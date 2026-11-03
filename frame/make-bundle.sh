#!/usr/bin/env bash
# Assemble the self-contained BotW VR bundle from the working install. No keys, saves, shader caches or personal paths.
set -e
SRC=~/Applications/Cemu-BetterVR
V3=~/bettervr-build/bvr-v3
OUT=/tmp/botwvr-bundle
B=$OUT/BotW-VR
rm -rf "$OUT"; mkdir -p "$B/layer" "$B/portable/gameProfiles" "$B/portable/controllerProfiles" "$B/portable/graphicPacks/downloadedGraphicPacks"
cp "$SRC/Cemu" "$SRC/libhugeshim.so" "$SRC/pin-threads.sh" "$B/"
cp -r "$SRC/resources" "$B/"
cp -r "$V3/resources/BreathOfTheWild_BetterVR" "$B/resources/"
cp "$V3/launch-bettervr.sh" "$B/"
cp ~/bettervr-build/fleet/cpu/port/layer-v3/BetterVR_Layer.so ~/bettervr-build/fleet/cpu/port/layer-v3/BetterVR_Layer.json "$B/layer/"
cp "$SRC/portable/gameProfiles/00050000101c9400.ini" "$B/portable/gameProfiles/"
cp "$SRC/portable/controllerProfiles/controller0.xml" "$B/portable/controllerProfiles/"
cp -r "$SRC/portable/graphicPacks/BreathOfTheWild_Graphics_BetterVR" "$B/portable/graphicPacks/"
cp -r "$SRC/portable/graphicPacks/downloadedGraphicPacks/BreathOfTheWild" "$B/portable/graphicPacks/downloadedGraphicPacks/"
cp "$SRC/portable/graphicPacks/downloadedGraphicPacks/version.txt" "$B/portable/graphicPacks/downloadedGraphicPacks/" 2>/dev/null || true
python3 - "$SRC/portable/settings.xml" "$B/portable/settings.xml.template" <<'EOF'
import re, sys
s = open(sys.argv[1]).read()
s = s.replace("/home/steamos/Emulation/wiiu-local/mlc01", "__BUNDLE__/mlc01")
s = s.replace("/home/steamos/Emulation/wiiu-local/games", "__GAMEDIR__")
s = re.sub(r"<RecentLaunchFiles>.*?</RecentLaunchFiles>", "<RecentLaunchFiles/>", s, flags=re.S)
assert "/home/steamos" not in s, [l for l in s.splitlines() if "/home/steamos" in l]
open(sys.argv[2], "w").write(s)
EOF
cp /tmp/bundle-src/botw-vr.sh /tmp/bundle-src/install.sh /tmp/bundle-src/get-botw-vr.sh /tmp/bundle-src/README.md "$B/"
chmod +x "$B"/*.sh "$B/Cemu"
grep -rl "/home/steamos" "$B" --include=*.json --include=*.xml --include=*.ini --include=*.template && echo "WARNING: personal paths above" || true
# zip(1) on SteamOS aborts with a buffer overflow on this tree; Python's zipfile keeps the exec bits
cd "$OUT" && python3 - <<'EOF'
import os, zipfile
with zipfile.ZipFile("BotW-VR-SteamFrame-arm64.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk("BotW-VR"):
        for f in files:
            p = os.path.join(root, f)
            with open(p, "rb") as fh:
                z.writestr(zipfile.ZipInfo.from_file(p), fh.read(), zipfile.ZIP_DEFLATED)
EOF
# shared shader cache, a separate release asset (transferable caches only; precompiled spirv is rebuilt locally)
python3 - "$SRC/portable/shaderCache/transferable" <<'EOF'
import os, sys, zipfile
with zipfile.ZipFile("BotW-VR-shadercache.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(os.listdir(sys.argv[1])):
        if f.endswith(".bin"):
            z.write(os.path.join(sys.argv[1], f), f)
EOF
ls -la BotW-VR-SteamFrame-arm64.zip BotW-VR-shadercache.zip && du -sh BotW-VR
