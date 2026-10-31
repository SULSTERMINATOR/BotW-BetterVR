#!/usr/bin/env bash
# Headless BotW VR run with the desktop mirror on: waits for gameplay, then saves screenshots of Cemu's window
# and the frame rate. Usage: shot-run.sh <label> [settle_seconds] [extra env assignments...]
LABEL=$1; SETTLE=${2:-40}; shift 2
OUT=~/bettervr-build/shots/$LABEL; mkdir -p "$OUT"; rm -f "$OUT"/*
LOG=~/bettervr-build/BotW-BetterVR-Linux/BetterVR_log.txt
pgrep -x cemu >/dev/null && { echo "Cemu already running"; exit 1; }
export DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 GAMESCOPE_WAYLAND_DISPLAY=gamescope-0
unset WAYLAND_DISPLAY XAUTHORITY
rm -f "$LOG"
env BETTERVR_LINUX_CAPTURE_DIAG=1 BETTERVR_DEBUG_AUTOPRESS_A=1 BETTERVR_LINUX_FRAME_STATS=1 BETTERVR_DESKTOP_MIRROR=1 BETTERVR_DESKTOP_MIRROR_EYE=${MIRROR_EYE:-left} "$@" \
    timeout 400 ~/Applications/Cemu-BetterVR/launch-botw-vr-old.sh > "$OUT/launch.log" 2>&1 &
for i in $(seq 1 240); do
    sleep 1
    pgrep -x cemu >/dev/null || [ $i -lt 10 ] || { echo "$LABEL: Cemu exited during boot"; exit 1; }
    grep -q 'inMenu=true' "$LOG" 2>/dev/null && grep 'InputDiag' "$LOG" | tail -1 | grep -q 'inMenu=false' && break
done
grep 'InputDiag' "$LOG" | tail -1 | grep -q 'inMenu=false' || { echo "$LABEL: never reached gameplay"; cp "$LOG" "$OUT/bettervr.log"; pkill -x cemu; exit 1; }
sleep "$SETTLE"
FS0=$(grep -c '\[frame stats\]' "$LOG")
for n in 1 2 3; do
    W=$(xwininfo -root -tree 2>/dev/null | grep -iE '"(Cemu|.*Zelda|.*Breath)' | head -1 | awk '{print $1}')
    [ -n "$W" ] && xwd -silent -id "$W" -out "$OUT/s$n.xwd" && ffmpeg -loglevel error -y -i "$OUT/s$n.xwd" -vf scale=960:-1 "$OUT/s$n.png" && rm -f "$OUT/s$n.xwd"
    sleep 5
done
echo "$LABEL: $(grep '\[frame stats\]' "$LOG" | tail -n +$((FS0 + 1)) | grep -oE 'cemu=[0-9.]+' | cut -d= -f2 | awk '{s+=$1; n++} END {if (n) printf "%.1f", s/n; else print "?"}') fps; shots in $OUT"
cp "$LOG" "$OUT/bettervr.log"; cp ~/Applications/Cemu-BetterVR/portable/log.txt "$OUT/cemu.log"
pkill -x cemu; sleep 5
