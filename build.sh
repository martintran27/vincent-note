#!/bin/zsh
# ./build.sh        → build OnThi.app
# ./build.sh test   → run the answer-parsing check
set -euo pipefail
cd "${0:A:h}"
# ponytail: pin the target; swiftc's default here stamps minos 28.0 and macOS refuses to launch.
# 15.2 = first release with SCScreenshotManager.captureImage(in:).
TARGET=(-target "$(uname -m)-apple-macos15.2")

if [[ "${1:-}" == "test" ]]; then
  mkdir -p .build
  swiftc -O "${TARGET[@]}" Sources/Quiz.swift tests/main.swift -o .build/check
  .build/check
  exit
fi

APP="Vincent Note.app"
rm -rf "$APP" OnThi.app
mkdir -p "$APP/Contents/MacOS"
swiftc -O "${TARGET[@]}" Sources/*.swift -o "$APP/Contents/MacOS/VincentNote"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.onthi</string>
  <key>CFBundleName</key><string>Vincent Note</string>
  <key>CFBundleDisplayName</key><string>Vincent Note</string>
  <key>CFBundleExecutable</key><string>VincentNote</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $PWD/$APP"
