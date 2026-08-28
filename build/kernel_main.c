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

/* Main kernel entry point - called by Multiboot2 bootloader */
void kernel_main(void) {
    /* Initialize UART */
    uart_init();
    
    /* Send G0 boot markers (Bare-metal Multiboot2 execution) */
    uart_puts("NEURX_G0_KERNEL_ENTRY\n");
    io_delay();
    io_delay();
    
    uart_puts("NEURX_G0_COM1_OWNED\n");
    io_delay();
    io_delay();
    
    uart_puts("NEURX_G0_PASS\n");
    io_delay();
    io_delay();
    
    /* Halt */
    while (1) {
        asm volatile("hlt");
    }
}
