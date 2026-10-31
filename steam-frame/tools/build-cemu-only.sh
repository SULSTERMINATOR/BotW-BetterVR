#!/usr/bin/env bash
# Runs inside an ubuntu:24.04 arm64 container with ~/bettervr-build mounted at /work.
# Builds (1) Cemu 3310f3b with BetterVR hook symbols exported, (2) the BetterVR Linux layer.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
export VCPKG_FORCE_SYSTEM_BINARIES=1   # required by vcpkg on arm64 Linux
export VCPKG_DEFAULT_BINARY_CACHE=/work/vcpkg-cache   # survives --rm containers
mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"

apt-get update -qq
  apt-get install -y --no-install-recommends \
    build-essential clang cmake ninja-build git curl ca-certificates zip unzip tar pkg-config \
    autoconf automake autoconf-archive libtool nasm python3 python3-jinja2 bison flex gettext \
    libgtk-3-dev libpulse-dev libsecret-1-dev libsystemd-dev libudev-dev libbluetooth-dev \
    libgcrypt20-dev freeglut3-dev libglm-dev libusb-1.0-0-dev libx11-dev libxrandr-dev \
    libxinerama-dev libxcursor-dev libxi-dev libxext-dev libxkbcommon-dev libwayland-dev \
    wayland-protocols libegl-dev libgl-dev libvulkan-dev linux-libc-dev llvm libxxf86vm-dev libxcb-glx0-dev libx11-xcb-dev libxcb1-dev

# ---- 1. Patched Cemu ----
cd /work/cemu-src
[ -x dependencies/vcpkg/vcpkg ] || bash ./dependencies/vcpkg/bootstrap-vcpkg.sh -disableMetrics
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_EXE_LINKER_FLAGS=-Wl,--export-dynamic
cmake --build build
echo "=== CEMU BUILD DONE ==="

