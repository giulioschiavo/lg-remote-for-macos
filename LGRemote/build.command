#!/bin/zsh
set -eu
cd "$(dirname "$0")"
APP="dist/Telecomando LG.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build-cache
swiftc -swift-version 5 -parse-as-library -O -module-cache-path .build-cache -target arm64-apple-macosx13.0 Sources/*.swift -o "$APP/Contents/MacOS/LGRemote" -framework Cocoa -framework SwiftUI -framework Security
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns Assets/AppIconLight.png Assets/AppIconDark.png "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "App creata: $PWD/$APP"
