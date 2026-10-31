# Frame-reuse re-rendering for BotW VR on the Steam Frame: feasibility and design

Author: reuse agent, 2026-10-28. This is a source study only. I made no GPU or Cemu runs.
All numbers come from existing bench files in ~/bettervr-build (bench-stereo-now, bench-monofix, bench-p900/p1080) or are derived from them. Derived numbers are marked (est).

## 1. Verdict (short)

- **Replaying the captured command stream with a patched view matrix (PM4/Latte level or Vulkan level) is NOT feasible** at reasonable effort. The view matrix is not a single patchable value. Everything that depends on it (culling, LOD, the light pre-pass, the view UBOs, per-draw uniform snapshots) is computed on the guest CPU, and Cemu copies it into per-draw ring slices. Details in section 3.
- **Feasible, but expensive:** the "guest-level extra eye pass". This extends BetterVR's existing trick: the right eye is already a re-render of the left eye's game state with a different camera and filtered game logic. Adding a third and fourth pass (L', R') per game frame reuses every hazard fix BetterVR already ships. Its GPU cost is about a full eye pair, and the passes come out bunched in time, not evenly spaced.
- **Expected result if built:** one extra pair per game frame, with shadows skipped on the replay. That gives head-pose updates at **about 35-40 Hz, with game logic dropping from 20.9 to about 17-19 fps** (est). Two replays per game frame (60 Hz head motion at 20 Hz logic) would need each replay pair to cost about 23% of a normal pair. Measured scaling says that is out of reach.
- **Recommendation:** do not start with replay. First run the cheap checks in section 6 (A/B of SteamVR positional depth reprojection, then optionally a layer-side, translation-only depth warp). Rotation is already handled at display rate by SteamVR's rotational reprojection, without the motion-vector artifacts the user disliked. So the only thing replay adds over today is **head translation and parallax at a higher rate**, plus less edge clipping. That benefit is narrow for its cost.

## 2. How things work today (relevant facts from the source)

### Guest side (BetterVR asm)
- `patch_RND_StereoRendering.asm` replaces `sead::GameFramework::procFrame` (0x031FA880). The order is:
  `calcDraw(eye 0)` (full game logic plus draw-list build) -> `procReset` -> simplified present -> `procDraw(L)` (submits the display lists) -> `storeLastSubmittedTimeStamp` / `waitForLastSubmittedTimeStamp` -> `calcDraw(eye 1)` (the game-state-mutating calls are filtered by `currentEyeSide==1`: 44 checks in `_ActorJobs.asm`, 25 in the main file) -> real present. The right eye's procDraw runs at the start of the next frame.
- `preventUnrequestingDraw` / `preventModelQueueClear` keep the model scene list alive for the second pass. This is the mono bug fixed on 2026-10-28.
- The camera is injected on the CPU side only. `agl::lyr::Layer::getRenderCamera` and `getRenderProjection` are redirected to `hook_GetRenderCamera` and `hook_GetRenderProjection` (camera.cpp:476, :535). These write a modified `sead::LookAtCamera` and `PerspectiveProjection` into guest scratch copies (`modifiedCopy_seadLookAtCamera` and the projection copy). `hook_ModifyLightPrePassProjectionMatrix` patches the light pre-pass projection in place. The pose comes from `renderer->GetPose(side)` (the latest xrLocateViews result).
- From these two structs, the game itself derives the view UBOs, frustum culling, LOD, the light pre-pass and translucent sorting. **No single guest UBO address holds "the view matrix" that a replay could patch.** It sits inside many CPU-built buffers.
- Eye identification for the layer uses the magic clear values of the 3D colour and depth targets (`patch_RND_Find3DFrameBuffer.asm`, keyed on `currentEyeSide`).

### Cemu side
- GX2 display lists live in guest memory. `LatteCP_ProcessRingbuffer` and `LatteCP_processCommandBuffer` (LatteCommandProcessor.cpp:1181, :1459) walk the PM4 packets and follow `IT_INDIRECT_BUFFER_PRIV`. Draws translate into Vulkan on the Latte thread.
- Uniforms: for shaders with remapped uniforms, `LatteBufferCache_LoadRemappedUniforms` copies only the used parts of guest UBOs **per draw** into a 16 MB host ring (`m_uniformVarBuffer`, VulkanRendererCore.cpp:341-361). Other UBOs bind ranges of `m_bufferCache`, which mirrors guest memory and is synced lazily. `m_useHostMemoryForCache` is constexpr false.
- **Guest timestamps retire when the Latte thread translates the EOP packet, not when the Vulkan GPU finishes** (`LatteCP_itEventWriteEOP` -> `TCLGPUNotifyNewRetirementTimestamp`, and `itHLEBottomOfPipeCB` writes the timestamp immediately). So BetterVR's mid-frame `waitForLastSubmittedTimeStamp` waits for translation, and the Vulkan GPU runs asynchronously behind it.
- Vulkan command buffers: a pool of 128, recorded with `VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT` (VulkanRenderer.cpp:2211, :2332). They interleave the eye passes, the HUD, buffer-cache uploads from staging, queries and readbacks.

### Layer side
- `renderer_vulkan.cpp` already has a display-rate submit thread (xrWaitFrame/EndFrame) and a head-pose sampling thread. It submits the latest colour and depth pair with the pose it was rendered at, plus XR_VALVE_app_space_delta_pose. So it can already present "the newest complete pair with its own render pose". A replay pair needs only a new slot tag, not a new presentation path.

## 3. Why command-stream capture and replay is unsafe or impractical

| Hazard | Where | Severity |
|---|---|---|
| View-dependent CPU work: frustum culling, LOD, translucent sort and the light pre-pass are baked at calcDraw time. A replay with a rotated head pops objects at the frustum edges. | gsys/agl calcDraw | High. It is partly mitigated by the existing 1.15 overscan (only for rotations under ~7 deg). |
| View data spread over many CPU-written buffers (view, viewProj, invView, camera position, light pre-pass params) and copied per draw into the uniform ring. A Vulkan-level patch would have to find every slice and recompute every derived matrix the way the game does. | VulkanRendererCore.cpp uniformData_* | High (blocker for Vulkan-level replay) |
| Guest memory mutated after retirement: the game reuses its double-buffered (`currentFrameCounter`) display lists and UBOs once the timestamp retires, which happens at translation time. A PM4 replay of frame N needs a snapshot of every referenced guest range, or must hold back retirement, which stalls the game. | GX2 timestamps, LatteCP | High |
| ONE_TIME_SUBMIT buffers that mix in staging uploads (staging ring reused, so a replay would copy garbage), queries and texture readbacks to the CPU; image layout transitions recorded from the original start state | VulkanRenderer.cpp | High for Vulkan-level replay |
| Occlusion queries: a replay must not write results back to guest memory, or the next frame's visibility changes | LatteQuery.cpp, GX2_Query.cpp | Medium (drop queries in the replay) |
| Render-target ping-pong and temporal state: auto-exposure/luminance adaptation, bloom history, any feedback copies (`IT_HLE_COPY_SURFACE_NEW`). A replay advances them, so adaptation runs faster (already 2x in stereo). BotW uses FXAA-style AA, not TAA: no TAA history problem found in the packs. | LatteSurfaceCopy, game post chain | Medium (visual only) |
| Shadow maps: correct to reuse, because the game state is the same. They are also the obvious pass to skip in a replay, as long as their textures stay untouched. | game shadow layer | Low (an opportunity, not a risk) |
| Latte CPU cost: a PM4 replay is re-translated by the Latte thread. Measured: Latte at 57% CPU in stereo vs 44% in mono, so about 7.7 ms of translation per extra eye (est). That fits, but it is not free. | LatteThread | Medium |

Conclusion: the only replay where the game recomputes all view-dependent data correctly is **guest-level re-execution of calcDraw/procDraw**. That is what BetterVR's right eye already is.

## 4. GPU and CPU budget (from measured benches)

| Metric | Stereo (stereo-now) | Mono (monofix) | Derived marginal eye |
|---|---|---|---|
| Game fps | 20.9 (47.8 ms) | 22.4 (44.6 ms) | |
| Cemu GPU busy | 64.4% -> 30.8 ms/frame | 37.2% -> 16.6 ms/frame | **~14 ms GPU per eye pass** |
| Latte thread CPU | 57% -> 27.3 ms | 44% -> 19.6 ms | **~7.7 ms Latte per eye** |
| Main PPC thread | 76% -> 36.5 ms | 79% -> 35.2 ms | **~1-3 ms PPC per filtered eye pass** |
| vrcompositor | 7.9% (~3.8 ms/frame) | 7.6% | |

- Free GPU per game frame today is about 47.8 - 30.8 - 3.8 ≈ **13 ms**. That is less than one extra eye.
- Resolution scaling: 900p -> 1080p (+44% pixels) took the frame from 47.8 to 54 ms. So roughly **45% of an eye pass scales with pixels and ~55% is fixed** (geometry, draw count, Cemu render-pass load/store). VRS and FDM gave 0-4%, which agrees. Lowering resolution alone cannot make a replay 4x cheaper.
- Replay pair cost r (est):
  - Full cost: r ≈ 28 ms.
  - Shadows skipped (assume ~20% of a pass, unmeasured): r ≈ 22 ms.
  - Shadows skipped plus replay at 0.75x linear resolution: r ≈ 17 ms.
  - Shadows skipped plus 0.5x: r ≈ 13 ms, but the soft replay frames alternate with sharp ones and are likely to shimmer.

| Config (est) | GPU/frame | Game fps | Head-pose pair rate |
|---|---|---|---|
| Today | 34.6 ms (CPU-bound 47.8) | 20.9 | 20.9 Hz (+ SteamVR rotational reprojection at display rate) |
| +1 replay, full cost | 62.6 | ~16 | ~32 Hz |
| +1 replay, no shadows, 0.75x | ~52 | ~19 | **~38 Hz** |
| +2 replays, no shadows, 0.75x | ~69 | ~14.5 | ~43 Hz |
| +2 replays at 60 Hz head with 20 Hz logic | needs r ≤ 6.6 ms (~23% of a pair) | - | not reachable |

**Pacing problem:** all passes run on the emulated main core inside procFrame. Back-to-back passes sample poses only a few ms apart, which gains almost nothing. To space them, there are three options, none of them good:
- (a) Make the main thread wait for real Vulkan completion before the replay calcDraw. This costs about 20-25 ms of game time per frame, so the game drops to ~14 fps.
- (b) Render the replay bunched, but with the pose predicted for its own mid-frame display time. This is extrapolation, so its positional gain is only what prediction gets right.
- (c) Run the replay pass from a second emulated core in parallel with the next frame's logic. This is research-grade: it races logic against the model scene, with a high crash risk and 3-6 weeks of reverse engineering.

## 5. Cheaper alternative: one render plus our own depth reprojection

The layer already holds per-eye colour and depth (`intermediateDepth`, depth swapchains) and the render pose. A layer-side compute warp works like this:
- **Translation-only, head-delta-only:** no motion vectors and no animation extrapolation, so none of the "wobble" of SteamVR motion smoothing. It does a backward search on depth, from render pose to display pose, at 2 synthetic frames per game frame or at display rate.
- **Cost (est):** about 0.5-1 ms per eye per synthetic frame on the Adreno 750 at 1600x900, so ~2-4 ms GPU per game frame. Compare 17-28 ms per replay pair. It fits in today's 13 ms of headroom **with no loss of game fps**.
- **Artifacts:** disocclusion at depth edges, with width proportional to translation x (1/z_near - 1/z_far). At 1 cm of head translation, an object at 0.5 m in front of a 10 m background shifts ~1.1 deg (~15 px), which shows at hands and weapons. Distant scenery is effectively exact. Translucent surfaces with no depth (particles, water surface) smear slightly, and specular is wrong (minor).
  - Why this differs from the artifacts seen before: the user's earlier complaints were about SteamVR motion smoothing (motion-vector frame synthesis), and earlier "depth reprojection" warping was later traced mainly to the aspect/preset mismatch.
- **Compared with replay:** replay has zero disocclusion and exact parallax, but costs 15-25% of game fps and gives about 38 Hz poses that are badly paced. The depth warp costs about 0% fps and gives display-rate poses, with small edge artifacts. Both leave animation, game-camera motion and stick turning at 20 Hz.

## 6. Plan

### Step 0: no code, about 30 minutes with the user
SteamVR may already do positional reprojection from the submitted depth now that motionSmoothing=0. Check whether it does:
1. In the headset, side-step or lean with a nearby object in view (normal launch).
2. Repeat with `BETTERVR_LINUX_DISABLE_DEPTH=1` (also accepted: `BETTERVR_LINUX_DISABLE_DEPTH_REPROJECTION`, renderer_vulkan.cpp:536).
3. If parallax visibly updates smoothly in the depth-on case, translation is already handled and replay brings almost nothing.

### Step 1: replay prototype P0, if still wanted (3-5 days, all env-gated, default off)
1. `BETTERVR_LINUX_REPLAY=1`: in `custom_sead_GameFramework_procFrame`, after the right eye's calcDraw, run one more pair.
   - `currentEyeSide` takes the values 2 and 3, and every filter check `==1` becomes `!=0`. Only the asm needs changing: about 80 sites in `_ActorJobs.asm`, `StereoRendering.asm`, `_Optimizations.asm` and `CameraAndProjection.asm`.
   - The hooks map the side as `side & 1` and the pass as `side >> 1`.
2. The camera and projection hooks call a fresh `xrLocateViews` (or predict to t0 + T/2) for pass 1.
3. Insert `storeLastSubmittedTimeStamp`/`waitForLastSubmittedTimeStamp` and the procDraw calls between the pairs, using the same pattern as L -> R.
4. In `Find3DFrameBuffer`, add new magic clear values for passes 2 and 3. The layer then tags slots with a pass index and per-pass pose, and the submit thread always shows the newest complete pair.
5. Drop occlusion queries in the replay pass (an env-gated Cemu tweak next to `CEMU_OCCLUSION_FORCE_VISIBLE`).
6. Measure under the lock with bench-botw.sh: fps, GPU busy and Latte CPU. Check with shot-run for popping at the frustum edges, exposure drift and particles.
   - Go/no-go: game fps ≥ 18 and visibly better parallax.

### Step 2: shadow skip for replay passes (3-5 days)
- Find the shadow render step in the agl layer list. The light pre-pass and shadow-related hooks are a starting point.
- Skip it when the pass is 1 or more, keeping the shadow textures.
- Optionally add a per-pass resolution scale. This is hard, because Cemu's render targets are fixed-size per graphic pack, so it would need a separate replay target set.

### Step 3: pacing (only if Step 1 and Step 2 pass)
Try option (b), predicted mid-frame pose, first. Treat (c), cross-core replay, as a separate high-risk project.

### Alternative track (recommended over Step 1)
Layer-side translation-only depth warp, about 1-2 weeks. This is theater-agent territory (layer src), behind `BETTERVR_LINUX_DEPTHWARP=1`.

### Effort summary

| Path | Effort | Risk | Expected head-motion rate |
|---|---|---|---|
| Guest extra pass P0 | 3-5 d | Medium | ~32 Hz, game ~16 fps |
| + shadow skip / 0.75x | +1-2 wk | Medium-High | ~38 Hz, game ~19 fps |
| Paced cross-core replay | 3-6 wk | Very high | ~40 Hz, evenly spaced |
| Vulkan/PM4 command replay | 6-10+ wk | Blocked (section 3) | - |
| Layer depth warp | 1-2 wk | Low-Medium | display rate, game 20.9 fps |
