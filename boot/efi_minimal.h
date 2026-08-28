/*
 * Minimal UEFI header definitions for G1 boot
 * This replaces efi.h and efilib.h when those are not available
 */

#ifndef __EFI_MINIMAL_H__
#define __EFI_MINIMAL_H__

#include <stdint.h>
#include <string.h>

/* Basic UEFI Types */
typedef uint8_t UINT8;
typedef uint16_t UINT16;
typedef uint32_t UINT32;
typedef uint64_t UINT64;
typedef int8_t INT8;
typedef int16_t INT16;
typedef int32_t INT32;
typedef int64_t INT64;
typedef uint64_t UINTN;
typedef int64_t INTN;
typedef uint16_t CHAR16;
typedef char CHAR8;
typedef void VOID;
typedef UINT8 BOOLEAN;

#define TRUE  1
#define FALSE 0

/* Calling convention */
#define EFIAPI

/* Handle */
typedef VOID* EFI_HANDLE;

/* UEFI Status Codes */
typedef UINT64 EFI_STATUS;

#define EFI_SUCCESS               0
#define EFI_LOAD_ERROR            1
#define EFI_INVALID_PARAMETER     2
#define EFI_UNSUPPORTED           3
#define EFI_BAD_BUFFER_SIZE       4
#define EFI_BUFFER_TOO_SMALL      5
#define EFI_ERROR(Status)         (((INT64)(Status)) < 0)

/* Memory Types */
typedef UINT32 EFI_MEMORY_TYPE;
#define EfiReservedMemoryType 0
#define EfiLoaderCode         1
#define EfiLoaderData         2
#define EfiBootServicesCode   3
#define EfiBootServicesData   4
#define EfiRuntimeServicesCode 5
#define EfiRuntimeServicesData 6
#define EfiConventionalMemory 7

/* Memory Descriptor */
typedef struct {
    UINT32 Type;
    UINT32 Pad;
    UINT64 PhysicalStart;
    UINT64 VirtualStart;
    UINT64 NumberOfPages;
    UINT64 Attribute;
} EFI_MEMORY_DESCRIPTOR;

/* Simple Text Output Protocol */
typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    VOID *Reset;
    EFI_STATUS (EFIAPI *OutputString)(
        VOID *This,
        CHAR16 *String
    );
    VOID *TestString;
    VOID *QueryMode;
    VOID *SetMode;
    VOID *SetAttribute;
    VOID *ClearScreen;
    VOID *SetCursorPosition;
    VOID *EnableCursor;
    VOID *Mode;
} EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

/* Boot Services Table */
typedef struct {
    /* Skip first 52 bytes */
    UINT8 _Padding[52];
    
    /* Offset 52: AllocatePool */
    EFI_STATUS (EFIAPI *AllocatePool)(
        EFI_MEMORY_TYPE PoolType,
        UINTN Size,
        VOID **Buffer
    );
    
    /* Offset 60: FreePool */
    EFI_STATUS (EFIAPI *FreePool)(
        VOID *Buffer
    );
    
    /* Offset 68: GetMemoryMap */
    EFI_STATUS (EFIAPI *GetMemoryMap)(
        UINTN *MemoryMapSize,
        EFI_MEMORY_DESCRIPTOR *MemoryMap,
        UINTN *MapKey,
        UINTN *DescriptorSize,
        UINT32 *DescriptorVersion
    );
    
    /* More functions follow, but we use padding for the rest */
    UINT8 _Padding2[200];
    
    /* Offset around 228: SetWatchdogTimer */
    EFI_STATUS (EFIAPI *SetWatchdogTimer)(
        UINTN Timeout,
        UINT64 WatchdogCode,
        UINTN DataSize,
        VOID *WatchdogData
    );
    
    /* More padding */
    UINT8 _Padding3[200];
    
    /* Near the end: ExitBootServices */
    EFI_STATUS (EFIAPI *ExitBootServices)(
        EFI_HANDLE ImageHandle,
        UINTN MapKey
    );
} EFI_BOOT_SERVICES;

/* System Table */
typedef struct {
    UINT64 Signature;
    UINT32 Revision;
    UINT32 HeaderSize;
    UINT32 CRC32;
    UINT32 Reserved;
    
    VOID *FirmwareVendor;
    UINT32 FirmwareRevision;
    
    EFI_HANDLE ConsoleInHandle;
    VOID *ConIn;
    
    EFI_HANDLE ConsoleOutHandle;
    EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
    
    EFI_HANDLE StandardErrorHandle;
    VOID *StdErr;
    
    VOID *RuntimeServices;
    EFI_BOOT_SERVICES *BootServices;
    
    UINTN NumberOfTableEntries;
    VOID *ConfigurationTable;
} EFI_SYSTEM_TABLE;

/* Global Boot Services and System Table pointers */
extern EFI_BOOT_SERVICES *BS;
extern EFI_SYSTEM_TABLE *ST;

/* Library initialization function */
static inline void InitializeLib(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    extern EFI_BOOT_SERVICES *BS;
    extern EFI_SYSTEM_TABLE *ST;
    ST = SystemTable;
    BS = SystemTable->BootServices;
}

#endif /* __EFI_MINIMAL_H__ */
