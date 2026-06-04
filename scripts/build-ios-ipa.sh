#!/usr/bin/env bash
# Build an unsigned iOS IPA for sideloading tools that re-sign the app later.
#
# Usage:
#   ./scripts/build-ios-ipa.sh
#   OUTPUT_DIR=out ./scripts/build-ios-ipa.sh

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

: "${OUTPUT_DIR:=build/ios/ipa}"
: "${IOS_RUST_TARGET:=aarch64-apple-ios}"
: "${IPA_NAME:=sparxie-ios.ipa}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 not found. Install it before building the iOS IPA." >&2
    exit 1
  fi
}

require_cmd flutter
require_cmd cargo
require_cmd xcodebuild
require_cmd ditto
require_cmd nm

if command -v rustup >/dev/null 2>&1; then
  rustup target add "$IOS_RUST_TARGET"
fi

echo ">>> Building Rust core for $IOS_RUST_TARGET"
(
  cd core
  cargo build --release --target "$IOS_RUST_TARGET"
)

CORE_LIB="core/target/$IOS_RUST_TARGET/release/libsparxie.a"
if [[ ! -f "$CORE_LIB" ]]; then
  echo "Missing Rust static library: $CORE_LIB" >&2
  exit 1
fi

echo ">>> Fetching Flutter dependencies"
flutter pub get

echo ">>> Building unsigned iOS app"
# Flutter 3.44 的 --no-codesign 仍强制验证 DEVELOPMENT_TEAM 非空，
# 改用 xcodebuild 直接构建以绕过 Flutter 的签名后检查。
(
  cd ios
  xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination 'generic/platform=ios' \
    -archivePath ../build/ios/archive/Runner.xcarchive \
    archive \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM=""
)
# 从 archive 中提取 .app 到 flutter build 期望的路径
mkdir -p build/ios/iphoneos
APP_IN_ARCHIVE="$(find build/ios/archive/Runner.xcarchive -name 'Runner.app' -type d | head -n1)"
if [[ -z "$APP_IN_ARCHIVE" || ! -d "$APP_IN_ARCHIVE" ]]; then
  echo "No Runner.app found in xcarchive" >&2
  exit 1
fi
cp -R "$APP_IN_ARCHIVE" build/ios/iphoneos/Runner.app

APP_BUNDLE="$(find build/ios/iphoneos -maxdepth 1 -type d -name '*.app' | head -n1)"
if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
  echo "No iOS app bundle found under build/ios/iphoneos" >&2
  exit 1
fi

APP_EXECUTABLE="$APP_BUNDLE/Runner"
if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "No Runner executable found in $APP_BUNDLE" >&2
  exit 1
fi

if ! nm -g "$APP_EXECUTABLE" | grep -q '_frb_get_rust_content_hash'; then
  echo "Rust FFI symbols are missing from $APP_EXECUTABLE" >&2
  echo "Check iOS linker settings: DEAD_CODE_STRIPPING must be disabled for Runner." >&2
  exit 1
fi

STAGE="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$STAGE/Payload" "$OUTPUT_DIR"
cp -R "$APP_BUNDLE" "$STAGE/Payload/"

IPA_PATH="$PROJECT_ROOT/$OUTPUT_DIR/$IPA_NAME"
rm -f "$IPA_PATH"
(
  cd "$STAGE"
  ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent Payload "$IPA_PATH"
)

echo ">>> IPA: $IPA_PATH"
