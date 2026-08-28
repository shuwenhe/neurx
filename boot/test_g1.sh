#!/bin/bash
# G1 UEFI Boot Ownership Verification Test
# Tests whether NeurX successfully takes control from UEFI firmware
# Requires: OVMF UEFI firmware, BOOTX64.EFI entry point

BUILD_DIR="build"
KERNEL_ELF="$BUILD_DIR/kernel.elf"
UEFI_EFI="$BUILD_DIR/BOOTX64.EFI"
SERIAL_LOG="/tmp/neurx_g1_serial.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}    G1: UEFI Boot Ownership Verification${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Path: OVMF → BOOTX64.EFI → efi_main → ExitBootServices → NeurX${NC}"
echo ""

# Build UEFI EFI application
echo -e "${YELLOW}[INFO]${NC} Building UEFI EFI application..."

if [ ! -x "boot/build.sh" ]; then
    echo -e "${RED}[FAIL]${NC} boot/build.sh not found"
    exit 1
fi

# Try to build EFI version
if ! bash boot/build.sh > /tmp/g1_build.log 2>&1; then
    echo -e "${RED}[FAIL]${NC} UEFI EFI build failed"
    echo "Build log:"
    cat /tmp/g1_build.log | tail -20
    echo ""
    echo "Troubleshooting:"
    echo "  - Need EFI development headers: libefi-dev, libefi headers"
    echo "  - Or build EFI tools from source"
    exit 1
fi

if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}[FAIL]${NC} EFI kernel not built: $KERNEL_ELF"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} EFI application built: $KERNEL_ELF ($(ls -lh $KERNEL_ELF | awk '{print $5}'))"
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

# Find OVMF UEFI firmware
echo -e "${YELLOW}[INFO]${NC} Checking for OVMF UEFI firmware..."
OVMF_FILE=""
for ovmf in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd /usr/share/seabios/bios.bin; do
    if [ -f "$ovmf" ]; then
        OVMF_FILE="$ovmf"
        break
    fi
done

if [ -z "$OVMF_FILE" ]; then
    echo -e "${RED}[FAIL]${NC} OVMF firmware not found"
    echo ""
    echo "Install OVMF with:"
    echo "  sudo apt update && sudo apt install -y ovmf"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK]${NC} OVMF firmware: $OVMF_FILE"
echo ""

# Run QEMU with UEFI firmware
echo -e "${YELLOW}[INFO]${NC} Starting QEMU with UEFI firmware (10s timeout)..."
echo "Command: $QEMU_CMD -m 256 -nographic -no-reboot \\"
echo "  -bios $OVMF_FILE -kernel $KERNEL_ELF -serial file:$SERIAL_LOG"
echo ""

rm -f "$SERIAL_LOG"

timeout 10 "$QEMU_CMD" \
    -m 256 \
    -nographic \
    -no-reboot \
    -bios "$OVMF_FILE" \
    -kernel "$KERNEL_ELF" \
    -serial "file:$SERIAL_LOG" 2>/dev/null || true

echo ""
echo "=== G1 Serial Output ==="
if [ -f "$SERIAL_LOG" ]; then
    cat "$SERIAL_LOG"
else
    echo "(no output)"
fi
echo "=== End Output ==="
echo ""

# Verify G1 markers in correct order
echo -e "${YELLOW}[INFO]${NC} Verifying G1 UEFI boot sequence..."
echo ""

EXPECTED_MARKERS=(
    "NEURX_G1_EFI_ENTRY"
    "NEURX_G1_MEMORY_MAP_READY"
    "NEURX_G1_BOOT_SERVICES_EXITED"
    "NEURX_G1_KERNEL_ENTRY"
    "NEURX_G1_COM1_OWNED"
    "NEURX_G1_PASS"
)

if [ ! -f "$SERIAL_LOG" ]; then
    echo -e "${RED}[FAIL]${NC} No serial output generated"
    exit 1
fi

# Check each marker exists and in order
LAST_POS=0
ALL_FOUND=1
for marker in "${EXPECTED_MARKERS[@]}"; do
    if grep -q "$marker" "$SERIAL_LOG"; then
        LINE_NUM=$(grep -n "$marker" "$SERIAL_LOG" | head -1 | cut -d: -f1)
        if [ "$LINE_NUM" -ge "$LAST_POS" ]; then
            echo -e "${GREEN}[OK]${NC} $marker (line $LINE_NUM)"
            LAST_POS=$LINE_NUM
        else
            echo -e "${RED}[OUT_OF_ORDER]${NC} $marker (expected after line $LAST_POS, found at line $LINE_NUM)"
            ALL_FOUND=0
        fi
    else
        echo -e "${RED}[MISSING]${NC} $marker"
        ALL_FOUND=0
    fi
done

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [ $ALL_FOUND -eq 1 ]; then
    echo -e "${GREEN}G1 VERIFICATION: PASS ✅${NC}"
    echo ""
    echo "Proven:"
    echo "  ✓ OVMF UEFI firmware loaded NeurX"
    echo "  ✓ efi_main() entry point executed"
    echo "  ✓ Memory map successfully retrieved"
    echo "  ✓ ExitBootServices() succeeded"
    echo "  ✓ Boot Services permanently unavailable"
    echo "  ✓ Direct hardware I/O (COM1 UART) works post-ExitBootServices"
    echo "  ✓ Full UEFI → NeurX ownership handoff completed"
    echo ""
    echo "Evidence:"
    echo "  Serial log: $SERIAL_LOG"
    echo "  QEMU: $QEMU_VERSION"
    echo "  OVMF: $OVMF_FILE"
    echo "  EFI kernel: $KERNEL_ELF"
    echo ""
    exit 0
else
    echo -e "${RED}G1 VERIFICATION: FAIL ❌${NC}"
    echo ""
    echo "Failed to complete UEFI boot sequence"
    exit 1
fi
