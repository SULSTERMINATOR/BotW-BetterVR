#!/usr/bin/env bash
# Rebuilds only the BetterVR layer (container, ~/bettervr-build at /work).
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive VCPKG_FORCE_SYSTEM_BINARIES=1 VCPKG_DEFAULT_BINARY_CACHE=/work/vcpkg-cache
apt-get update -qq
apt-get install -y --no-install-recommends build-essential cmake ninja-build git curl ca-certificates zip unzip tar pkg-config python3 libvulkan-dev libx11-dev libxxf86vm-dev libxcb-glx0-dev libx11-xcb-dev libxcb1-dev libgl-dev libegl-dev libwayland-dev libxkbcommon-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libxext-dev autoconf automake libtool >/dev/null
cd /work/BotW-BetterVR-Linux
cmake --build cmake-build-Linux-Release
echo "=== LAYER BUILD DONE ==="
