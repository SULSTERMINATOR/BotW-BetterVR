#!/usr/bin/env bash
# bench2.sh LABEL v3|old [ENV=..]   headless: autopress A to gameplay, settle 75 s, then average Cemu's swap rate
# (CEMU_CORE_STATS lattestats, 5 s windows) over 60 s. Run under the heavy lock.
LABEL=$1; WHICH=$2; shift 2
OUT=~/bettervr-build/fleet/cpu/port/bench-$LABEL; mkdir -p $OUT
CEMU_LOG=~/Applications/Cemu-BetterVR/portable/log.txt
if [ "$WHICH" = v3 ]; then L=~/bettervr-build/fleet/cpu/port/launch-v3.sh; LOG=~/bettervr-build/fleet/cpu/port/layer-v3/BetterVR_log.txt; PAT='BenchDiag'
else L=~/Applications/Cemu-BetterVR/launch-botw-vr.sh; LOG=~/bettervr-build/BotW-BetterVR-Linux/BetterVR_log.txt; PAT='InputDiag'; fi
pgrep -x cemu >/dev/null && { echo "Cemu already running"; exit 1; }
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 GAMESCOPE_WAYLAND_DISPLAY=gamescope-0
unset WAYLAND_DISPLAY XAUTHORITY
rm -f "$LOG"
env CEMU_CORE_STATS=1 BETTERVR_DEBUG_AUTOPRESS_A=1 BETTERVR_LINUX_BENCH_DIAG=1 BETTERVR_LINUX_CAPTURE_DIAG=1 "$@" timeout 400 $L > $OUT/launch.log 2>&1 &
fail() { echo "$LABEL: $1" | tee $OUT/result.txt; cp "$LOG" $OUT/bettervr.log 2>/dev/null; cp $CEMU_LOG $OUT/cemu.log; pkill -x cemu; sleep 5; exit 1; }
for i in $(seq 1 240); do
    sleep 1
    pgrep -x cemu >/dev/null || [ $i -lt 15 ] || fail "Cemu exited during boot"
    grep -q 'inMenu=true' "$LOG" 2>/dev/null && grep "$PAT" "$LOG" | tail -1 | grep -q 'inMenu=false' && break
done
grep "$PAT" "$LOG" 2>/dev/null | tail -1 | grep -q 'inMenu=false' || fail "never reached gameplay"
sleep 75
N0=$(grep -c lattestats $CEMU_LOG)
sleep 60
pgrep -x cemu >/dev/null || fail "Cemu exited"
FPS=$(grep lattestats $CEMU_LOG | tail -n +$((N0+1)) | grep -oE 'wall/frame=[0-9.]+' | cut -d= -f2 | awk '{s+=1000/$1; n++} END {if(n) printf "%.1f (%d windows)", s/n, n; else print "?"}')
echo "$LABEL: $FPS swaps/s" | tee $OUT/result.txt
cp "$LOG" $OUT/bettervr.log; cp $CEMU_LOG $OUT/cemu.log
pkill -x cemu; sleep 5
