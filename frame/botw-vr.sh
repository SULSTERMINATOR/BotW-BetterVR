#!/usr/bin/env bash
# BotW VR for the Steam Frame: Cemu + BetterVR, run from the folder this script lives in.
# Add this script to Steam as a non-Steam game. Run install.sh once first.
D="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
if [ ! -f "$D/botw-vr.conf" ]; then
    echo "BotW VR is not set up yet. Run: $D/install.sh /path/to/your/BotW.wua" >&2
    exit 1
fi
. "$D/botw-vr.conf"

export CEMU_BIN="$D/Cemu" BETTERVR_SKIP_CEMU_CHECK=1
export BETTERVR_LAYER_DIR="$D/layer"
export CEMU_GRAPHIC_PACKS="$D/portable/graphicPacks"
export BOTW_RPX="$BOTW_GAME"
export ENABLE_GAMESCOPE_WSI=0
# create the OpenXR instance before Cemu's own Vulkan instance (needed with SteamVR)
export BETTERVR_LINUX_EARLY_INIT=1
export LD_PRELOAD="$D/libhugeshim.so${LD_PRELOAD:+:$LD_PRELOAD}"
[ "${BETTERVR_PIN_THREADS:-1}" = 1 ] && "$D/pin-threads.sh" &
cd "$D"
exec "$D/launch-bettervr.sh" "$@" >"$D/botw-vr.log" 2>&1
