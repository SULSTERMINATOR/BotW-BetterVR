#!/usr/bin/env bash
# container build of the v3 (ctrlaltdle-based) layer; run via podman with ~/bettervr-build at /work
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y --no-install-recommends g++ libvulkan-dev >/dev/null
V=/work/BotW-BetterVR-Linux/cmake-build-Linux-Release/vcpkg_installed/arm64-linux; I=/work/fleet/cpu/port/inc
cd /work/bvr-v3
EXTRA_INCLUDES="-I $I" EXTRA_LDFLAGS="-L $V/lib -Wl,-Bsymbolic" EXTRA_LIBS="-ljsoncpp" OPT_FLAGS="-O2 -g1 ${EXTRA_OPT:-}" bash build-linux/build.sh
echo "=== V3 BUILD DONE ==="
