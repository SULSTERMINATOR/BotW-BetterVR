# BotW BetterVR on the Steam Frame: handoff

Status as of 2026-10-31. Everything here was built and measured on a Steam Frame:
- aarch64 SteamOS
- Snapdragon-8-Gen-3-class CPU: cpu7 is the X4 core, cpu2-6 are A720s
- Adreno 750 GPU with Mesa Turnip
- SteamVR 2.18.2 (OpenXR)

This folder is the starting point for continuing the work on a stronger machine.

## 1. What is in this repo (`main`)

| Commit | What |
|---|---|
| `2e06b31` | Upstream Crementif/BotW-BetterVR (BetterVR 0.9.23, Aug 2026) |
| `3076fa0` | ctrlaltdle's Linux port, imported unchanged. It adds `build-linux/build.sh`, `LINUX.md` and vendored glm/imgui/implot, and was tested on x86 with a Quest 3 and WiVRn. |
| `47cb001` | Steam Frame port fixes, see §3 |
| `aa68324` | sRGB view fix and view-locked HUD |

Things that are **not** upstream, and live in this folder:
- `cemu/cemu-3310f3b-steam-frame.patch`: our Cemu changes on top of cemu-project/Cemu `3310f3b8b184d64a62b89fd59088c799432badf5`, see §4.
- `reference/old-port-steam-frame-fixes.patch`: the earlier Frame work, done on asingleoat/BotW-BetterVR-Linux. Two features from it are **not yet ported** to this tree, see §6.
- `graphics-pack/…rules.txt`: the "Graphics (Modified Version For BetterVR)" pack with the 16:9 presets we added. The other presets are near-square and stretch the game's 16:9 image, which shows as warping.
- `tools/`: benchmark, screenshot, build, launch and debug scripts. Paths assume the Frame layout (`~/bettervr-build`, `~/Applications/Cemu-BetterVR`), so adjust them.

## 2. Current state on the Frame

- **Default launch:** the Steam shortcut runs v3, which is this repo's `main` layer plus our Cemu build.
- **Frame rate:** about 24-26 stereo fps at 1600x900, and somewhat lower at the current 1920x1080 preset, which hasn't been benchmarked headless yet.
- **Cemu wait switches are OFF in v3,** because skipping the left-eye wait desynced the eyes (see §4).
- **SteamVR settings:**
  - Motion Smoothing off (the user preferred it)
  - `additionalFramesToPredict=2` for app key `steam.app.4002757572`. This was tuned for the old port; re-check it for v3.
- **Thermals matter a lot.** The SoC hits 86-98 °C in long sessions and the X4 throttles to about 2.6 GHz. Benchmarks are only comparable when started below about 60 °C.

## 3. Steam Frame port fixes (commit `47cb001` + `aa68324`)

1. **Startup deadlock.** SteamVR's `xrCreateVulkanInstanceKHR` and `xrGetVulkanGraphicsDevice2KHR` create *extra internal* VkInstances and VkDevices on the Device-B thread. Those go through our implicit Vulkan layer and re-enter `VRManager::instance()` while it is still being constructed, which blocks forever on the static-init guard.
   - Fix: a thread-local `VRLayer::g_creatingDeviceB` covering the whole `RND_Vulkan2` constructor makes every layer hook pass those through.
2. **Swapchain format.** SteamVR on the Frame offers no `R8G8B8A8_UNORM` colour swapchain.
   - We fall back to `R8G8B8A8_SRGB` **and render through an sRGB view**, because the present shaders write linear colour.
   - A UNORM view crushed the darks: black shadows and a black minimap.
3. **`-Wl,-Bsymbolic` is required** when linking the layer against our Cemu build. Cemu is built with `--export-dynamic` (BetterVR resolves Cemu symbols) and exports its *own* ImGui. Without it, the layer's ImGui calls bind to Cemu's ImGui and crash in `ImFontConfig`.
   - This is set in `tools/build-v3.sh`; `build-linux/build.sh` takes `EXTRA_LDFLAGS`.
4. **HUD/menus view-locked.** The HUD quad now lives in XR VIEW space at `hudDistance`. In stage space, positioned from the game's low-rate eye poses, it jittered. `BETTERVR_LINUX_HUD_VIEWLOCK=0` reverts it.
5. Frame controller bindings (`utils/controller_bindings.h`), `LockedValue` input state, and game-side PPC console logging off by default.

## 4. Cemu patch (`cemu/cemu-3310f3b-steam-frame.patch`)

**Required on ARM:**
- `_mm_pause()` on aarch64 needed a `"memory"` clobber (`src/Common/precompiled.h`). Without it the GX2CopySurface spin-wait never re-reads the queue, and BotW hangs at the boot splash.
- Build Cemu with `-DCMAKE_EXE_LINKER_FLAGS=-Wl,--export-dynamic` (see `tools/build-cemu-only.sh`).

**Diagnostics and experiments, all env-gated and off by default:**

| Env | Purpose |
|---|---|
| `CEMU_CORE_STATS=1` | Logs, per emulated core, run vs idle time and *what each idle was blocked on*: guest LR plus who woke it. Also LatteThread busy, ring-idle and vkFence time. This is the main tool. |
| `CEMU_PERF_MAP=1` | Writes `/tmp/perf-<pid>.map` so `perf` can name JIT code by guest address |
| `CEMU_ASYNC_DRAWDONE=1` | GX2DrawDone no longer forces a full host-GPU sync |
| `CEMU_WAITTS_LR=<hex>` + `CEMU_WAITTS_LAG=<n>` | Lets GX2WaitTimeStamp from one guest call site lag. The left-eye wait is `018141c4` in the old port and `018145c4` in v3. |
| `CEMU_FAST_CLOCK`, `CEMU_IDLE_THROTTLE_US` | Cheaper clock and idle spin: no gain |
| `CEMU_FDM`, `CEMU_VRS` | Foveation and variable-rate shading experiments: no gain (FDM forces Turnip GMEM, which is about 4x slower) |
| `CEMU_OCCLUSION_FORCE_VISIBLE` | Diagnostic only; BotW never reads occlusion results |

## 5. What limits the frame rate (measured with `CEMU_CORE_STATS`)

**Old port, stereo, about 21.5 fps:**
- The main guest core runs game code about 52% of the frame (about 27 ms).
- It is idle about 47%:
  - 28% in GX2WaitTimeStamp from BetterVR's left-eye `waitForLastSubmittedTimeStamp`
  - 7% in the end-of-frame GX2DrawDone
  - 5% waiting on job workers
- **LatteThread** (Cemu's GPU-command translation thread) is busy about 33 ms per frame.
- The guest profile is flat (top function 1.5%) and interpreter fallback is about 0.2%, so HLE-ing hot guest functions won't help.

The frame is a serial handoff chain: guest core → LatteThread → GPU.
- Removing either wait alone just moves the stall to the other wait.
- Removing both gave **26.2 vs 21.5 fps (+22%)**, but desynced the eyes in the headset.

**v3 (upstream 0.9.23):** about 25.7 by the same counter. The Cemu switches only add +0.4 there, so v3 already overlaps better.

**Ceiling today:** LatteThread time and GPU time. SteamVR reports about 29 ms app CPU and about 36 ms app GPU per frame.

**Benchmarks:**
- `tools/bench2.sh LABEL v3|old [ENV=..]` reports swaps/s from `CEMU_CORE_STATS`.
- `tools/bench-botw.sh` reports `[frame stats] cemu=` from the old port.
- Both run headless with `BETTERVR_DEBUG_AUTOPRESS_A=1` and wait for `inMenu=false`.
- **Do not compare numbers across the two counters.**
- Live in the headset: `vrcmd --stats` gives frame_submits deltas and average app CPU/GPU ms.

## 6. Open problems, highest value first

1. **LatteThread throughput** is the real limit now; the old 44 ms "CPU cap" was mostly waits.
   - Profile LatteThread with `perf` (`LatteCP_processCommandBuffer`, `LatteTexture_updateTexturesForStage`, buffer cache, descriptor-set creation, pipeline lookups).
   - Ideas: cache descriptor sets, cut per-draw state hashing, move work off the thread, batch uniform uploads.
   - Any win here also helps every Cemu user on every platform, so do it on a PC with good tooling and verify on the Frame.
2. **Eye-safe overlap.** Get the +22% from removing the waits *without* desyncing eyes.
   - For example, let the right eye proceed but present both eyes only when both are done: pair the eyes per frame in the layer.
   - Or move the wait instead of removing it.
3. **Dark straight-edged patch on grass.**
   - Seen since the start, in both old and v3. It moves with head motion, so it's screen-space.
   - It is **not** the graphics pack scaling (it stays with the pack disabled), **not** depth shadows (it stays with `isDepthShadowEnabled` forced false), **not** overscan, and **not** Turnip LRZ/UBWC (`TU_DEBUG=nolrz/noubwc`).
   - Suspect a screen-space lighting or shadow-mask buffer computed for one eye or camera and reused for the other. Ask whether it differs per eye; the user is checking.
   - Upstream fixes `24ba14a` (shadows rotating with headset) and `a35fa2d` (light projection matrices) are already in this tree.
4. **Port the remaining old-port features** from `reference/old-port-steam-frame-fixes.patch`:
   - **XR_VALVE_app_space_delta_pose.** `LinuxPublishAppSpaceDelta`, with EMA-smoothed game-camera velocity, cut detection, and zero in menus. It tells SteamVR how the world moves under stick turning, so reprojection follows it. The user found turning better with it.
   - Overscan (`BETTERVR_LINUX_OVERSCAN=1.15`) to render past the view edge for reprojection. Optional.
5. **Minimap** is now a full circle with its grid visible, but the inside is darker than on the flat screen. Re-check after the colour fix.
6. **Single-eye mode** (old port, `BETTERVR_LINUX_MONO=1`, `monoFrameActive` fix in `patch_RND_StereoRendering.asm`) works but gives only +7%; not worth losing stereo.

**Dead ends already measured:**
- foveation (FDM/VRS)
- lower shadows
- actor/draw-distance sim reduction (+4% max, only object distance 0.75x matters)
- frame-reuse re-rendering (no GPU headroom, see `reference/frame-reuse-design.md`)
- 3D theater mode (user rejected)
- Switch Labo VR (needs a Switch dump, 480p, 3DOF; see `reference/switch-labo-vr-plan.md`)
- `FAST_CLOCK`
- `TU_DEBUG=sysmem`

## 7. Building

**Layer, v3 tree:**
```
EXTRA_INCLUDES="-I <openxr+vulkan headers>" EXTRA_LDFLAGS="-L <jsoncpp lib> -Wl,-Bsymbolic" EXTRA_LIBS="-ljsoncpp" OPT_FLAGS="-O2 -g1" bash build-linux/build.sh
```
- On the Frame this runs inside an `ubuntu:24.04` arm64 podman container (`tools/build-v3.sh`).
- The headers came from OpenXR-SDK (with openxr.hpp) and Vulkan-Headers.

**Cemu:**
```
git checkout 3310f3b && git apply steam-frame/cemu/cemu-3310f3b-steam-frame.patch
```
Then build with `tools/build-cemu-only.sh` (vcpkg, clang, `--export-dynamic`).

**Launch:** `tools/launch-v3.sh` sets:
- `BETTERVR_LAYER_DIR`, `CEMU_BIN`, `BOTW_RPX`
- `ENABLE_GAMESCOPE_WSI=0` (the gamescope WSI layer breaks on the Frame)
- `LD_PRELOAD=libhugeshim.so` (MADV_HUGEPAGE on Cemu's guest RAM, about +5%; source in `tools/hugeshim`)
- `BETTERVR_LINUX_EARLY_INIT=1`

`tools/pin-threads.sh` pins LatteThread to the X4 and the main guest core to an A720 with uclamp, about +3-5%.

**Cemu config used:**
- 1920x1080 (16:9) preset of the Graphics pack
- FPS++ 120 FPS limit
- `accurateShaderMul=true` (false gave +7% but is a suspect for dark shading)

## 8. Frame gotchas

- **The Steam performance overlay (mangoapp) crash-loops** when the nested Plasma desktop is running: it can't read kwin's `/proc/<pid>/map_files`. It crashes every 2-3 s and costs about 1.5 cores through coredump and log-submitter. Close the nested desktop while playing.
- **Volume button jumps to max:** SteamOS issue, not ours.
- **Headset backlight:** `/sys/class/backlight/*/brightness` (0 = off).
- Never `cp` over a loaded layer `.so`: copy to `.new`, then `mv`.
