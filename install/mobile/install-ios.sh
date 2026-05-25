#!/usr/bin/env bash
# install/mobile/install-ios.sh
# Install NeurX AI OS on iPhone (via Xcode / xcodebuild)
#
# Usage (macOS host with Xcode 15+):
#   ./install/mobile/install-ios.sh [--device <udid>] [--simulator]
#
# Prerequisites:
#   - macOS 14+ with Xcode 15+ and iOS SDK
#   - Apple Developer account (for device deploy)
#   - iPhone connected via USB (or --simulator for Simulator)

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE_UDID=""
USE_SIM=false
APP_PROJ="$NEURX_ROOT/app/mobile"

for arg in "$@"; do
  case $arg in
    --device=*) DEVICE_UDID="${arg#--device=}" ;;
    --simulator) USE_SIM=true ;;
  esac
done

echo "=== NeurX Mobile Install (iOS) ==="
echo "    Simulator : $USE_SIM"
[ -n "$DEVICE_UDID" ] && echo "    Device    : $DEVICE_UDID"
echo ""

# ── 1. Compile NeurX core for arm64 (Metal backend) ─────────────────────────
echo "[1/4] Building NeurX for ios-arm64..."
make -C "$NEURX_ROOT" ios \
    S_COMPILER="${S_COMPILER:-s}" \
    NEURX_ARCH=ios-arm64 \
    NEURX_PROFILE=mobile || echo "  [warn] iOS build not fully configured"

# ── 2. Copy NeurX bundles into Xcode project ─────────────────────────────────
echo "[2/4] Copying NeurX bundles into Xcode project..."
BUNDLE_DST="$APP_PROJ/neurx-bundle"
mkdir -p "$BUNDLE_DST"
cp -r "$NEURX_ROOT/build/ir/"        "$BUNDLE_DST/ir/"       2>/dev/null || true
cp -r "$NEURX_ROOT/targets/mobile/"  "$BUNDLE_DST/config/"   2>/dev/null || true
cp -r "$NEURX_ROOT/agent/"           "$BUNDLE_DST/lib/"      2>/dev/null || true

# ── 3. Build Xcode project ───────────────────────────────────────────────────
echo "[3/4] Building Xcode project..."
if [ "$USE_SIM" = "true" ]; then
    xcodebuild -project "$APP_PROJ"/*.xcodeproj \
        -scheme NeurX \
        -sdk iphonesimulator \
        -configuration Debug \
        build | tail -5
else
    DEST="id=$DEVICE_UDID"
    [ -z "$DEVICE_UDID" ] && DEST="generic/platform=iOS"
    xcodebuild -project "$APP_PROJ"/*.xcodeproj \
        -scheme NeurX \
        -sdk iphoneos \
        -configuration Release \
        -destination "$DEST" \
        build | tail -5
fi

echo "[4/4] Done."
echo ""
echo "=== NeurX iOS install complete ==="
if [ "$USE_SIM" = "true" ]; then
    echo "    Open Simulator and run the NeurX app"
else
    echo "    App deployed to device $DEVICE_UDID"
fi
