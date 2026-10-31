#!/usr/bin/env bash
# Keeps Cemu's threads on fixed cores while BotW runs: the busiest LatteThread (GPU command translation, on the
# critical path every frame) on the X4 core, the main emulated PPC core on an A720, everything else on the other
# big cores. About +3% fps over the scheduler's placement. Started in the background by launch-botw-vr.sh.
LATTE_CPU=7; MAIN_CPU=4; REST=2,3,5,6
# utilization clamp for the two critical threads: keeps their cores clocked up between bursts (0 = off)
UCLAMP=${BETTERVR_UCLAMP:-600}
for i in $(seq 1 120); do P=$(pgrep -x cemu) && break; sleep 1; done
[ -n "$P" ] || exit 0
while kill -0 "$P" 2>/dev/null; do
    LT=$(for t in /proc/$P/task/*; do [ "$(cat $t/comm 2>/dev/null)" = LatteThread ] && echo "$(awk '{print $14+$15}' $t/stat 2>/dev/null) $(basename $t)"; done | sort -n | tail -1 | awk '{print $2}')
    for t in /proc/$P/task/*; do
        tid=$(basename $t); name=$(cat $t/comm 2>/dev/null)
        if [ "$tid" = "$LT" ]; then want=$LATTE_CPU
        elif [ "$name" = "OSSched[core=1]" ]; then want=$MAIN_CPU
        else want=$REST; fi
        [ "$(taskset -pc $tid 2>/dev/null | awk -F': ' '{print $2}')" = "$want" ] || taskset -pc "$want" $tid >/dev/null 2>&1
        if [ "$UCLAMP" != 0 ] && [ "$want" != "$REST" ]; then
            uclampset -p $tid 2>/dev/null | grep -q "min: $UCLAMP " || uclampset -m "$UCLAMP" -p $tid >/dev/null 2>&1
        fi
    done
    sleep 10
done
