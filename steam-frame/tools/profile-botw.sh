#!/usr/bin/env bash
# Samples GPU frequency and Cemu per-thread CPU while BotW VR runs, to tell GPU-bound from CPU-bound.
# Usage: profile-botw.sh [seconds]   (writes ~/bettervr-build/profile-<time>.txt)
DUR=${1:-60}
OUT=~/bettervr-build/profile-$(date +%H%M%S).txt
GPU=/sys/class/devfreq/3d00000.gpu/cur_freq
P=$(pgrep -x cemu) || { echo "Cemu is not running"; exit 1; }

# GPU clock every 250ms; simple_ondemand only holds the top clock when the GPU is saturated
( for ((i = 0; i < DUR * 4; i++)); do echo $(( $(cat $GPU) / 1000000 )); sleep 0.25; done ) > "$OUT.gpu" &
SAMPLER=$!
# per-thread CPU averaged over the same window
top -H -b -d "$DUR" -n 2 -p "$P" | awk '/^top/{n++} n==2' | sed -n '7,18p' > "$OUT.threads"
wait $SAMPLER

{
    echo "== GPU frequency over ${DUR}s (max 903 MHz)"
    sort -n "$OUT.gpu" | uniq -c | awk -v t="$(wc -l < "$OUT.gpu")" '{printf "%5d MHz  %5.1f%%\n", $2, 100*$1/t}'
    echo
    echo "== Cemu threads (%CPU, 100 = one full core)"
    awk '{printf "%6s%%  %s\n", $9, $12}' "$OUT.threads"
} > "$OUT"
rm -f "$OUT.gpu" "$OUT.threads"
cat "$OUT"
