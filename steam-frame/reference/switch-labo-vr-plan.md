# BotW (Switch) Labo VR mode on the Steam Frame - scouting plan

Agent: switch. Date: 2026-10-28. Status: scouting only; nothing installed, no BotW files touched.

## Verdict (short)

Technically feasible with tools already on the device. As a way to play BotW in VR it is probably
**worse than the current BetterVR setup**, apart from frame rate:

- What you would get: third-person BotW, stereo, camera turned by head rotation only (no 6DoF, no
  first-person, no motion controls), with the image the Labo goggles expect: two side-by-side ~640x720
  halves, barrel pre-warped for the Labo lenses, about 480p in the centre per Digital Foundry, with the
  game's 30 fps target and the usual dynamic-resolution drops. Ryujinx's resolution scale can sharpen it
  (2x gives about 1280x1440 per eye), but the stereo itself is shallow and the HUD/FOV is tuned for cardboard.
- What it might win: the game runs as ARM64 code on an ARM64 host (Ryujinx LightningJit, close to native),
  so 30 fps (maybe 60 with a 1.6.0 FPS mod) looks plausible. It was **not measured with BotW**
  (there is no copy), and my 3D-load measurement with other games is weak (see Perf).
- Blocker: **the user has no Switch copy of BotW on the device** (no title 01007EF00011E000 anywhere under
  ~/Emulation, ~/.config/Ryujinx/games, the SD card or Sync/). Nothing can be tested until they provide one.

Recommendation: worth roughly a 2-3 day prototype only if the user wants a "seated 30 fps cinema-stereo"
mode as an alternative to the 21 fps 6DoF BetterVR. Step 1 is cheap and tells us most of what we need:
once a dump exists, boot BotW 1.6.0 in Ryujinx, turn on VR goggles mode, and record fps. Do not build
the XR side before that number exists.

## 1. Emulators on the device

| Emulator | Path | Arch | Notes |
|---|---|---|---|
| Ryujinx (Ryubing) Canary 1.3.351, .NET 10 | ~/Applications/publish/Ryujinx (EmuDeck launcher ~/Emulation/tools/launchers/ryujinx.sh) | **ELF aarch64** | CPU backend on ARM64 host = `Ryujinx.Cpu.LightningJit` (strings in binary). AppleHv hypervisor backend is macOS-only (`use_hypervisor=false`). No NCE in Ryujinx. Memory manager HostMappedUnsafe (fastest). Vulkan on Turnip Adreno 750 works. |
| yuzu EA 3787 | /run/media/mmcblk0p1/Sync/Linux-Yuzu-EA-3787.AppImage | **x86-64** | Unusable here: it would need FEX plus its own JIT, which means translating twice. Not touched (Sync/). |
| Eden/Citron/Sudachi | not installed | - | Eden has an NCE backend (native code execution) listed as experimental on Linux arm64. Getting it would mean a new download, which is out of scope. It is a possible later upgrade if LightningJit turns out CPU-bound. |

LightningJit on an ARM64 host copies most guest A64 instructions through unchanged and only rewrites
memory and system ops, so guest code runs close to native speed. That is the "near native" premise, and it holds for Ryujinx.

Existing Ryujinx config (EmuDeck): Vulkan, res_scale 1, handheld (docked_mode=false), PTC and shader
cache on, player 1 = "Steam Deck Controller" (Steam Input virtual pad, SDL3) **with motion backend
CemuHook already set to 127.0.0.1:26760, slot 0, sensitivity 100, gyro_deadzone 1**. So the DSU
client side needs no setup.

## 2. Measured perf (Ryujinx, this device, 2026-10-28)

Conditions: under the heavy lock, but other agents' loads kept the SoC at **66-98 C** the whole time
(the 58 C cool-down target was never reached; it gives up after 3 min), so the numbers are pessimistic.
FPS comes from Ryujinx's status-bar counter (windowed mode screenshots), because MangoHud never wrote a CSV
for Ryujinx even though the layer is installed (cause not found).

| Run | Content | Result |
|---|---|---|
| kirby2 (fullscreen, no input) | Kirby boot -> "connect online?" dialog | Booted fine (shader cache 104 MB + PTC present); waited on the dialog |
| kirby4 / kirby5 (windowed, XTest keys) | Kirby opening movie and attract loop | **60.0 FPS**, FIFO 3%, GPU at its minimum 231 MHz. Probably a pre-rendered video, so **not a 3D load test**. "Skip" with + did not work |
| arceus (fullscreen, no input) | Arceus boot | First frame after ~100 s (load from SD + shader build), killed shortly after; no FPS |

Earlier (2026-10-26) the user ran LEGO 2K Drive / LEGO Horizon in this Ryujinx; the logs show no crashes.

Honest bottom line: Ryujinx boots big Switch games on the Frame and presents at a locked 60 when the load is light.
**A sustained 3D gameplay fps was not obtained.** WARNING: the XTest key injection used in kirby3-5
(perf-run2.sh / tools/xkey.py) sends keys to whatever window has focus, and it **typed z/w/l into the user's
chat/terminal**. It is disabled (script made non-executable, xkey.py renamed .DO-NOT-USE) and must not be
used again. To get a gameplay number without input injection: the user plays 2 minutes of Arceus/Kirby (or later BotW)
with Ryujinx windowed so the status-bar FPS is visible, or loads a save that boots straight into gameplay.

Scripts: ~/bettervr-build/fleet/switch/perf-run.sh (fullscreen + MangoHud), perf-run2.sh (DISABLED, see
warning above).
Outputs and screenshots: ~/bettervr-build/fleet/switch/runs/<label>/. Ryujinx saves were backed up first
(fleet/switch/save-backup/) and checked unchanged after every run.

## 3. BotW Labo VR mode facts (research)

- Requires the **1.6.0 update** (Apr 2019, latest). Enable: System menu -> Options -> Toy-Con VR Goggles
  -> "Use VR Goggles". Works from any point in an existing save. Cutscenes and some scenes drop back to 2D.
- Stereo side-by-side on the 1280x720 handheld screen, so each eye gets at most 640x720. DF measured about 480p in the
  centre, higher towards the edges (the lens pre-warp is baked into the render). Dynamic resolution and
  30 fps target, with drops.
- The camera stays **third person**. The gyro rotates the camera (rotation-only head tracking, no
  position). There is an option to turn gyro camera off and use the right stick (stereo stays).
- HUD: reduced/re-laid-out for the goggles (no source states exactly what is hidden).
- Mods: theboy181's 60 FPS and resolution patches exist for 1.6.0 (yuzu-format exefs/romfs mods,
  which Ryujinx also loads from ~/.config/Ryujinx/mods). The 60 fps mod ties game speed to frame rate. It
  is **unverified** whether these patches behave in VR mode. Ryujinx `res_scale` (2x/3x) scales all render
  targets generically and should apply to VR mode too (unverified).
- Existing projects that put Switch Labo VR mode from an emulator into a real headset: **none found**.
  (BotW VR work is all Cemu-based: BetterVR and the older 6DoF mods.) People used ReShade SuperDepth3D
  with yuzu, which is a different thing.
- Steam Frame: Valve says flat-game stereoscopic/SBS display is not supported yet ("on our list"), so no
  built-in theater mode can show an SBS window in 3D today.

## 4. Pipeline design

```
 Ryujinx (handheld, BotW 1.6.0, VR goggles ON)
   |  DSU/cemuhook UDP 127.0.0.1:26760  <---- gyro (deg/s) + accel (g) @ 250-500 Hz
   |  vkQueuePresentKHR (1280x720 SBS, pre-warped)   ^
   v                                                 |
 [VK_LAYER_labo_xr]  (our Vulkan layer, loaded only when LABO_XR=1)
   - OpenXR session (SteamVR/Monado runtime, same as BetterVR)  --+
   - DSU server thread: xrLocateSpace(VIEW, LOCAL) + XrSpaceVelocity -> console-frame gyro/accel
   - on present: copy left/right halves into two XR swapchains through an undistort shader,
     submit XrCompositionLayerProjection with pose = headset pose sampled when that game frame's
     gyro input was consumed (ring buffer, tunable delay) -> SteamVR reprojection keeps the world
     steady even at 30 fps
```

### Motion (DSU server)
- Prototype: ~/bettervr-build/fleet/switch/dsu_server.py (cemuhook v1001: version/port-info/pad-data,
  CRC32, slot 0, synthetic yaw sweep). Written but **not yet tested against Ryujinx**: a passive listen on 26760 during
  one run saw no client packets, maybe because the controller/motion only polls once a game uses the
  sensor ("StartSixAxisSensor" appears in the Arceus log). Next step: run it during a game and look for Ryujinx's
  "CemuHook" connect log line.
- Feed the real angular velocity (XrSpaceVelocity.angularVelocity) rotated into the Switch's handheld
  axis frame, plus a gravity vector from the headset orientation as accel. Ryujinx runs its own
  gyro+accel fusion, so pitch/roll self-correct and yaw drifts slowly. Recentre by resetting yaw (BotW
  re-centres the camera behind Link when the camera-reset button is pressed).
- Ryujinx profile for VR: controller type **Handheld** (VR mode is handheld-only), gyro_deadzone 0,
  sensitivity 100. Keep it in a separate Ryujinx profile so the normal profile stays untouched.

### Presentation options (concrete)
1. **Vulkan layer in Ryujinx (recommended).** Same pattern as BetterVR's Linux layer (OpenXR inside
   the emulator process, Vulkan interop), so the theater agent's code is reusable. Zero-copy (GPU blit), lowest
   latency, can use projection layers with the real per-frame pose, and gives reprojection for free.
   Work: about 1.5-2 kLoC C++, most of it borrowed from BotW-BetterVR-Linux (openxr.cpp swapchain/session code).
2. **Standalone OpenXR viewer.** Captures the Ryujinx X11 window (XComposite + DMA-BUF, or XShm) and
   draws two quads or a projection layer. It doesn't touch Ryujinx, but adds 1+ frame of latency and a
   CPU copy (XShm) unless DMA-BUF import works on Xwayland/gamescope. Good fallback.
3. Existing viewers: Steam Frame theater mode / SteamVR desktop view are mono today (no SBS). wlx-overlay-s
   / xrdesktop can show a window as a mono overlay. None is installed, and installing them would be new external code.

### Undistort
The Labo pre-warp has to be inverted per eye (radial polynomial + circular mask). Parameters are
unknown. Measure them from captured frames once the game runs (straight horizon/edges), or look for
a 1.6.0 exefs patch that skips the warp pass. If the warp can't be removed, the double distortion
(Labo warp + Frame lens correction) will look wrong.

## 5. What the user would need to provide

- **Their own dump of The Legend of Zelda: Breath of the Wild for Switch** (title ID 01007EF00011E000,
  base game) **plus the v1.6.0 update** (the update is mandatory for VR mode). DLC is optional. It must
  come from their own console/cartridge. We will not obtain it.
- Optional: theboy181's 1.6.0 60fps/resolution mods, if they want to try >30 fps (unverified in VR).
- Keys/firmware: already set up (Ryujinx shows firmware 10.0.4; that is old, but BotW 1.6.0 only needs a
  low firmware level).

## 6. Next steps once a BotW copy exists
1. Under the lock: boot BotW 1.6.0 handheld, enable VR goggles, windowed status bar, record FPS in
   Hyrule Field / Kakariko at res_scale 1x and 2x. Go/no-go: at least 30 fps sustained at 2x.
2. Test dsu_server.py synthetic yaw: does the BotW camera turn? Check the axis mapping and sign.
3. Capture one VR frame and fit the undistort.
4. Only then build the Vulkan layer (option 1), gated by LABO_XR=1, with a separate Ryujinx profile.
