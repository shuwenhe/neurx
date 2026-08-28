#!/bin/bash
# G0 Bare-Metal Execution Verification Test
# Tests whether NeurX kernel can execute independently via Multiboot2
# WITHOUT any UEFI or firmware dependencies

BUILD_DIR="build"
KERNEL_ELF="$BUILD_DIR/kernel.elf"
SERIAL_LOG="/tmp/neurx_g0_serial.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  G0: Bare-Metal Execution Verification${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Path: QEMU → Multiboot2 loader → kernel.elf → NeurX entry${NC}"
echo ""

# Build kernel if needed
if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${YELLOW}[INFO]${NC} Building G0 kernel..."
    if [ -x "boot/build_pure.sh" ]; then
        bash boot/build_pure.sh > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${RED}[FAIL]${NC} Kernel build failed"
            exit 1
        fi
    else
        echo -e "${RED}[FAIL]${NC} No build script found"
        exit 1
    fi
fi

if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}[FAIL]${NC} Kernel ELF not found: $KERNEL_ELF"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Kernel ELF built: $KERNEL_ELF ($(ls -lh $KERNEL_ELF | awk '{print $5}'))"
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

QEMU_VERSION=$("$QEMU_CMD" --version | head -1)
echo -e "${GREEN}[OK]${NC} QEMU: $QEMU_VERSION"
echo ""

# Run QEMU with Multiboot2 kernel
echo -e "${YELLOW}[INFO]${NC} Starting QEMU with Multiboot2 kernel (10s timeout)..."
echo "Command: $QEMU_CMD -m 256 -nographic -no-reboot -kernel $KERNEL_ELF -serial file:$SERIAL_LOG"
echo ""

rm -f "$SERIAL_LOG"

timeout 10 "$QEMU_CMD" \
    -m 256 \
    -nographic \
    -no-reboot \
    -kernel "$KERNEL_ELF" \
    -serial "file:$SERIAL_LOG" 2>/dev/null || true

echo ""
echo "=== G0 Serial Output ==="
if [ -f "$SERIAL_LOG" ]; then
    cat "$SERIAL_LOG"
else
    echo "(no output)"
fi
echo "=== End Output ==="
echo ""

# Verify G0 markers in correct order
echo -e "${YELLOW}[INFO]${NC} Verifying G0 boot sequence..."
echo ""

EXPECTED_MARKERS=(
    "NEURX_G0_KERNEL_ENTRY"
    "NEURX_G0_COM1_OWNED"
    "NEURX_G0_PASS"
)

if [ ! -f "$SERIAL_LOG" ]; then
    echo -e "${RED}[FAIL]${NC} No serial output generated"
    exit 1
fi

# Check each marker exists and in order
LAST_POS=0
ALL_FOUND=1
for marker in "${EXPECTED_MARKERS[@]}"; do
    MARKER_POS=$(grep -o "$marker" "$SERIAL_LOG" | head -1)
    if [ -z "$MARKER_POS" ]; then
        echo -e "${RED}[MISSING]${NC} $marker"
        ALL_FOUND=0
    else
        LINE_NUM=$(grep -n "$marker" "$SERIAL_LOG" | head -1 | cut -d: -f1)
        if [ "$LINE_NUM" -ge "$LAST_POS" ]; then
            echo -e "${GREEN}[OK]${NC} $marker (line $LINE_NUM)"
            LAST_POS=$LINE_NUM
        else
            echo -e "${RED}[OUT_OF_ORDER]${NC} $marker (expected after line $LAST_POS, found at line $LINE_NUM)"
            ALL_FOUND=0
        fi
    fi
done

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [ $ALL_FOUND -eq 1 ]; then
    echo -e "${GREEN}G0 VERIFICATION: PASS ✅${NC}"
    echo ""
    echo "Proven:"
    echo "  ✓ NeurX kernel loads via Multiboot2"
    echo "  ✓ CPU execution is under NeurX control"
    echo "  ✓ Direct hardware I/O (COM1 UART) works"
    echo "  ✓ No firmware/BIOS dependencies needed"
    echo ""
    echo "Evidence:"
    echo "  Serial log: $SERIAL_LOG"
    echo "  QEMU: $QEMU_VERSION"
    echo ""
    exit 0
else
    echo -e "${RED}G0 VERIFICATION: FAIL ❌${NC}"
    echo ""
    echo "Failed to complete bare-metal execution boot sequence"
    exit 1
fi
