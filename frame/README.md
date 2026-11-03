# BotW VR for the Steam Frame

Breath of the Wild in VR, running natively on the Steam Frame: no PC, no streaming. This is Cemu (Linux arm64 build with
BetterVR's hooks) + the BetterVR mod (ctrlaltdle's Linux port of Crementif's BetterVR), with Steam Frame fixes.

Expect roughly 22-28 fps depending on the area. It's experimental.

## What you need

- A Steam Frame (SteamOS, arm64). This bundle does NOT work with Windows Cemu or on a PC.
- Your own dump of Breath of the Wild (USA, 00050000101C9400) with the v1.5.0 update (v208). Either:
  - a `.wua` that includes the update, or
  - the game already installed in a Cemu `mlc01` folder (point install.sh at `mlc01/usr/title/00050000/101c9400/code/U-King.rpx`;
    the update and DLC must be installed in that same `mlc01`).
  Not included, don't ask.
- SteamVR (comes with the Frame).

## Install or update (one command)

In Desktop Mode, open Konsole and paste:
```
curl -fsSL https://raw.githubusercontent.com/SULSTERMINATOR/BotW-BetterVR/main/frame/get-botw-vr.sh | bash
```
It installs to `~/Applications/BotW-VR`, downloads the shared shader cache (far less black popping on first play), finds your
game in your home folder and adds an **Update BotW VR** shortcut to the desktop and app menu. Run that shortcut (or the same
command) to update; your saves, game path and settings are kept. If it can't find the game, add the path:
`... | bash -s -- /path/to/BotW.wua`. Then do steps 3-5 below.

## Manual install

1. Unzip this folder somewhere on the Frame, e.g. `~/Applications/BotW-VR`.
2. Open a terminal (Desktop Mode, Konsole) and run:
   ```
   ~/Applications/BotW-VR/install.sh /path/to/your/BotW.wua
   ```
   With no path it searches your home folder for the game.
3. Steam > Games > **Add a Non-Steam Game** > Browse > pick `botw-vr.sh` in that folder. Rename it "BotW VR" if you like.
4. Launch it from your library with SteamVR running.
5. SteamVR settings > Video > Per-application settings > BotW VR: set refresh rate to **90 Hz**.
   At the default 72 Hz SteamVR locks the game to 24 fps.

The first run compiles shaders, so expect stutter and a slow first load.

## Notes

- FPS++ and the BetterVR graphic packs are already enabled. Don't open Cemu's graphic pack window; just launch the game.
- With a `.wua`, saves go in `mlc01/` inside this folder (back it up before updating). With an installed game they stay in
  that game's `mlc01`.
- Stuck on a black screen after launch with the game installed in an mlc01? The update is probably missing from it.
- Problems: the log is `botw-vr.log` in this folder. Post it with your bug report.

## Source

- BetterVR layer: https://github.com/SULSTERMINATOR/BotW-BetterVR (main)
- Based on https://github.com/ctrlaltdle/BotW-BetterVR-Linux and https://github.com/Crementif/BotW-BetterVR
- Cemu (MPL-2.0): https://github.com/cemu-project/Cemu
