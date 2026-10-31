#!/usr/bin/env bash
# under lock: start v3 under gdb, after 70 s interrupt to dump backtraces
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 GAMESCOPE_WAYLAND_DISPLAY=gamescope-0; unset WAYLAND_DISPLAY XAUTHORITY
rm -f ~/bettervr-build/fleet/cpu/port/layer-v3/BetterVR_log.txt /tmp/claude-1000/v3-bt.txt
CEMU_BIN_OVERRIDE=~/bettervr-build/fleet/cpu/port/cemu-gdb.sh BETTERVR_DEBUG_AUTOPRESS_A=1 timeout 200 ~/bettervr-build/fleet/cpu/port/launch-v3.sh > /tmp/claude-1000/v3-hang-launch.log 2>&1 &
sleep 70
pkill -INT -x cemu; sleep 25
pkill -x cemu; pkill -x gdb; sleep 3
