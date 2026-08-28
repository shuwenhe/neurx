/*
 * Minimal UEFI header definitions for G1 boot
 * This replaces efi.h and efilib.h when those are not available
 */

#ifndef __EFI_MINIMAL_H__
#define __EFI_MINIMAL_H__

#include <stdint.h>
#include <string.h>

/* UEFI status codes */
typedef uint64_t EFI_STATUS;
typedef void* EFI_HANDLE;

#define EFI_SUCCESS               0
#define EFI_INVALID_PARAMETER     (1ULL << 63) | 0x2
#define EFI_ERROR(Status)         ((Status) != EFI_SUCCESS)

/* UEFI memory types */
typedef uint32_t EFI_MEMORY_TYPE;
#define EfiLoaderCode   1
#define EfiLoaderData   2
#define EfiBootServicesCode  3
#define EfiBootServicesData  4

/* UEFI memory descriptor */
typedef struct {
    uint32_t Type;
    uint64_t PhysicalStart;
    uint64_t VirtualStart;
    uint64_t NumberOfPages;
    uint64_t Attribute;
} EFI_MEMORY_DESCRIPTOR;

/* Minimal Boot Services table */
typedef struct {
    /* Minimal subset of Boot Services */
    uint64_t Padding[0x20];  /* Skip to the functions we need */
    
    /* GetMemoryMap is at offset 0x28 in UEFI spec */
    EFI_STATUS (*GetMemoryMap)(
        uint64_t *MemoryMapSize,
        EFI_MEMORY_DESCRIPTOR *MemoryMap,
        uint64_t *MapKey,
        uint64_t *DescriptorSize,
        uint32_t *DescriptorVersion
    );
    
    /* ExitBootServices is at offset 0x30 */
    EFI_STATUS (*ExitBootServices)(
        EFI_HANDLE ImageHandle,
        uint64_t MapKey
    );
} EFI_BOOT_SERVICES_MINIMAL;

/* UEFI System Table */
typedef struct {
    uint64_t Signature;
    uint32_t Revision;
    uint32_t HeaderSize;
    uint32_t CRC32;
    uint32_t Reserved;
    
    void* FirmwareVendor;
    uint32_t FirmwareRevision;
    
    EFI_HANDLE ConsoleInHandle;
    void* ConIn;
    
    EFI_HANDLE ConsoleOutHandle;
    void* ConOut;
    
    EFI_HANDLE StandardErrorHandle;
    void* StdErr;
    
    void* RuntimeServices;
    EFI_BOOT_SERVICES_MINIMAL* BootServices;
    
    uint64_t NumberOfTableEntries;
    void* ConfigurationTable;
} EFI_SYSTEM_TABLE_MINIMAL;

/* Simple print for UEFI ConOut */
static inline void efi_print(EFI_SYSTEM_TABLE_MINIMAL* SystemTable, const uint16_t* Str) {
    if (!SystemTable || !SystemTable->ConOut) {
        return;
    }
    
    /* ConOut is an UEFI Simple Text Output Protocol */
    /* First function at offset 0 is OutputString */
    typedef EFI_STATUS (*OutputString_t)(void* This, uint16_t* Str);
    OutputString_t OutputString = (OutputString_t)(((void**)SystemTable->ConOut)[0]);
    
    if (OutputString) {
        OutputString(SystemTable->ConOut, (uint16_t*)Str);
    }
}

#endif /* __EFI_MINIMAL_H__ */
