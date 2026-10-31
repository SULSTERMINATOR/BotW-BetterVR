#!/usr/bin/env bash
# Launches BotW in VR: patched ARM Cemu + BetterVR Linux layer, via the port's launcher (uses running SteamVR).
V="$HOME/Applications/Cemu-BetterVR"
export CEMU_BIN="$V/Cemu"
export BETTERVR_LAYER_DIR="$V/layer"
export CEMU_GRAPHIC_PACKS="$V/portable/graphicPacks"
export BOTW_RPX="$HOME/Emulation/wiiu-local/mlc01/usr/title/00050000/101c9400/code/U-King.rpx"
# Gamescope WSI layer fails to hook windows on ARM/Frame
export ENABLE_GAMESCOPE_WSI=0
# Transparent huge pages for Cemu's guest RAM (+~5% fps); source in ~/bettervr-build/hugeshim
export LD_PRELOAD="$V/libhugeshim.so${LD_PRELOAD:+:$LD_PRELOAD}"
# BETTERVR_LINUX_CAPTURE_DIAG=1 enables verbose diagnostics (the bench tools set it); off for normal play
# Render a wider FOV than shown so head turns at low fps reproject into image instead of black edges
export BETTERVR_LINUX_OVERSCAN=${BETTERVR_LINUX_OVERSCAN:-1.15}
# Tell SteamVR how the game world moves between frames (stick turning/walking) so reprojection follows it.
# 1 = on, -1 = opposite convention (try if turning looks worse), 0 = off
export BETTERVR_LINUX_DELTA_POSE=${BETTERVR_LINUX_DELTA_POSE:-1}
# Experimental foveated rendering: present only while fdm.conf exists (delete it to turn foveation off)
[ -f "$V/fdm.conf" ] && set -a && . "$V/fdm.conf" && set +a
# fixed core placement for Cemu threads (+~3% fps); BETTERVR_PIN_THREADS=0 disables
[ "${BETTERVR_PIN_THREADS:-1}" = 1 ] && "$V/pin-threads.sh" &
cd "$HOME/bettervr-build/BotW-BetterVR-Linux"
exec ./launch-bettervr.sh "$@"
