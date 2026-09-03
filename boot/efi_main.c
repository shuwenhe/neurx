
#ifdef __has_include
  #if __has_include(<efi.h>)
    #include <efi.h>
    #include <efilib.h>
  #else
    #include "efi_minimal.h"
  #endif
#else
  
  #include "efi_minimal.h"
#endif

#include <stdint.h>
#include <string.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

EFI_BOOT_SERVICES *BS = NULL;
EFI_SYSTEM_TABLE *ST = NULL;

#define COM1_BASE       0x3F8

#define COM1_DATA       (COM1_BASE + 0)   
#define COM1_IER        (COM1_BASE + 1)   
#define COM1_IIR        (COM1_BASE + 2)   
#define COM1_FCR        (COM1_BASE + 3)   
#define COM1_LCR        (COM1_BASE + 4)   
#define COM1_MCR        (COM1_BASE + 5)   
#define COM1_LSR        (COM1_BASE + 6)   
#define COM1_MSR        (COM1_BASE + 7)   
#define COM1_DLAB       (COM1_BASE + 0)   
#define COM1_DLM        (COM1_BASE + 1)   

static inline u8 io_read_u8(uint16_t port) {
    u8 val;
    asm volatile("inb %1, %0" : "=a" (val) : "d" (port));
    return val;
}

static inline void io_write_u8(uint16_t port, u8 val) {
    asm volatile("outb %0, %1" : : "a" (val), "d" (port));
}

static void io_delay(void) {
    volatile int i;
    for (i = 0; i < 1000; i++) {}
}

static void com1_init(void) {
    
    io_write_u8(COM1_IER, 0x00);
    
    io_write_u8(COM1_LCR, 0x80);
    
    io_write_u8(COM1_DLAB, 0x01);   
    io_write_u8(COM1_DLM, 0x00);    
    
    io_write_u8(COM1_LCR, 0x03);
    
    io_write_u8(COM1_FCR, 0xC7);
    
    io_write_u8(COM1_MCR, 0x0B);
}

static void com1_putchar(char c) {
    
    while (!(io_read_u8(COM1_LSR) & 0x20)) {
        io_delay();
    }
    
    io_write_u8(COM1_DATA, (u8)c);
}

static void com1_puts(const char *str) {
    while (*str) {
        if (*str == '\n') {
            com1_putchar('\r');
        }
        com1_putchar(*str);
        str++;
    }
}

static void efi_print(const CHAR16 *str) {
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *conout = ST->ConOut;
    if (conout) {
        conout->OutputString(conout, (CHAR16 *)str);
    }
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_STATUS Status;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    UINTN MemMapSize = 0, MemMapKey = 0, DescSize = 0;
    UINT32 DescVersion = 0;
    
    InitializeLib(ImageHandle, SystemTable);
    
    BS->SetWatchdogTimer(0, 0, 0, NULL);
    
    efi_print(L"NeurX G1: Starting UEFI entry\r\n");
    
    MemMapSize = 0;
    Status = BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
    if (Status != EFI_BUFFER_TOO_SMALL) {
        efi_print(L"Memory map get size failed\r\n");
        return Status;
    }
    
    MemMapSize += 2 * DescSize;
    Status = BS->AllocatePool(EfiBootServicesData, MemMapSize, (void**)&MemoryMap);
    if (EFI_ERROR(Status)) {
        efi_print(L"Memory map allocation failed\r\n");
        return Status;
    }
    
    Status = BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
    if (EFI_ERROR(Status)) {
        efi_print(L"Memory map retrieval failed\r\n");
        return Status;
    }
    
    com1_init();
    com1_puts("NEURX_G1_EFI_ENTRY\n");
    io_delay();
    
    com1_puts("NEURX_G1_MEMORY_MAP_READY\n");
    io_delay();
    
    efi_print(L"NeurX G1: Memory map retrieved, exiting boot services...\r\n");
    
    Status = BS->ExitBootServices(ImageHandle, MemMapKey);
    
    if (Status == EFI_INVALID_PARAMETER) {
        
        efi_print(L"ExitBootServices failed with stale map_key, retrying with fresh map...\r\n");
        
        BS->GetMemoryMap(&MemMapSize, MemoryMap, &MemMapKey, &DescSize, &DescVersion);
        Status = BS->ExitBootServices(ImageHandle, MemMapKey);
    }
    
    if (EFI_ERROR(Status)) {
        
        while (1) {
            asm volatile("hlt");
        }
    }
    
    com1_puts("NEURX_G1_BOOT_SERVICES_EXITED\n");
    io_delay();
    io_delay();
    
    com1_puts("NEURX_G1_KERNEL_ENTRY\n");
    io_delay();
    
    com1_puts("NEURX_G1_COM1_OWNED\n");
    io_delay();
    
    com1_puts("NEURX_G1_PASS\n");
    io_delay();
    io_delay();
    
    com1_puts("NEURX_G1_HALTING\n");
    
    while (1) {
        asm volatile("hlt");
    }
    
    return EFI_SUCCESS;
}
