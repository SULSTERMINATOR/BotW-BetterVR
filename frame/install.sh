#!/usr/bin/env bash
# One-time setup: point the bundle at your own BotW dump and fill in Cemu's paths.
# Usage: ./install.sh /path/to/BotW.wua        (or the game's code/U-King.rpx)
set -e
D="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
GAME="$1"
if [ -z "$GAME" ]; then
    echo "Looking for a BotW dump in your home folder..."
    GAME=$(find "$HOME" -maxdepth 5 \( -iname "*zelda*.wua" -o -iname "*breath*.wua" -o -path "*101c9400*/code/U-King.rpx" \) 2>/dev/null | head -1)
fi
if [ -z "$GAME" ] || [ ! -f "$GAME" ]; then
    echo "Couldn't find the game. Run again with the path to your .wua (or code/U-King.rpx):" >&2
    echo "  $D/install.sh /home/steamos/Games/BotW.wua" >&2
    exit 1
fi
GAME="$(readlink -f "$GAME")"
case "$GAME" in
    *.wua|*.WUA|*/U-King.rpx) ;;
    *) echo "Expected a .wua file or U-King.rpx, got: $GAME" >&2; exit 1 ;;
esac

printf 'BOTW_GAME=%q\n' "$GAME" > "$D/botw-vr.conf"
# A game already installed into a Cemu mlc01 keeps its update, DLC and saves there, so use that mlc01
MLC="$D/mlc01"
case "$GAME" in
    */usr/title/00050000/101c9400/code/U-King.rpx) MLC="${GAME%/usr/title/00050000/101c9400/code/U-King.rpx}" ;;
esac
mkdir -p "$MLC"
sed -e "s|__BUNDLE__/mlc01|$MLC|g" -e "s|__GAMEDIR__|$(dirname "$GAME")|g" "$D/portable/settings.xml.template" > "$D/portable/settings.xml"
chmod +x "$D/Cemu" "$D"/*.sh

echo
echo "Set up for: $GAME"
echo "Saves, update and DLC folder (mlc01): $MLC"
echo
echo "Next:"
echo "  1. Steam (Desktop Mode) > Games > Add a Non-Steam Game > Browse > $D/botw-vr.sh"
echo "  2. Start SteamVR once, launch BotW VR from your library."
echo "  3. SteamVR settings > Video > Per-application settings > BotW VR: set refresh rate to 90 Hz."
echo "     (At the default 72 Hz SteamVR locks the game to 24 fps.)"
echo "Log file if something goes wrong: $D/botw-vr.log"
