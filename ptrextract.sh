#!/usr/bin/env bash

WOWPATH="/Applications/Games/World of Warcraft Public Test"
INTERFACEPATH="$WOWPATH/BlizzardInterfaceCode/Interface"

echo "exportInterfaceFiles code" | tr -d "\n" | pbcopy
cd "$WOWPATH/World of Warcraft Test.app/Contents/MacOS"
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
