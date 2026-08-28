#!/bin/bash
# G1 Boot Ownership Verification Test
# Tests whether NeurX successfully takes control from bootloader

BUILD_DIR="build"
KERNEL_ELF="$BUILD_DIR/kernel.elf"
SERIAL_LOG="/tmp/neurx_g1_serial.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "G1 Boot Ownership Verification"
echo "============================================"
echo ""

# Build kernel if needed
if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${YELLOW}[INFO]${NC} Building kernel..."
    if [ -x "boot/build_pure.sh" ]; then
        bash boot/build_pure.sh > /dev/null 2>&1 || bash boot/build.sh > /dev/null 2>&1 || true
    else
        bash boot/build.sh > /dev/null 2>&1 || true
    fi
fi

if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}[FAIL]${NC} Kernel ELF not found: $KERNEL_ELF"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Kernel ELF found: $KERNEL_ELF ($(ls -lh $KERNEL_ELF | awk '{print $5}'))"
echo ""

# Find QEMU
echo -e "${YELLOW}[INFO]${NC} Checking for QEMU..."
QEMU_CMD=""
for cmd in qemu-system-x86_64 qemu-system-i386; do
    if command -v "$cmd" &> /dev/null; then
        QEMU_CMD="$cmd"
        break
    fi
done

if [ -z "$QEMU_CMD" ]; then
    echo -e "${RED}[FAIL]${NC} QEMU not found"
    echo ""
    echo "Install QEMU with:"
    echo "  sudo apt update && sudo apt install -y qemu-system-x86"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK]${NC} QEMU: $QEMU_CMD"
echo ""

# Run QEMU
echo -e "${YELLOW}[INFO]${NC} Starting QEMU (10 second timeout)..."
rm -f "$SERIAL_LOG"

timeout 10 "$QEMU_CMD" \
    -m 256 \
    -nographic \
    -no-reboot \
    -kernel "$KERNEL_ELF" \
    -serial "file:$SERIAL_LOG" 2>/dev/null || true

echo ""
echo "=== Serial Output ==="
if [ -f "$SERIAL_LOG" ]; then
    cat "$SERIAL_LOG"
else
    echo "(no output)"
fi
echo "=== End Output ==="
echo ""

# Check markers
MARKERS=("NEURX_G1_KERNEL_ENTRY" "NEURX_G1_BOOT_SERVICES_EXITED" "NEURX_G1_COM1_OWNED" "NEURX_G1_PASS")
ALL_FOUND=1

for marker in "${MARKERS[@]}"; do
    if [ -f "$SERIAL_LOG" ] && grep -q "$marker" "$SERIAL_LOG"; then
        echo -e "${GREEN}[OK]${NC} $marker"
    else
        echo -e "${RED}[MISSING]${NC} $marker"
        ALL_FOUND=0
    fi
done

echo ""
echo "============================================"
if [ $ALL_FOUND -eq 1 ]; then
    echo -e "${GREEN}G1 VERIFICATION: PASS ✅${NC}"
    echo ""
    echo "Evidence saved:"
    echo "  Serial log: $SERIAL_LOG"
    echo ""
    exit 0
else
    echo -e "${RED}G1 VERIFICATION: FAIL ❌${NC}"
    exit 1
fi
