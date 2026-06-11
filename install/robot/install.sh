#!/usr/bin/env bash
# install/robot/install.sh
# Install NeurX AI OS on a robotics platform (Jetson Orin / RK3588)
#
# Usage:
#   ./install/robot/install.sh [--sim]   # --sim: simulation mode (no real hardware)
#
# Prerequisites:
#   - Ubuntu 22.04 / JetPack 6.x on Jetson, or Debian on RK3588
#   - sudo privileges
#   - Internet access for package install (or pre-staged packages)
#   - ROS 2 Humble (optional but recommended)

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="/opt/neurx"
SERVICE_USER="neurx"
SIM_MODE=false
PLATFORM="jetson_orin"   # jetson_orin | rk3588

# ── Parse args ──────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --sim)       SIM_MODE=true ;;
    --rk3588)    PLATFORM="rk3588" ;;
  esac
done

echo "=== NeurX Robot Install ==="
echo "    Platform : $PLATFORM"
echo "    Sim mode : $SIM_MODE"
echo "    Source   : $NEURX_ROOT"
echo "    Target   : $TARGET_DIR"
echo ""

# ── 1. System dependencies ──────────────────────────────────────────────────
echo "[1/6] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build \
    python3 python3-pip \
    libopenblas-dev \
    can-utils iproute2        # CAN bus tools

if [ "$PLATFORM" = "jetson_orin" ]; then
    # JetPack ships CUDA; install CUSPARSELT and cuDNN headers
    sudo apt-get install -y --no-install-recommends \
        cuda-toolkit-12-2 libcudnn9-dev || true
fi

if [ "$SIM_MODE" = "false" ]; then
    # ROS 2 Humble for real robot comms
    if ! command -v ros2 &>/dev/null; then
        echo "  [hint] ROS 2 not found — skipping (install manually if needed)"
    fi
fi

# ── 2. Build NeurX from source ──────────────────────────────────────────────
echo "[2/6] Building NeurX..."
make -C "$NEURX_ROOT" neurx S_COMPILER="${S_COMPILER:-s}"

# ── 3. Install binaries and runtime ─────────────────────────────────────────
echo "[3/6] Installing NeurX runtime to $TARGET_DIR ..."
sudo mkdir -p "$TARGET_DIR"/{bin,lib,config,ir}
sudo cp -r "$NEURX_ROOT/build/ir/"*         "$TARGET_DIR/ir/"
sudo cp -r "$NEURX_ROOT/targets/robot/"     "$TARGET_DIR/config/target/"
sudo cp -r "$NEURX_ROOT/kernel/"            "$TARGET_DIR/lib/kernel/"
sudo cp -r "$NEURX_ROOT/agent/"             "$TARGET_DIR/lib/agent/"
sudo cp -r "$NEURX_ROOT/tool/"              "$TARGET_DIR/lib/tool/"
sudo cp -r "$NEURX_ROOT/memory/"            "$TARGET_DIR/lib/memory/"

# ── 4. Create service user ───────────────────────────────────────────────────
echo "[4/6] Creating service user '$SERVICE_USER'..."
id "$SERVICE_USER" &>/dev/null || sudo useradd -r -s /sbin/nologin "$SERVICE_USER"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$TARGET_DIR"

# ── 5. Install systemd service ───────────────────────────────────────────────
echo "[5/6] Installing systemd service..."
sudo tee /etc/systemd/system/neurx-robot.service > /dev/null <<EOF
[Unit]
Description=NeurX AI OS - Robot Runtime
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$TARGET_DIR
ExecStart=$TARGET_DIR/bin/neurx-runtime --target robot --config $TARGET_DIR/config/target/target.s
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable neurx-robot.service
echo "  [ok] Service installed. Start with: sudo systemctl start neurx-robot"

# ── 6. Verify ────────────────────────────────────────────────────────────────
echo "[6/6] Verifying install..."
ls "$TARGET_DIR/lib/kernel/" | head -5
echo ""
echo "=== NeurX Robot install complete ==="
echo "    Start:  sudo systemctl start neurx-robot"
echo "    Logs:   journalctl -u neurx-robot -f"
echo "    Config: $TARGET_DIR/config/target/target.s"
