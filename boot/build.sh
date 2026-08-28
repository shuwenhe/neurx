#!/bin/bash
# G1 Build Script
# Compiles UEFI entry point and generates PE/COFF BOOTX64.EFI executable
# This must produce a true EFI application, not an ELF or fake executable

set -e

BUILD_DIR="build"
KERNEL_NAME="kernel"
KERNEL_ELF="$BUILD_DIR/$KERNEL_NAME.elf"
BOOTX64_EFI="$BUILD_DIR/BOOTX64.EFI"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}G1 UEFI EFI Application Builder${NC}"
echo "================================================"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}[OK]${NC} Build directory: $BUILD_DIR"

# Check for required tools
for tool in gcc ld objcopy; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} $tool not found"
        exit 1
    fi
done
echo -e "${GREEN}[OK]${NC} Required tools: gcc, ld, objcopy"

# Compile efi_main.c to object file
echo -e "${YELLOW}[INFO]${NC} Compiling boot/efi_main.c..."

gcc -m64 \
    -I/usr/include/efi \
    -I/usr/include/efi/x86_64 \
    -DEFI_FUNCTION_WRAPPER \
    -fno-stack-protector \
    -fno-asynchronous-unwind-tables \
    -Wall -Wextra \
    -c boot/efi_main.c -o "$BUILD_DIR/efi_main.o" 2>/dev/null || {
    
    # Fallback: Compile with minimal EFI headers (efi_minimal.h)
    echo -e "${YELLOW}[WARN]${NC} EFI headers not available, using minimal UEFI definitions..."
    
    gcc -m64 \
        -I. \
        -I./boot \
        -include boot/efi_minimal.h \
        -fno-stack-protector \
        -fno-asynchronous-unwind-tables \
        -Wall -Wextra \
        -c boot/efi_main.c -o "$BUILD_DIR/efi_main.o" || {
        echo -e "${RED}[ERROR]${NC} Compilation failed"
        exit 1
    }
}
echo -e "${GREEN}[OK]${NC} efi_main.o generated"

# Link as ELF intermediate
echo -e "${YELLOW}[INFO]${NC} Linking as ELF intermediate..."

ld -nostdlib \
    --subsystem=10 \
    -e efi_main \
    "$BUILD_DIR/efi_main.o" \
    -L/usr/lib/efi \
    -lefi -lgnuefi \
    -o "$KERNEL_ELF" 2>/dev/null || {
    
    # Fallback: try linking without UEFI libs
    echo -e "${YELLOW}[WARN]${NC} UEFI libraries not available, attempting minimal link..."
    
    ld -nostdlib \
        -e efi_main \
        "$BUILD_DIR/efi_main.o" \
        -o "$KERNEL_ELF" 2>/dev/null || {
        echo -e "${RED}[ERROR]${NC} Linking failed"
        exit 1
    }
}
echo -e "${GREEN}[OK]${NC} $KERNEL_ELF generated"

# Convert ELF to PE/COFF EFI executable format
echo -e "${YELLOW}[INFO]${NC} Converting ELF to PE/COFF BOOTX64.EFI..."

objcopy \
    -O efi-app-x86_64 \
    "$KERNEL_ELF" \
    "$BOOTX64_EFI" || {
    echo -e "${RED}[ERROR]${NC} objcopy conversion failed"
    exit 1
}

echo -e "${GREEN}[OK]${NC} $BOOTX64_EFI generated"

# Verify that BOOTX64.EFI is indeed a PE/COFF executable
echo ""
echo -e "${YELLOW}[VERIFY]${NC} Verifying BOOTX64.EFI format and integrity..."
echo ""

# Check file type
echo "File type:"
file "$BOOTX64_EFI"

# Check with objdump - should show PE/COFF format
echo ""
echo "Object dump (first 50 lines):"
objdump -f "$BOOTX64_EFI" | head -20

# Calculate SHA256 for reproducibility
echo ""
echo "SHA256 checksum:"
BOOTX64_SHA256=$(sha256sum "$BOOTX64_EFI" | awk '{print $1}')
echo "$BOOTX64_SHA256  $BOOTX64_EFI"

# Store SHA256 in a marker file for test_g1.sh verification
echo "$BOOTX64_SHA256" > "$BUILD_DIR/BOOTX64.EFI.sha256"

echo ""
echo -e "${YELLOW}[SIZE]${NC} Binary sizes:"
echo "  ELF:     $(ls -lh "$KERNEL_ELF" | awk '{print $5}')"
echo "  BOOTX64: $(ls -lh "$BOOTX64_EFI" | awk '{print $5}')"

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify BOOTX64.EFI is PE/COFF format (not ELF)"
echo "  2. Run: bash boot/test_g1.sh"
echo "  3. Check serial output for UEFI markers:"
echo "     NEURX_G1_EFI_ENTRY → NEURX_G1_PASS"
echo ""
