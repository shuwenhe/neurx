#!/bin/bash
# G1 Build Script
# Compiles UEFI entry point and generates EFI application

set -e

BUILD_DIR="build"
KERNEL_NAME="kernel"
KERNEL_ELF="$BUILD_DIR/$KERNEL_NAME.elf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}G1 Build System${NC}"
echo "===================="
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
echo -e "${GREEN}[OK]${NC} Required tools available"

# Compile efi_main.c
# We need to compile for x86-64 EFI (no -fPIC needed for kernel context)
echo -e "${YELLOW}[INFO]${NC} Compiling efi_main.c..."

gcc -m64 \
    -I/usr/include/efi \
    -I/usr/include/efi/x86_64 \
    -DEFI_FUNCTION_WRAPPER \
    -fno-stack-protector \
    -fno-asynchronous-unwind-tables \
    -Wall -Wextra \
    -c boot/efi_main.c -o "$BUILD_DIR/efi_main.o" 2>/dev/null || {
    
    # Fallback: Simple compilation without EFI headers
    echo -e "${YELLOW}[WARN]${NC} EFI headers not available, using basic compilation..."
    
    gcc -m64 \
        -fno-stack-protector \
        -fno-asynchronous-unwind-tables \
        -Wall -Wextra \
        -c boot/efi_main.c -o "$BUILD_DIR/efi_main.o" || {
        echo -e "${RED}[ERROR]${NC} Compilation failed"
        exit 1
    }
}
echo -e "${GREEN}[OK]${NC} efi_main.o generated"

# Link as ELF
# For QEMU UEFI boot, we can use ELF directly
echo -e "${YELLOW}[INFO]${NC} Linking ELF kernel..."

ld -nostdlib \
    --subsystem=10 \
    -e efi_main \
    "$BUILD_DIR/efi_main.o" \
    -L/usr/lib/efi \
    -lefi -lgnuefi \
    -o "$KERNEL_ELF" 2>/dev/null || {
    
    # Fallback: try linking without UEFI libs (for embedded scenario)
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

# Show binary info
echo ""
echo -e "${YELLOW}Binary Information:${NC}"
ls -lh "$KERNEL_ELF"
file "$KERNEL_ELF"

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: ./boot/test_g1.sh"
echo "  2. Check serial output for: NEURX_G1_PASS"
echo ""
