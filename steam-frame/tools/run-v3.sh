#!/usr/bin/env bash
# run under the heavy lock: back up settings.xml, run bench2/shot, restore settings.xml and re-link the normal pack
S=~/Applications/Cemu-BetterVR/portable/settings.xml
cp -p $S /tmp/claude-1000/settings.xml.pre-v3
"$@"; rc=$?
pgrep -x cemu >/dev/null && { pkill -x cemu; sleep 5; }
cp -p /tmp/claude-1000/settings.xml.pre-v3 $S
ln -sfn ~/bettervr-build/BotW-BetterVR-Linux/resources/BreathOfTheWild_BetterVR ~/Applications/Cemu-BetterVR/portable/graphicPacks/BreathOfTheWild_BetterVR
exit $rc
