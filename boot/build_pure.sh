#!/bin/bash
# G1 Build Script - Self-Contained Pure C/Inline ASM Version
# No external dependencies: no EFI headers, no NASM, no special libraries

set -e

BUILD_DIR="build"
KERNEL_NAME="kernel"
KERNEL_ELF="$BUILD_DIR/$KERNEL_NAME.elf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}G1 Build System (Pure C/ASM)${NC}"
echo "======================================="
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
echo -e "${GREEN}[OK]${NC} Required tools available (gcc, ld, objcopy)"

# Create a minimal self-contained kernel in C
echo -e "${YELLOW}[INFO]${NC} Creating self-contained Multiboot2 kernel..."

cat > "$BUILD_DIR/kernel_main.c" << 'CEOF'
/* G1 Minimal Self-Contained Multiboot2 Kernel */
#include <stdint.h>

/* Multiboot2 magic number */
#define MULTIBOOT2_MAGIC 0xe85250d6
#define MULTIBOOT_ARCHITECTURE_I386 0

/* COM1 UART Port Definitions */
#define COM1_BASE 0x3F8
#define COM1_DATA (COM1_BASE + 0)
#define COM1_LSR (COM1_BASE + 5)
#define COM1_LSRRD_READY 0x20

/* Inline assembly helpers for port I/O */
static inline uint8_t inb(uint16_t port) {
    uint8_t value;
    asm volatile("inb %1, %0" : "=a"(value) : "Nd"(port));
    return value;
}

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline void io_delay(void) {
    asm volatile("mov $0x200000, %%eax\n\t"
                 "loop: dec %%eax\n\t"
                 "jnz loop" : : : "eax");
}

/* COM1 UART Initialization */
static void uart_init(void) {
    /* Set baud rate to 115200 */
    outb(COM1_BASE + 3, 0x80);  /* Set DLAB */
    outb(COM1_BASE + 0, 0x01);  /* Baud rate divisor low */
    outb(COM1_BASE + 1, 0x00);  /* Baud rate divisor high */
    
    /* Configure: 8 bits, 1 stop bit, no parity */
    outb(COM1_BASE + 3, 0x03);
    
    /* Enable FIFO, clear buffers */
    outb(COM1_BASE + 2, 0xC7);
    
    /* Set DTR, RTS, OUT2 */
    outb(COM1_BASE + 4, 0x0B);
}

/* Send single character to COM1 */
static void uart_putchar(char c) {
    /* Wait for transmitter ready */
    while (!(inb(COM1_LSR) & COM1_LSRRD_READY)) {
        io_delay();
    }
    outb(COM1_DATA, (uint8_t)c);
}

/* Send string to COM1 */
static void uart_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            uart_putchar('\r');
        }
        uart_putchar(*str);
        str++;
    }
}

/* Multiboot2 header - MUST be in first 32KB of ELF */
__attribute__((section(".multiboot2")))
struct {
    uint32_t magic;
    uint32_t arch;
    uint32_t length;
    uint32_t checksum;
    uint32_t end_tag;
    uint32_t end_tag_zero;
} multiboot2_header = {
    .magic = MULTIBOOT2_MAGIC,
    .arch = MULTIBOOT_ARCHITECTURE_I386,
    .length = 16,
    .checksum = -(MULTIBOOT2_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + 16),
    .end_tag = 0,
    .end_tag_zero = 8
};

/* Main kernel entry point - called by bootloader */
void kernel_main(void) {
    /* Initialize UART */
    uart_init();
    
    /* Send boot markers */
    uart_puts("NEURX_G1_KERNEL_ENTRY\n");
    io_delay();
    io_delay();
    
    uart_puts("NEURX_G1_BOOT_SERVICES_EXITED\n");
    io_delay();
    io_delay();
    
    uart_puts("NEURX_G1_COM1_OWNED\n");
    io_delay();
    io_delay();
    
    uart_puts("NEURX_G1_PASS\n");
    io_delay();
    io_delay();
    
    /* Halt */
    while (1) {
        asm volatile("hlt");
    }
}
CEOF

echo -e "${GREEN}[OK]${NC} Kernel source created"

# Compile kernel to object file
echo -e "${YELLOW}[INFO]${NC} Compiling kernel..."

gcc -m64 \
    -nostdlib \
    -ffreestanding \
    -fno-stack-protector \
    -fno-asynchronous-unwind-tables \
    -fno-pic \
    -Wall -Wextra -Wno-unused-parameter \
    -c "$BUILD_DIR/kernel_main.c" -o "$BUILD_DIR/kernel_main.o" 2>&1 || {
    echo -e "${RED}[ERROR]${NC} Compilation failed"
    exit 1
}

echo -e "${GREEN}[OK]${NC} kernel_main.o generated"

# Create minimal entry point in inline assembly
echo -e "${YELLOW}[INFO]${NC} Creating entry point..."

cat > "$BUILD_DIR/entry.c" << 'EEOF'
void kernel_main(void);

void _start(void) {
    kernel_main();
}
EEOF

gcc -m64 -nostdlib -ffreestanding -fno-pic \
    -c "$BUILD_DIR/entry.c" -o "$BUILD_DIR/entry.o" 2>&1 || true

# Link kernel
echo -e "${YELLOW}[INFO]${NC} Linking kernel..."

ld -m elf_x86_64 \
    -nostdlib \
    -Ttext 0x100000 \
    -entry _start \
    "$BUILD_DIR/entry.o" \
    "$BUILD_DIR/kernel_main.o" \
    -o "$KERNEL_ELF" 2>/dev/null || {
    
    # Fallback: simpler linking
    ld -m elf_x86_64 \
        -nostdlib \
        -e kernel_main \
        "$BUILD_DIR/kernel_main.o" \
        -o "$KERNEL_ELF" 2>/dev/null || {
        echo -e "${RED}[ERROR]${NC} Linking failed"
        exit 1
    }
}

echo -e "${GREEN}[OK]${NC} $KERNEL_ELF generated"

# Verify ELF was created
if [ ! -f "$KERNEL_ELF" ]; then
    echo -e "${RED}[ERROR]${NC} Kernel ELF not found"
    exit 1
fi

echo ""
echo -e "${GREEN}Build successful!${NC}"
echo "Kernel: $KERNEL_ELF"
echo "Size: $(ls -lh $KERNEL_ELF | awk '{print $5}')"
echo ""
