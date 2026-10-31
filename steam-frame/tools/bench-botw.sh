#!/usr/bin/env bash
# Headless BotW VR benchmark: boots the save (auto-pressing A through the menus), waits until gameplay,
# then measures game FPS and GPU clock. Usage: bench-botw.sh <label> [extra env assignments...]
#   e.g. bench-botw.sh baseline
#        bench-botw.sh fdm CEMU_FDM=1 CEMU_FDM_SIZE=1280x1320
LABEL=$1; shift
LOG=~/bettervr-build/BotW-BetterVR-Linux/BetterVR_log.txt
OUT=~/bettervr-build/bench-$LABEL.txt
CEMU_LOG=~/Applications/Cemu-BetterVR/portable/log.txt

pgrep -x cemu >/dev/null && { echo "Cemu already running"; exit 1; }
# run in the same display session as Steam (Game Mode / gamescope), not a possibly-closed nested desktop
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 GAMESCOPE_WAYLAND_DISPLAY=gamescope-0
unset WAYLAND_DISPLAY XAUTHORITY
rm -f "$LOG" # so the gameplay check below never reads a previous run
env BETTERVR_LINUX_CAPTURE_DIAG=1 BETTERVR_DEBUG_AUTOPRESS_A=1 BETTERVR_LINUX_FRAME_STATS=1 "$@" timeout 420 ~/Applications/Cemu-BetterVR/launch-botw-vr-old.sh > ~/bettervr-build/bench-$LABEL.launch.log 2>&1 &

hud() { grep -oE 'LinuxCopyHudToSwapchain #[0-9]+' "$LOG" 2>/dev/null | tail -1 | grep -oE '[0-9]+$'; }
fail() { echo "$LABEL: $1" | tee "$OUT"; pkill -x cemu; exit 1; }

# wait for gameplay: the input diagnostics report inMenu=false once the world is loaded
for i in $(seq 1 240); do
    sleep 1
    pgrep -x cemu >/dev/null || [ $i -lt 10 ] || fail "Cemu exited during boot"
    grep -q 'inMenu=true' "$LOG" 2>/dev/null && grep 'InputDiag' "$LOG" | tail -1 | grep -q 'inMenu=false' && break
done
grep 'InputDiag' "$LOG" | tail -1 | grep -q 'inMenu=false' || fail "never reached gameplay"
sleep 75 # let streaming/shader compilation settle
P=$(pgrep -x cemu)
if [ -n "$BENCH_PIN" ]; then
    # BENCH_PIN=<cpu>: main emulated PPC core thread onto that CPU, every other Cemu thread elsewhere
    for t in /proc/$P/task/*; do
        tid=$(basename $t); name=$(cat $t/comm)
        if [ "$name" = "OSSched[core=1]" ]; then taskset -pc "$BENCH_PIN" $tid >/dev/null; else taskset -pc "$(seq -s, 0 7 | tr , "\n" | grep -vx "$BENCH_PIN" | paste -sd,)" $tid >/dev/null 2>&1; fi
    done
fi
if [ -n "$BENCH_PIN_LATTE" ]; then
    # BENCH_PIN_LATTE=<cpu>[,<core1 cpu>]: busiest LatteThread onto <cpu>, OSSched[core=1] onto <core1 cpu>, others elsewhere
    LCPU=${BENCH_PIN_LATTE%%,*}; MCPU=${BENCH_PIN_LATTE#*,}; [ "$MCPU" = "$BENCH_PIN_LATTE" ] && MCPU=""
    LT=$(for t in /proc/$P/task/*; do [ "$(cat $t/comm)" = LatteThread ] && echo "$(awk '{print $14+$15}' $t/stat) $(basename $t)"; done | sort -n | tail -1 | awk '{print $2}')
    REST=$(seq 2 7 | grep -vx "$LCPU" | grep -vx "${MCPU:-x}" | paste -sd,)
    for t in /proc/$P/task/*; do tid=$(basename $t); name=$(cat $t/comm)
        if [ "$tid" = "$LT" ]; then taskset -pc "$LCPU" $tid >/dev/null
        elif [ -n "$MCPU" ] && [ "$name" = "OSSched[core=1]" ]; then taskset -pc "$MCPU" $tid >/dev/null
        else taskset -pc "$REST" $tid >/dev/null 2>&1; fi
    done
fi
FS0=$(grep -c '\[frame stats\]' "$LOG")

a=$(hud); until [ "$(hud)" != "$a" ]; do sleep 0.2; pgrep -x cemu >/dev/null || fail "Cemu exited"; done
t0=$(date +%s.%N); b=$(hud)
GPUS=$(mktemp)
( while :; do echo $(( $(cat /sys/class/devfreq/3d00000.gpu/cur_freq) / 1000000 )); sleep 0.25; done ) > "$GPUS" &
SAMPLER=$!
~/bettervr-build/tools/gpubusy.sh 8 $P $(pgrep -f vrcompositor | head -1) > ~/bettervr-build/bench-$LABEL.gpu.txt &
top -H -b -n 2 -d 5 -p $P | awk '/^top -/{n++} n==2' | head -30 > ~/bettervr-build/bench-$LABEL.threads.txt &
for w in 1 2; do until [ "$(hud)" != "$b" ]; do sleep 0.2; pgrep -x cemu >/dev/null || { kill $SAMPLER; fail "Cemu exited"; }; done; b=$(hud); done
t1=$(date +%s.%N); kill $SAMPLER
{
    echo "$LABEL: $(grep '\[frame stats\]' "$LOG" | tail -n +$((FS0 + 1)) | grep -oE 'cemu=[0-9.]+' | cut -d= -f2 | awk '{s+=$1; n++} END {if (n) printf "%.1f", s/n; else print "?"}') stereo fps (Cemu frame rate), $(echo "scale=1; 1000/($t1 - $t0)" | bc) HUD copies/s"
    echo "Main PPC thread ran on CPU(s): $(ps -L -o psr=,comm= -p $P | awk '$2=="OSSched[core=1]"{print $1}' | sort -u | tr '\n' ' ')"
    echo "GPU clock: $(sort -n "$GPUS" | uniq -c | awk -v t="$(wc -l < "$GPUS")" '{printf "%d MHz %.0f%%  ", $2, 100*$1/t}')"
    grep 'BetterVR FDM' "$CEMU_LOG"
} | tee "$OUT"
rm -f "$GPUS"
cp "$LOG" ~/bettervr-build/bench-$LABEL.bettervr.log
cp "$CEMU_LOG" ~/bettervr-build/bench-$LABEL.cemu.log
pkill -x cemu
sleep 5
