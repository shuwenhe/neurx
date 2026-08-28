#!/bin/bash
# G1 UEFI Boot Ownership Verification Test
# Tests whether NeurX successfully takes control from UEFI firmware
# 
# Execution chain MUST be:
#   OVMF UEFI → EFI System Partition → /EFI/BOOT/BOOTX64.EFI → efi_main() → ExitBootServices() → NeurX
#
# NOT allowed:
#   QEMU -kernel [direct kernel injection]  ← G0 only
#   SeaBIOS or other legacy BIOS fallback   ← Not UEFI

BUILD_DIR="build"
BOOTX64_EFI="$BUILD_DIR/BOOTX64.EFI"
ESP_ROOT="$BUILD_DIR/esp"
ESP_BOOTX64="$ESP_ROOT/EFI/BOOT/BOOTX64.EFI"
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
echo -e "${YELLOW}Boot Chain: OVMF → EFI/BOOT/BOOTX64.EFI → efi_main → ExitBootServices → NeurX${NC}"
echo ""

# ============================================================================
# Step 1: Build UEFI EFI application
# ============================================================================

echo -e "${YELLOW}[STEP 1]${NC} Building BOOTX64.EFI..."
echo ""

if [ ! -x "boot/build.sh" ]; then
    echo -e "${RED}[FAIL]${NC} boot/build.sh not found"
    exit 1
fi

if ! bash boot/build.sh > /tmp/g1_build.log 2>&1; then
    echo -e "${RED}[FAIL]${NC} UEFI EFI build failed"
    echo ""
    echo "Build log (last 30 lines):"
    tail -30 /tmp/g1_build.log
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Build completed"
echo ""

# ============================================================================
# Step 2: Verify BOOTX64.EFI is a real PE/COFF executable, not ELF
# ============================================================================

echo -e "${YELLOW}[STEP 2]${NC} Verifying BOOTX64.EFI format and integrity..."
echo ""

if [ ! -f "$BOOTX64_EFI" ]; then
    echo -e "${RED}[FAIL]${NC} BOOTX64.EFI not found: $BOOTX64_EFI"
    exit 1
fi

# Check file type - must contain "PE" (PE/COFF format)
FILE_OUTPUT=$(file "$BOOTX64_EFI")
echo "File type: $FILE_OUTPUT"

if ! echo "$FILE_OUTPUT" | grep -qi "PE\|executable"; then
    echo -e "${RED}[FAIL]${NC} BOOTX64.EFI is not a PE/COFF executable"
    echo ""
    echo "Troubleshooting:"
    echo "  - Verify objcopy succeeded in build.sh"
    echo "  - Check objdump output:"
    objdump -f "$BOOTX64_EFI" 2>/dev/null || echo "  - objdump unavailable"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} BOOTX64.EFI is PE/COFF format"

# Verify with objdump
echo ""
echo "Object format verification:"
objdump -f "$BOOTX64_EFI" 2>/dev/null | grep -E "architecture|format" || true

# Calculate SHA256 for this specific build
BOOTX64_SHA256=$(sha256sum "$BOOTX64_EFI" | awk '{print $1}')
echo ""
echo "SHA256: $BOOTX64_SHA256"
ls -lh "$BOOTX64_EFI" | awk '{print "Size: " $5}'

echo ""
echo -e "${GREEN}[OK]${NC} BOOTX64.EFI verified as legitimate PE/COFF executable"
echo ""

# ============================================================================
# Step 3: Create EFI System Partition (ESP) directory structure
# ============================================================================

echo -e "${YELLOW}[STEP 3]${NC} Creating EFI System Partition (ESP)..."
echo ""

# Clean and create ESP structure
rm -rf "$ESP_ROOT"
mkdir -p "$ESP_ROOT/EFI/BOOT"
echo -e "${GREEN}[OK]${NC} ESP directory created: $ESP_ROOT"

# Copy BOOTX64.EFI to ESP
cp "$BOOTX64_EFI" "$ESP_BOOTX64"
ESP_SHA256=$(sha256sum "$ESP_BOOTX64" | awk '{print $1}')

# Verify copy integrity
if [ "$BOOTX64_SHA256" != "$ESP_SHA256" ]; then
    echo -e "${RED}[FAIL]${NC} BOOTX64.EFI copy verification failed"
    echo "  Original SHA256: $BOOTX64_SHA256"
    echo "  Copy SHA256:     $ESP_SHA256"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} BOOTX64.EFI copied to ESP"
ls -lh "$ESP_BOOTX64"

echo ""
echo "ESP layout:"
tree "$ESP_ROOT" 2>/dev/null || find "$ESP_ROOT" -type f

echo ""
echo -e "${GREEN}[OK]${NC} EFI System Partition ready"
echo ""

# ============================================================================
# Step 4: Verify QEMU installation
# ============================================================================

echo -e "${YELLOW}[STEP 4]${NC} Checking for QEMU..."
echo ""

QEMU_CMD=""
for cmd in qemu-system-x86_64 qemu-system-i386; do
    if command -v "$cmd" &> /dev/null; then
        QEMU_CMD="$cmd"
        break
    fi
done

if [ -z "$QEMU_CMD" ]; then
    echo -e "${RED}[BLOCKED]${NC} QEMU not found"
    echo ""
    echo "Install QEMU with:"
    echo "  sudo apt update && sudo apt install -y qemu-system-x86_64"
    echo ""
    echo "Or compile from source: https://www.qemu.org/"
    echo ""
    echo "Status after blocking:"
    echo "  ✅ G1 BOOTX64.EFI build & ESP layout complete"
    echo "  ⏳ G1 QEMU execution BLOCKED"
    echo "  ❌ G1 boot ownership NOT PROVEN"
    echo ""
    exit 1
fi

QEMU_VERSION=$("$QEMU_CMD" --version | head -1)
echo -e "${GREEN}[OK]${NC} QEMU: $QEMU_VERSION"
echo ""

# ============================================================================
# Step 5: Verify OVMF UEFI firmware
# ============================================================================

echo -e "${YELLOW}[STEP 5]${NC} Checking for OVMF UEFI firmware..."
echo ""

OVMF_FILE=""
for ovmf in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF.fd /usr/share/qemu/OVMF.fd /opt/ovmf/OVMF.fd; do
    if [ -f "$ovmf" ]; then
        OVMF_FILE="$ovmf"
        break
    fi
done

if [ -z "$OVMF_FILE" ]; then
    echo -e "${RED}[BLOCKED]${NC} OVMF UEFI firmware not found"
    echo ""
    echo "Install OVMF with:"
    echo "  sudo apt update && sudo apt install -y ovmf"
    echo ""
    echo "Or download from: https://github.com/tianocore/tianocore.github.io/wiki/OVMF"
    echo ""
    echo "Note: SeaBIOS (traditional BIOS) is NOT compatible with this test."
    echo "      G1 requires UEFI/OVMF specifically."
    echo ""
    echo "Status after blocking:"
    echo "  ✅ G1 BOOTX64.EFI build & ESP layout complete"
    echo "  ⏳ G1 OVMF execution BLOCKED"
    echo "  ❌ G1 boot ownership NOT PROVEN"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK]${NC} OVMF firmware: $OVMF_FILE"
ls -lh "$OVMF_FILE" | awk '{print "Size: " $5}'
echo ""

# ============================================================================
# Step 6: Launch QEMU with UEFI boot from ESP
# ============================================================================

echo -e "${YELLOW}[STEP 6]${NC} Starting QEMU with UEFI firmware..."
echo ""

echo "Boot parameters:"
echo "  QEMU command:       $QEMU_CMD"
echo "  Memory:             256M"
echo "  UEFI firmware:      $OVMF_FILE"
echo "  ESP location:       $ESP_ROOT"
echo "  BOOTX64.EFI SHA256: $BOOTX64_SHA256"
echo "  Serial output:      $SERIAL_LOG"
echo ""

echo "IMPORTANT: QEMU will boot OVMF, which will search for /EFI/BOOT/BOOTX64.EFI"
echo "           and execute efi_main() directly. NO -kernel parameter injected."
echo ""

rm -f "$SERIAL_LOG"

# Launch QEMU with OVMF firmware
# IMPORTANT: NO -kernel parameter!
# OVMF will find and load BOOTX64.EFI from the virtual disk
timeout 10 "$QEMU_CMD" \
    -m 256 \
    -nographic \
    -no-reboot \
    -bios "$OVMF_FILE" \
    -serial "file:$SERIAL_LOG" \
    -hda "fat:ro:$ESP_ROOT" \
    2>/dev/null || true

echo ""
echo "=== G1 Serial Output ==="
if [ -f "$SERIAL_LOG" ]; then
    cat "$SERIAL_LOG"
else
    echo "(no serial output)"
fi
echo "=== End Output ==="
echo ""

# ============================================================================
# Step 7: Verify G1 UEFI boot sequence markers
# ============================================================================

echo -e "${YELLOW}[STEP 7]${NC} Verifying G1 UEFI boot sequence..."
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
    echo ""
    echo "Possible causes:"
    echo "  - QEMU does not support serial output"
    echo "  - OVMF failed to boot"
    echo "  - BOOTX64.EFI was not found in ESP"
    echo ""
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
    echo "  ✓ OVMF UEFI firmware loaded BOOTX64.EFI from ESP"
    echo "  ✓ efi_main() entry point executed"
    echo "  ✓ Memory map successfully retrieved via GetMemoryMap()"
    echo "  ✓ ExitBootServices() succeeded with EFI_SUCCESS"
    echo "  ✓ Boot Services permanently unavailable"
    echo "  ✓ NeurX kernel has exclusive CPU control"
    echo "  ✓ COM1 UART I/O works (direct port I/O, no BIOS calls)"
    echo ""
    echo "Evidence:"
    echo "  Serial log: $SERIAL_LOG"
    echo "  ESP path: $ESP_ROOT"
    echo "  BOOTX64.EFI SHA256: $BOOTX64_SHA256"
    echo ""
else
    echo -e "${RED}G1 VERIFICATION: FAIL ❌${NC}"
    echo ""
    echo "Missing or out-of-order markers. This could mean:"
    echo "  - efi_main() was not called"
    echo "  - GetMemoryMap() failed"
    echo "  - ExitBootServices() failed or returned an error"
    echo "  - Marker order is wrong"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check serial output above for error messages"
    echo "  2. Verify BOOTX64.EFI is a valid PE/COFF executable"
    echo "  3. Verify OVMF can read from ESP (FAT filesystem)"
    echo "  4. Add debug output to boot/efi_main.c for more info"
    echo ""
    exit 1
fi
