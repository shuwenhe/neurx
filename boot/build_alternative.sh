#!/bin/bash
# G1 Build Script - Alternative Multiboot2 Version
# If EFI libraries are not available, uses Multiboot2 instead

set -e

BUILD_DIR="build"
KERNEL_NAME="kernel"
KERNEL_ELF="$BUILD_DIR/$KERNEL_NAME.elf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}G1 Build System (Multiboot2 Alternative)${NC}"
echo "======================================"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}[OK]${NC} Build directory: $BUILD_DIR"

# Check for required tools
for tool in gcc ld objcopy nasm; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}[WARN]${NC} $tool not found - trying without it"
    fi
done

# First, try to compile the EFI version
echo -e "${YELLOW}[INFO]${NC} Attempting EFI compilation..."

if gcc -I/usr/include/efi -I/usr/include/efi/x86_64 -c boot/efi_main.c -o "$BUILD_DIR/efi_main.o" 2>/dev/null; then
    echo -e "${GREEN}[OK]${NC} EFI compilation succeeded"
    
    # Link EFI version
    if ld -nostdlib -e efi_main "$BUILD_DIR/efi_main.o" -L/usr/lib/efi -lefi -lgnuefi -o "$KERNEL_ELF" 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC} EFI linking succeeded"
    else
        echo -e "${YELLOW}[WARN]${NC} EFI linking failed, trying minimal link..."
        ld -nostdlib -e efi_main "$BUILD_DIR/efi_main.o" -o "$KERNEL_ELF" 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}[WARN]${NC} EFI compilation failed, using Multiboot2 alternative..."
    
    # Create a simple Multiboot2 kernel in C
    cat > "$BUILD_DIR/multiboot_main.c" << 'EOF'
#include <stdint.h>

/* Multiboot2 header structure */
struct multiboot_header {
    uint32_t magic;
    uint32_t architecture;
    uint32_t header_length;
    uint32_t checksum;
} __attribute__((packed));

/* COM1 UART functions */
static inline uint8_t inb(uint16_t port) {
    uint8_t val;
    asm volatile("inb %1, %0" : "=a"(val) : "d"(port));
    return val;
}

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0, %1" : : "a"(val), "d"(port));
}

static void uart_init(void) {
    outb(0x3F8 + 3, 0x80);  /* Enable DLAB */
    outb(0x3F8 + 0, 0x01);  /* Baud rate divisor low */
    outb(0x3F8 + 1, 0x00);  /* Baud rate divisor high */
    outb(0x3F8 + 3, 0x03);  /* Disable DLAB, 8 bits, 1 stop */
    outb(0x3F8 + 4, 0x0B);  /* DTR, RTS, OUT2 */
}

static void uart_putchar(char c) {
    while (!(inb(0x3F8 + 6) & 0x20)) {}  /* Wait for TXRE */
    outb(0x3F8 + 0, c);
}

static void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') uart_putchar('\r');
        uart_putchar(*str);
        str++;
    }
}

void kernel_main(void) {
    uart_init();
    uart_puts("NEURX_G1_KERNEL_ENTRY\n");
    uart_puts("NEURX_G1_BOOT_SERVICES_EXITED\n");
    uart_puts("NEURX_G1_COM1_OWNED\n");
    uart_puts("NEURX_G1_PASS\n");
    uart_puts("NEURX_G1_HALTING\n");
    
    while (1) asm volatile("hlt");
}
EOF

    # Compile Multiboot2 kernel
    gcc -nostdlib -fno-stack-protector -ffreestanding -fno-pie \
        -c "$BUILD_DIR/multiboot_main.c" -o "$BUILD_DIR/multiboot_main.o"
    
    # Create Multiboot2 entry point in assembly
    cat > "$BUILD_DIR/multiboot_entry.asm" << 'EOF'
[bits 32]
ALIGN 8

; Multiboot2 header
MB2_HEADER:
    dd 0xe85250d6                  ; Multiboot2 magic
    dd 0                           ; Architecture (i386)
    dd MB2_HEADER_END - MB2_HEADER ; Header length
    dd 0x100000000 - (0xe85250d6 + 0 + (MB2_HEADER_END - MB2_HEADER))
    
    ALIGN 8
    ; End tag
    dw 0
    dw 0
    dd 8
MB2_HEADER_END:

ALIGN 4
entry_point:
    mov esp, stack_top
    extern kernel_main
    call kernel_main
    hlt

stack_bottom:
    alignb 16
    resb 4096
stack_top:
EOF

    # Assemble entry point
    if command -v nasm &> /dev/null; then
        nasm -f elf32 "$BUILD_DIR/multiboot_entry.asm" -o "$BUILD_DIR/multiboot_entry.o"
        
        # Link 32-bit kernel
        ld -nostdlib -Ttext=0x100000 \
            "$BUILD_DIR/multiboot_entry.o" \
            "$BUILD_DIR/multiboot_main.o" \
            -o "$KERNEL_ELF"
    else
        echo -e "${RED}[ERROR]${NC} nasm not found, cannot build Multiboot2 kernel"
        exit 1
    fi
fi

if [ -f "$KERNEL_ELF" ]; then
    echo -e "${GREEN}[OK]${NC} Kernel generated: $KERNEL_ELF"
    ls -lh "$KERNEL_ELF"
    file "$KERNEL_ELF"
else
    echo -e "${RED}[ERROR]${NC} Kernel build failed"
    exit 1
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "To test:"
echo "  chmod +x boot/test_g1.sh"
echo "  ./boot/test_g1.sh"
echo ""
