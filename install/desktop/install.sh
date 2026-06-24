#!/usr/bin/env bash
# install/desktop/install.sh
# Install NeurX AI OS on Linux / macOS / Windows desktop or laptop
#
# Usage:
#   ./install/desktop/install.sh [--gpu nvidia|amd|apple|none]
#
# Supports:
#   - Ubuntu 22.04+ / Debian 12+
#   - macOS 13+ (Apple Silicon or Intel)
#   - Windows: run install/desktop/install.ps1 instead

set -euo pipefail

NEURX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GPU="auto"
OS_NAME="$(uname -s)"

for arg in "$@"; do
  case $arg in
    --gpu) shift; GPU="$1" ;;
    --gpu=*) GPU="${arg#--gpu=}" ;;
  esac
done

# Auto-detect GPU
if [ "$GPU" = "auto" ]; then
    if command -v nvidia-smi &>/dev/null; then
        GPU="nvidia"
    elif [ "$OS_NAME" = "Darwin" ]; then
        GPU="apple"
    elif command -v rocm-smi &>/dev/null; then
        GPU="amd"
    else
        GPU="none"
    fi
fi

echo "=== NeurX Desktop Install ==="
echo "    OS  : $OS_NAME"
echo "    GPU : $GPU"
echo ""

# ── 1. Dependencies ─────────────────────────────────────────────────────────
echo "[1/5] Installing dependencies..."
if [ "$OS_NAME" = "Linux" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build \
        libopenblas-dev liblapack-dev

    if [ "$GPU" = "nvidia" ]; then
        sudo apt-get install -y --no-install-recommends \
            cuda-toolkit-12-6 libcudnn9-dev || \
        echo "  [warn] CUDA packages not found in apt — install manually from developer.nvidia.com"
    elif [ "$GPU" = "amd" ]; then
        echo "  [hint] ROCm: follow https://rocm.docs.amd.com/en/latest/deploy/linux/quick_start.html"
    fi
elif [ "$OS_NAME" = "Darwin" ]; then
    command -v brew &>/dev/null || {
        echo "  Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    }
    brew install cmake ninja openblas
fi

# ── 2. Build ────────────────────────────────────────────────────────────────
echo "[2/5] Building NeurX..."
make -C "$NEURX_ROOT" neurx S_COMPILER="${S_COMPILER:-s}"

# ── 3. Install to user local ─────────────────────────────────────────────────
INSTALL_DIR="$HOME/.local/neurx"
echo "[3/5] Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"/{bin,lib,config,ir}
cp -r "$NEURX_ROOT/build/ir/"*          "$INSTALL_DIR/ir/"
cp -r "$NEURX_ROOT/targets/desktop/"    "$INSTALL_DIR/config/target/"
cp -r "$NEURX_ROOT/kernel/"             "$INSTALL_DIR/lib/kernel/"
cp -r "$NEURX_ROOT/agent/"              "$INSTALL_DIR/lib/agent/"
cp -r "$NEURX_ROOT/tool/"               "$INSTALL_DIR/lib/tool/"
cp -r "$NEURX_ROOT/serving/"            "$INSTALL_DIR/lib/serving/"
cp -r "$NEURX_ROOT/memory/"             "$INSTALL_DIR/lib/memory/"

# Add to PATH
SHELL_RC="$HOME/.bashrc"
[ "$SHELL" = "/bin/zsh" ] && SHELL_RC="$HOME/.zshrc"
grep -q 'neurx' "$SHELL_RC" 2>/dev/null || \
    echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\"" >> "$SHELL_RC"

# ── 4. Write config ──────────────────────────────────────────────────────────
echo "[4/5] Writing GPU config..."
cat > "$INSTALL_DIR/config/runtime.env" <<EOF
NEURX_GPU=$GPU
NEURX_TARGET=desktop
NEURX_INSTALL=$INSTALL_DIR
EOF

# ── 5. Verify ────────────────────────────────────────────────────────────────
echo "[5/5] Done."
echo ""
echo "=== NeurX Desktop install complete ==="
echo "    Reload shell : source $SHELL_RC"
echo "    Start agent  : neurx-runtime --target desktop"
echo "    GPU          : $GPU"
