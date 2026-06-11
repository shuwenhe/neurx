#!/usr/bin/env bash
# install/tablet/install.sh
# Install NeurX AI OS on Android tablet
# For iPadOS: use install/tablet/install-ios.sh + Xcode
#
# Usage (on a Linux host with ADB connected tablet):
#   ./install/tablet/install.sh [--device <adb-serial>]
#
# Prerequisites:
#   - ADB installed on host (apt install adb)
#   - Android tablet with USB Debugging enabled, Android 14+
#   - NeurX compiled for android-arm64 (NDK cross-compile)

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE=""
ADB_INSTALL_DIR="/data/local/neurx"

for arg in "$@"; do
  case $arg in
    --device) shift; DEVICE="$1" ;;
    --device=*) DEVICE="${arg#--device=}" ;;
  esac
done

ADB_CMD="adb"
[ -n "$DEVICE" ] && ADB_CMD="adb -s $DEVICE"

echo "=== NeurX Tablet Install (Android) ==="
echo "    Device : ${DEVICE:-auto-detect}"
echo ""

# ── 1. Check ADB connection ──────────────────────────────────────────────────
echo "[1/5] Checking ADB connection..."
$ADB_CMD wait-for-device
$ADB_CMD shell echo "  [ok] device connected: $($ADB_CMD shell getprop ro.product.model)"

# ── 2. Cross-compile for arm64 ───────────────────────────────────────────────
echo "[2/5] Cross-compiling NeurX for android-arm64..."
make -C "$NEURX_ROOT" neurx \
    S_COMPILER="${S_COMPILER:-s}" \
    NEURX_ARCH=android-arm64 || {
    echo "  [warn] S compiler cross-compile not available — using pre-built bin/"
}

# ── 3. Push runtime to device ────────────────────────────────────────────────
echo "[3/5] Pushing NeurX runtime to device ($ADB_INSTALL_DIR)..."
$ADB_CMD shell "mkdir -p $ADB_INSTALL_DIR/{bin,lib,config,ir}"
$ADB_CMD push "$NEURX_ROOT/bin/android/"          "$ADB_INSTALL_DIR/bin/" 2>/dev/null || true
$ADB_CMD push "$NEURX_ROOT/build/ir/"             "$ADB_INSTALL_DIR/ir/"
$ADB_CMD push "$NEURX_ROOT/targets/tablet/"       "$ADB_INSTALL_DIR/config/target/"
$ADB_CMD push "$NEURX_ROOT/agent/"                "$ADB_INSTALL_DIR/lib/agent/"
$ADB_CMD push "$NEURX_ROOT/tool/"                 "$ADB_INSTALL_DIR/lib/tool/"
$ADB_CMD push "$NEURX_ROOT/memory/"               "$ADB_INSTALL_DIR/lib/memory/"

# ── 4. Set permissions ───────────────────────────────────────────────────────
echo "[4/5] Setting permissions..."
$ADB_CMD shell "chmod -R 755 $ADB_INSTALL_DIR/bin/" 2>/dev/null || true

# ── 5. Install APK (if built) ────────────────────────────────────────────────
echo "[5/5] Installing NeurX APK..."
APK_PATH="$NEURX_ROOT/bin/android/neurx.apk"
if [ -f "$APK_PATH" ]; then
    $ADB_CMD install -r "$APK_PATH"
    echo "  [ok] APK installed"
else
    echo "  [skip] APK not found at $APK_PATH — build with: make android"
fi

echo ""
echo "=== NeurX Tablet (Android) install complete ==="
echo "    Runtime dir : $ADB_INSTALL_DIR"
echo "    Launch CLI  : adb shell $ADB_INSTALL_DIR/bin/neurx-runtime --target tablet"
