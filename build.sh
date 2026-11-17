#!/bin/zsh
# ./build.sh               → build "Vincent Note.app"
# ./build.sh test          → run the checks
# ./build.sh setup-signing → one-time stable signing identity (keeps Screen Recording grant)
set -euo pipefail
cd "${0:A:h}"
# ponytail: pin the target; swiftc's default here stamps minos 28.0 and macOS refuses to launch.
# 15.2 = first release with SCScreenshotManager.captureImage(in:).
TARGET=(-target "$(uname -m)-apple-macos15.2")

SIGN_NAME="Vincent Note Local Signing"

# One-time: self-signed code-signing cert in a project-local keychain (.signing/, gitignored).
# The login keychain and its search list are not touched.
if [[ "${1:-}" == "setup-signing" ]]; then
  [[ -e .signing/vincent.keychain-db ]] && { echo ".signing/ already set up"; exit; }
  mkdir -p .signing && cd .signing
  printf '[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=%s\n[ext]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n' "$SIGN_NAME" > cert.cnf
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config cert.cnf -keyout key.pem -out cert.pem
  PASS=$(openssl rand -hex 16); print -r -- "$PASS" > keychain-password; chmod 600 keychain-password key.pem
  openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out cert.p12 -passout pass:"$PASS"
  security create-keychain -p "$PASS" "$PWD/vincent.keychain-db"
  security unlock-keychain -p "$PASS" "$PWD/vincent.keychain-db"
  security import cert.p12 -k "$PWD/vincent.keychain-db" -P "$PASS" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple: -s -k "$PASS" "$PWD/vincent.keychain-db" >/dev/null
  echo "Signing identity ready in .signing/"
  exit
fi

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
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
# A stable local identity keeps the Screen Recording grant across rebuilds (ad-hoc changes every build).
KC="$PWD/.signing/vincent.keychain-db"
if [[ -f "$KC" ]]; then
  security unlock-keychain -p "$(cat .signing/keychain-password)" "$KC"
  codesign --force --keychain "$KC" --sign "$SIGN_NAME" "$APP"
else
  echo "No .signing/ found: ad-hoc signing, Screen Recording must be re-granted. Run ./build.sh setup-signing once."
  codesign --force --sign - "$APP"
fi
echo "Built $PWD/$APP"
