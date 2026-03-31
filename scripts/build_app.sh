#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FocusFloat"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift_files=("${(@f)$(find "$ROOT_DIR/Sources" -name '*.swift' -print | sort)}")

xcrun swiftc \
  -parse-as-library \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  -module-name "$APP_NAME" \
  -framework AppKit \
  -framework SwiftUI \
  -framework EventKit \
  "${swift_files[@]}" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Config/Info.plist" "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built app: $APP_DIR"
