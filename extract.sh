#!/usr/bin/env bash

WOWPATH="/Applications/Games/World of Warcraft"
INTERFACEPATH="$WOWPATH/BlizzardInterfaceCode/Interface"

echo "exportInterfaceFiles code" | tr -d "\n" | pbcopy
cd "$WOWPATH/World of Warcraft.app/Contents/MacOS"
./World\ of\ Warcraft -console
cd -

rm -r AddOns FrameXML LCDXML SharedXML

mv \
  "$INTERFACEPATH/AddOns" \
  "$INTERFACEPATH/FrameXML" \
  "$INTERFACEPATH/LCDXML" \
  "$INTERFACEPATH/SharedXML" \
  .
./fix_perms.sh
git add AddOns FrameXML LCDXML SharedXML
