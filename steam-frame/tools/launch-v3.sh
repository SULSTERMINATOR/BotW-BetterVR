#!/usr/bin/env bash
# Launch BotW with the v3 (BetterVR 0.9.23-based) layer from ~/bettervr-build/bvr-v3 instead of the installed one.
# Same Cemu, hugeshim and thread pinning as launch-botw-vr.sh. The launcher re-links the BetterVR graphic pack to
# bvr-v3/resources; the normal launcher links it back on its next start.
V="$HOME/Applications/Cemu-BetterVR"
export CEMU_BIN="${CEMU_BIN_OVERRIDE:-$V/Cemu}"; [ -n "$CEMU_BIN_OVERRIDE" ] && export BETTERVR_SKIP_CEMU_CHECK=1
export BETTERVR_LAYER_DIR="$HOME/bettervr-build/fleet/cpu/port/layer-v3"
export CEMU_GRAPHIC_PACKS="$V/portable/graphicPacks"
export BOTW_RPX="$HOME/Emulation/wiiu-local/mlc01/usr/title/00050000/101c9400/code/U-King.rpx"
export ENABLE_GAMESCOPE_WSI=0
export BETTERVR_LINUX_EARLY_INIT=${BETTERVR_LINUX_EARLY_INIT:-1}
export LD_PRELOAD="$V/libhugeshim.so${LD_PRELOAD:+:$LD_PRELOAD}"
[ "${BETTERVR_PIN_THREADS:-1}" = 1 ] && "$V/pin-threads.sh" &
cd "$HOME/bettervr-build/bvr-v3"
exec ./launch-bettervr.sh "$@"
