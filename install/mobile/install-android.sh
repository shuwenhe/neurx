#!/usr/bin/env bash
# install/mobile/install-android.sh
# Install NeurX AI OS on Android phone
#
# Usage (Linux/macOS host, phone connected via USB):
#   ./install/mobile/install-android.sh [--device <adb-serial>] [--apk-only]
#
# Prerequisites:
#   - ADB on host
#   - Android 14+ phone with USB Debugging enabled
#   - arm64-v8a build of NeurX (NDK r26)

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE=""
APK_ONLY=false
ADB_INSTALL_DIR="/data/local/neurx"

for arg in "$@"; do
  case $arg in
    --device=*) DEVICE="${arg#--device=}" ;;
    --apk-only) APK_ONLY=true ;;
  esac
done

ADB_CMD="adb"; [ -n "$DEVICE" ] && ADB_CMD="adb -s $DEVICE"

echo "=== NeurX Mobile Install (Android Phone) ==="
$ADB_CMD wait-for-device
echo "    Model : $($ADB_CMD shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
echo "    ABI   : $($ADB_CMD shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
echo ""

if [ "$APK_ONLY" = "false" ]; then
    echo "[1/4] Cross-compiling NeurX for android-arm64..."
    make -C "$NEURX_ROOT" neurx \
        S_COMPILER="${S_COMPILER:-s}" \
        NEURX_ARCH=android-arm64 \
        NEURX_PROFILE=mobile || echo "  [warn] build skipped — using prebuilt"

    echo "[2/4] Pushing runtime..."
    $ADB_CMD shell "mkdir -p $ADB_INSTALL_DIR/{bin,lib,config,ir}"
    $ADB_CMD push "$NEURX_ROOT/build/ir/"           "$ADB_INSTALL_DIR/ir/"
    $ADB_CMD push "$NEURX_ROOT/targets/mobile/"     "$ADB_INSTALL_DIR/config/target/"
    $ADB_CMD push "$NEURX_ROOT/agent/"              "$ADB_INSTALL_DIR/lib/agent/"
    $ADB_CMD push "$NEURX_ROOT/tool/"               "$ADB_INSTALL_DIR/lib/tool/"
    $ADB_CMD push "$NEURX_ROOT/memory/"             "$ADB_INSTALL_DIR/lib/memory/"
    $ADB_CMD shell "chmod 755 $ADB_INSTALL_DIR/bin/*" 2>/dev/null || true
fi

echo "[3/4] Installing APK..."
APK="$NEURX_ROOT/bin/android/neurx.apk"
if [ -f "$APK" ]; then
    $ADB_CMD install -r "$APK" && echo "  [ok] APK installed"
else
    echo "  [skip] APK not found — run: make android"
fi

echo "[4/4] Writing on-device config..."
$ADB_CMD shell "cat > $ADB_INSTALL_DIR/config/runtime.env << 'EOF'
NEURX_TARGET=mobile
NEURX_PRECISION=int8
NEURX_MAX_POWER_MW=2500
NEURX_ON_DEVICE_ONLY=true
EOF"

echo ""
echo "=== NeurX Mobile (Android) install complete ==="
echo "    Launch: adb shell $ADB_INSTALL_DIR/bin/neurx-runtime --target mobile"
