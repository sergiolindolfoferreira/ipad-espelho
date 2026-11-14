#!/bin/zsh
# Compila o iPad Espelho e cria "iPad Espelho.app" nesta pasta.
set -e
cd "$(dirname "$0")"
APP="iPad Espelho.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/iPadEspelho" \
  -framework Cocoa -framework AVFoundation -framework CoreMediaIO
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>iPad Espelho</string>
  <key>CFBundleDisplayName</key><string>iPad Espelho</string>
  <key>CFBundleIdentifier</key><string>local.ipad-espelho</string>
  <key>CFBundleExecutable</key><string>iPadEspelho</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Para mostrar o ecrã do iPad ligado por cabo.</string>
</dict></plist>
EOF
codesign --force --deep --sign - "$APP"
echo "Pronto: $(pwd)/$APP"
