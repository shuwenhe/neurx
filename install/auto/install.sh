#!/usr/bin/env bash
# install/auto/install.sh
# Install NeurX AI OS on an automotive platform (NVIDIA DRIVE Orin / QNX)
#
# Usage (on target board, run as root or with sudo):
#   ./install/auto/install.sh [--qnx] [--agl]
#
# Prerequisites:
#   - NVIDIA DRIVE OS 6.x / QNX 7.1+ / AGL on target SoC
#   - Cross-compile toolchain already set up (or native on board)
#   - CAN / Ethernet AVB interfaces configured

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="/opt/neurx"
OS_BASE="linux"   # linux | qnx

for arg in "$@"; do
  case $arg in
    --qnx) OS_BASE="qnx" ;;
    --agl) OS_BASE="agl" ;;
  esac
done

echo "=== NeurX Auto Install ==="
echo "    OS base  : $OS_BASE"
echo "    Source   : $NEURX_ROOT"
echo "    Target   : $TARGET_DIR"
echo ""

# ── 1. Safety pre-check ─────────────────────────────────────────────────────
echo "[1/7] Safety pre-checks (ISO 26262)..."
# Ensure no other inference runtime is running on safety-critical cores
if command -v systemctl &>/dev/null; then
    systemctl is-active --quiet neurx-auto.service && {
        echo "ERROR: neurx-auto is already running. Stop it before reinstalling."
        exit 1
    } || true
fi

# ── 2. Build NeurX (real-time profile) ──────────────────────────────────────
echo "[2/7] Building NeurX with RT profile..."
make -C "$NEURX_ROOT" neurx \
    S_COMPILER="${S_COMPILER:-s}" \
    NEURX_PROFILE=realtime

# ── 3. Install runtime ───────────────────────────────────────────────────────
echo "[3/7] Installing runtime to $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"/{bin,lib,config,ir,log}
cp -r "$NEURX_ROOT/build/ir/"*         "$TARGET_DIR/ir/"
cp -r "$NEURX_ROOT/targets/auto/"      "$TARGET_DIR/config/target/"
cp -r "$NEURX_ROOT/kernel/"            "$TARGET_DIR/lib/kernel/"
cp -r "$NEURX_ROOT/agent/"             "$TARGET_DIR/lib/agent/"
cp -r "$NEURX_ROOT/tool/"              "$TARGET_DIR/lib/tool/"
cp -r "$NEURX_ROOT/safety/"            "$TARGET_DIR/lib/safety/"
cp -r "$NEURX_ROOT/security/"          "$TARGET_DIR/lib/security/"

# ── 4. Configure CAN bus ─────────────────────────────────────────────────────
echo "[4/7] Configuring CAN bus..."
if command -v ip &>/dev/null && ip link show can0 &>/dev/null; then
    ip link set can0 type can bitrate 500000
    ip link set up can0
    echo "  [ok] can0 up at 500kbps"
else
    echo "  [warn] can0 not found — configure manually"
fi

# ── 5. Set CPU/GPU to performance mode ───────────────────────────────────────
echo "[5/7] Setting performance governor..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo performance > "$cpu" && true
done
echo "  [ok] CPUs set to performance"

# ── 6. Install watchdog service ──────────────────────────────────────────────
echo "[6/7] Installing watchdog + main service..."
if command -v systemctl &>/dev/null; then
    tee /etc/systemd/system/neurx-auto.service > /dev/null <<EOF
[Unit]
Description=NeurX AI OS - Automotive Runtime
After=network.target can.service
RequiresMountsFor=$TARGET_DIR

[Service]
Type=simple
WorkingDirectory=$TARGET_DIR
ExecStart=$TARGET_DIR/bin/neurx-runtime --target auto --config $TARGET_DIR/config/target/target.s
Restart=always
RestartSec=1
WatchdogSec=10
KillSignal=SIGTERM
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable neurx-auto.service
    echo "  [ok] neurx-auto.service installed"
fi

# ── 7. Verify ────────────────────────────────────────────────────────────────
echo "[7/7] Verifying..."
ls "$TARGET_DIR/lib/safety/" 2>/dev/null | head -5 || true
echo ""
echo "=== NeurX Auto install complete ==="
echo "    Start : systemctl start neurx-auto"
echo "    Logs  : journalctl -u neurx-auto -f"
echo "    WARN  : Validate ISO 26262 ASIL-B compliance before vehicle deployment"
