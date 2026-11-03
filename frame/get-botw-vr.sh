#!/usr/bin/env bash
# One-command install and update for BotW VR on the Steam Frame:
#   curl -fsSL https://raw.githubusercontent.com/SULSTERMINATOR/BotW-BetterVR/main/frame/get-botw-vr.sh | bash
# Run it again (or the "Update BotW VR" shortcut it creates) to update. Your game path, saves, settings and shader cache are kept.
# Optional: pass the path to your .wua / U-King.rpx on first install:  ... | bash -s -- /path/to/BotW.wua
set -e
REPO=SULSTERMINATOR/BotW-BetterVR
DEST="${BOTW_VR_DIR:-$HOME/Applications/BotW-VR}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

echo "Checking for the latest BotW VR release..."
curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" -o "$TMP/release.json"
asset() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(next((a["browser_download_url"] for a in r["assets"] if a["name"]==sys.argv[2]),""))' "$TMP/release.json" "$1"; }
TAG=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tag_name"])' "$TMP/release.json")
BUNDLE_URL=$(asset BotW-VR-SteamFrame-arm64.zip)
CACHE_URL=$(asset BotW-VR-shadercache.zip)
[ -n "$BUNDLE_URL" ] || { echo "Release $TAG has no bundle zip, try again later." >&2; exit 1; }

if [ "$(cat "$DEST/.version" 2>/dev/null)" = "$TAG" ]; then
    echo "BotW VR is up to date ($TAG)."
else
    echo "Downloading $TAG..."
    curl -fL --progress-bar "$BUNDLE_URL" -o "$TMP/bundle.zip"
    python3 -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for i in z.infolist():
    p = z.extract(i, sys.argv[2])
    if i.external_attr >> 16 & 0o111: __import__("os").chmod(p, 0o755)' "$TMP/bundle.zip" "$TMP/new"
    NEW="$TMP/new/BotW-VR"
    # keep the user's own files on update
    for keep in botw-vr.conf portable/settings.xml portable/controllerProfiles/controller0.xml mlc01 portable/shaderCache; do
        [ -e "$DEST/$keep" ] && rm -rf "${NEW:?}/$keep"
    done
    mkdir -p "$DEST"
    cp -a "$NEW/." "$DEST/"
    echo "$TAG" > "$DEST/.version"
    echo "Installed $TAG to $DEST"
fi

# Shared shader cache: only replaces a local cache that is smaller (less of the game seen)
if [ -n "$CACHE_URL" ]; then
    curl -fsSL "$CACHE_URL" -o "$TMP/cache.zip"
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$TMP/cache.zip" "$TMP/cache"
    T="$DEST/portable/shaderCache/transferable"; mkdir -p "$T"
    for f in "$TMP"/cache/*.bin; do
        b=$(basename "$f")
        if [ ! -f "$T/$b" ] || [ "$(stat -c %s "$f")" -gt "$(stat -c %s "$T/$b")" ]; then
            cp "$f" "$T/$b" && echo "Shader cache updated: $b"
        fi
    done
fi

# Update shortcut on the desktop and in the app menu
cp "$DEST/get-botw-vr.sh" "$DEST/update.sh" 2>/dev/null || true
for d in "$HOME/Desktop" "$HOME/.local/share/applications"; do
    mkdir -p "$d"
    cat > "$d/update-botw-vr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Update BotW VR
Exec=konsole --hold -e bash "$DEST/update.sh"
Icon=system-software-update
Terminal=false
EOF
    chmod +x "$d/update-botw-vr.desktop"
done

if [ ! -f "$DEST/botw-vr.conf" ]; then
    echo
    "$DEST/install.sh" "$@" || exit 1
else
    echo
    echo "Done. Launch BotW VR from your Steam library."
fi
