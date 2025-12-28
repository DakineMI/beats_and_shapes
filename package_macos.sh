#!/bin/bash
set -e

APP_NAME="BeatsAndShapes"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "Building ${APP_NAME} in release mode..."
cd BeatsAndShapes
swift build -c release

echo "Creating .app bundle structure..."
rm -rf "../${APP_DIR}"
mkdir -p "../${APP_DIR}/Contents/MacOS"
mkdir -p "../${APP_DIR}/Contents/Resources"

echo "Copying binary and assets..."
cp "${BUILD_DIR}/${APP_NAME}" "../${APP_DIR}/Contents/MacOS/"
if [ -f "../AppIcon.icns" ]; then
    cp "../AppIcon.icns" "../${APP_DIR}/Contents/Resources/"
fi

# Copy media assets if they exist
if [ -f "../splash.mp4" ]; then
    cp "../splash.mp4" "../${APP_DIR}/Contents/Resources/"
fi

echo "Creating Info.plist..."
cat > "../${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.madbadbrax.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Success! ${APP_DIR} created in the root directory."
