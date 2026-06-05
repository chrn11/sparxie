#!/usr/bin/env bash
set -euo pipefail

# Build script for Sparxie native iOS IPA (TrollStore)
# Usage: ./scripts/build-native-ios-ipa.sh [OUTPUT_DIR]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PROJECT_ROOT/core"
NATIVE_DIR="$PROJECT_ROOT/native-ios"

OUTPUT_DIR="${1:-$PROJECT_ROOT/build/ios/ipa}"
RUST_TARGET="aarch64-apple-ios"
LIB_NAME="libsparxie.a"

echo "=== Sparxie Native iOS IPA Build ==="
echo "Project root: $PROJECT_ROOT"
echo "Output dir:  $OUTPUT_DIR"
echo ""

# Step 1: Install Rust iOS target
echo "[1/5] Installing Rust iOS target..."
rustup target add "$RUST_TARGET"

# Step 2: Build Rust staticlib
echo "[2/5] Building Rust staticlib for $RUST_TARGET..."
cargo build --release --target "$RUST_TARGET" --manifest-path "$CORE_DIR/Cargo.toml"

STATIC_LIB="$CORE_DIR/target/$RUST_TARGET/release/$LIB_NAME"
if [ ! -f "$STATIC_LIB" ]; then
    echo "ERROR: Static library not found at $STATIC_LIB"
    exit 1
fi

# Verify symbols exist
echo "   Verifying FFI symbols..."
nm -gU "$STATIC_LIB" | grep -q "sparxie_" || {
    echo "ERROR: No sparxie_* symbols found in static library"
    exit 1
}
echo "   FFI symbols verified."

# Step 3: Build iOS app with xcodebuild
echo "[3/5] Building iOS app with xcodebuild..."
xcodebuild build \
    -project "$NATIVE_DIR/Sparxie.xcodeproj" \
    -scheme Sparxie \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$PROJECT_ROOT/build/ios/derivedData" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    DEVELOPMENT_TEAM=0000000000 \
    | tail -5

# Find the .app bundle
APP_PATH="$(find "$PROJECT_ROOT/build/ios/derivedData" -name "Sparxie.app" -type d | head -1)"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Sparxie.app not found in derived data"
    exit 1
fi
echo "   App bundle: $APP_PATH"

# Step 4: Package IPA
echo "[4/5] Packaging IPA..."
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/Sparxie.app"

cd "$OUTPUT_DIR"
IPA_NAME="sparxie-trollstore.ipa"
zip -r "$IPA_NAME" Payload/

# Step 5: Cleanup and report
echo "[5/5] Done!"
rm -rf "$OUTPUT_DIR/Payload"

IPA_PATH="$OUTPUT_DIR/$IPA_NAME"
IPA_SIZE=$(du -h "$IPA_PATH" | cut -f1)
echo ""
echo "=== Build Complete ==="
echo "IPA: $IPA_PATH"
echo "Size: $IPA_SIZE"
echo ""
echo "Install via TrollStore on your device."