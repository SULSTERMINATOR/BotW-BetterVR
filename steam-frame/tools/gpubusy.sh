#!/usr/bin/env bash
# GPU busy % per process over $1 seconds, from DRM fdinfo drm-engine-gpu. Usage: gpubusy.sh <secs> <pid>...
D=$1; shift
snap() { for p in "$@"; do echo "$p $(awk '/^drm-engine-gpu/{s+=$2} END{printf "%d", s}' /proc/$p/fdinfo/* 2>/dev/null)"; done; }
A=$(snap "$@"); sleep "$D"; B=$(snap "$@")
join <(echo "$A" | sort) <(echo "$B" | sort) | while read p a b; do echo "$(cat /proc/$p/comm 2>/dev/null) $(echo "scale=1; ($b-$a)/($D*10000000)" | bc)%"; done
