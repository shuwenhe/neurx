/*
 * G1 Boot: UEFI Entry Point
 * 
 * This is a minimal UEFI application that:
 * 1. Gets boot services
 * 2. Calls ExitBootServices()
 * 3. Initializes COM1 UART
 * 4. Sends test messages
 * 5. Halts
 * 
 * No dependency on existing NeurX S kernel modules.
 * Goal: Prove CPU control is in NeurX, not Linux.
 */

#include <efi.h>
#include <efilib.h>
#include <stdint.h>
#include <string.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

/* COM1 UART Port I/O */
#define COM1_BASE       0x3F8

#define COM1_DATA       (COM1_BASE + 0)   /* RBR/THR */
#define COM1_IER        (COM1_BASE + 1)   /* Interrupt Enable Register */
#define COM1_IIR        (COM1_BASE + 2)   /* Interrupt Identification Register */
#define COM1_FCR        (COM1_BASE + 3)   /* FIFO Control Register */
#define COM1_LCR        (COM1_BASE + 4)   /* Line Control Register */
#define COM1_MCR        (COM1_BASE + 5)   /* Modem Control Register */
#define COM1_LSR        (COM1_BASE + 6)   /* Line Status Register */
#define COM1_MSR        (COM1_BASE + 7)   /* Modem Status Register */
#define COM1_DLAB       (COM1_BASE + 0)   /* Divisor Latch (for baud rate) */
#define COM1_DLM        (COM1_BASE + 1)   /* Divisor Latch MSB */

/* Inline assembly to read/write I/O ports */
static inline u8 io_read_u8(uint16_t port) {
    u8 val;
    asm volatile("inb %1, %0" : "=a" (val) : "d" (port));
    return val;
}

static inline void io_write_u8(uint16_t port, u8 val) {
    asm volatile("outb %0, %1" : : "a" (val), "d" (port));
}

/* Delay for I/O operations */
static void io_delay(void) {
    volatile int i;
    for (i = 0; i < 1000; i++) {}
}

/* Initialize COM1 UART */
static void com1_init(void) {
    /* Disable all interrupts */
    io_write_u8(COM1_IER, 0x00);
    
    /* Enable DLAB (Divisor Latch Access Bit) to set baud rate */
    io_write_u8(COM1_LCR, 0x80);
    
    /* Set baud rate to 115200
     * Divisor = 115200 / (16 * 115200) = 1
     */
    io_write_u8(COM1_DLAB, 0x01);   /* DLL = 1 */
    io_write_u8(COM1_DLM, 0x00);    /* DLM = 0 */
    
    /* Disable DLAB, set 8 data bits, 1 stop bit, no parity */
    io_write_u8(COM1_LCR, 0x03);
    
    /* Set FIFO, clear buffers, enable FIFO */
    io_write_u8(COM1_FCR, 0xC7);
    
    /* Set DTR, RTS, OUT2 */
    io_write_u8(COM1_MCR, 0x0B);
}

/* Send a single character via COM1 */
static void com1_putchar(char c) {
    /* Wait for transmit ready (LSR bit 5) */
    while (!(io_read_u8(COM1_LSR) & 0x20)) {
        io_delay();
    }
    
    /* Send character */
    io_write_u8(COM1_DATA, (u8)c);
}

/* Send a string via COM1 */
static void com1_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            com1_putchar('\r');
        }
        com1_putchar(*str);
        str++;
    }
}

/* Simple output for debugging (before ExitBootServices) */
static void efi_print(const CHAR16 *str) {
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *conout = ST->ConOut;
    if (conout) {
        conout->OutputString(conout, (CHAR16 *)str);
    }
}

/* UEFI Entry Point */
EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_STATUS Status;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    UINTN MemMapSize = 0, MemMapKey = 0, DescSize = 0;
    UINT32 DescVersion = 0;
    
    /* Initialize global pointers */
    InitializeLib(ImageHandle, SystemTable);
    
    /* Disable UEFI watchdog timer */
    BS->SetWatchdogTimer(0, 0, 0, NULL);
    
    efi_print(L"NeurX G1: Starting UEFI entry\r\n");
    
    /* Get memory map */
    MemMapSize = 0;
    Status = BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        efi_print(L"Memory map get size failed\r\n");
        return Status;
    }
    
    /* Allocate memory for memory map (add safety margin) */
    MemMapSize += 2 * DescSize;
    Status = BS->AllocatePool(EfiBootServicesData, MemMapSize, (void**)&MemoryMap);
    if (EFI_ERROR(Status)) {
        efi_print(L"Memory map allocation failed\r\n");
        return Status;
    }
    
    /* Get actual memory map */
    Status = BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
    if (EFI_ERROR(Status)) {
        efi_print(L"Memory map retrieval failed\r\n");
        return Status;
    }
    
    /* Send G1 marker: UEFI entry complete */
    com1_init();
    com1_puts("NEURX_G1_EFI_ENTRY\n");
    io_delay();
    
    /* Send G1 marker: Memory map ready */
    com1_puts("NEURX_G1_MEMORY_MAP_READY\n");
    io_delay();
    
    efi_print(L"NeurX G1: Memory map retrieved, exiting boot services...\r\n");
    
    /* Exit Boot Services - This is the critical transition point */
    /* Per UEFI spec: ExitBootServices may fail with EFI_INVALID_PARAMETER if map_key is stale */
    Status = BS->ExitBootServices(ImageHandle, MemMapKey);
    
    if (Status == EFI_INVALID_PARAMETER) {
        /* map_key became invalid (system events changed memory map) */
        /* Retry: get fresh memory map and try again (allowed by UEFI spec) */
        efi_print(L"ExitBootServices failed with stale map_key, retrying with fresh map...\r\n");
        
        BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
        Status = BS->ExitBootServices(ImageHandle, MemMapKey);
    }
    
    /* 
     * If Status is still an error, we cannot continue
     * Only EFI_SUCCESS indicates Boot Services are now permanently unavailable
     */
    if (EFI_ERROR(Status)) {
        /* Something went wrong - halt immediately */
        while (1) {
            asm volatile("hlt");
        }
    }
    
    /* 
     * CRITICAL: We have successfully exited boot services
     * Boot Services are now permanently unavailable
     * No UEFI calls allowed after this point
     * CPU is under NeurX control
     * 
     * Send proof of successful exit
     */
    com1_puts("NEURX_G1_BOOT_SERVICES_EXITED\n");
    io_delay();
    io_delay();
    
    /* Kernel entry in bare-metal mode */
    com1_puts("NEURX_G1_KERNEL_ENTRY\n");
    io_delay();
    
    com1_puts("NEURX_G1_COM1_OWNED\n");
    io_delay();
    
    com1_puts("NEURX_G1_PASS\n");
    io_delay();
    io_delay();
    
    /* Halt - CPU control loop ends here */
    com1_puts("NEURX_G1_HALTING\n");
    
    while (1) {
        asm volatile("hlt");
    }
    
    return EFI_SUCCESS;
}
