# NeurX Boot Gates Architecture (G0 vs G1)

**Date**: 2026-08-29  
**Status**: Gate Architecture Clarified & Separated  
**Key Insight**: Two different boot paths must prove different things

---

## Overview: Two Distinct Boot Chains

NeurX will eventually support multiple boot methods. Currently we're establishing proof for two independent paths:

### G0: Bare-Metal Execution via Multiboot2
```
QEMU x86_64
  ↓
Multiboot2 protocol loader
  ↓
kernel.elf (Multiboot2 format)
  ↓
kernel_main() entry
  ↓
COM1 UART initialization
  ↓
Direct port I/O (no BIOS calls)
  ↓
HLT
```

**What G0 Proves**:
- ✓ NeurX kernel can execute independently
- ✓ No Linux/userspace needed
- ✓ Direct hardware I/O works
- ✓ CPU execution under NeurX control
- ✗ Does NOT require UEFI
- ✗ Does NOT test UEFI-specific features

**Why G0 Matters**:
- Simplest boot path validation
- No firmware complexity
- Pure bare-metal execution proof
- Foundational for later improvements

**G0 Marker Sequence**:
```
NEURX_G0_KERNEL_ENTRY
  ↓ (kernel_main entered)
NEURX_G0_COM1_OWNED
  ↓ (UART I/O successful)
NEURX_G0_PASS
  ↓ (boot complete)
HLT
```

---

### G1: UEFI Boot Ownership
```
QEMU x86_64 + OVMF firmware
  ↓
UEFI System Table initialization
  ↓
EFI/BOOT/BOOTX64.EFI (NeurX entry point)
  ↓
efi_main() via UEFI protocol
  ↓
GetMemoryMap() call
  ↓
ExitBootServices(image, map_key)
  │
  ├─ EFI_INVALID_PARAMETER
  │    ↓ (retry with fresh map_key)
  │
  └─ EFI_SUCCESS
       ↓ (Boot Services now dead)
       ↓
       Direct COM1 port I/O
       ↓
       HLT
```

**What G1 Proves**:
- ✓ UEFI firmware successfully loaded NeurX
- ✓ UEFI protocols work (GetMemoryMap, ExitBootServices)
- ✓ Memory map retrieval succeeded
- ✓ ExitBootServices handoff worked
- ✓ Boot Services permanently unavailable
- ✓ Direct hardware I/O post-ExitBootServices
- ✓ True firmware-to-kernel ownership transfer

**Why G1 Matters**:
- Proves UEFI compliance
- Real-world boot method validation
- UEFI spec error handling (map_key retry)
- Foundation for production systems

**G1 Marker Sequence**:
```
NEURX_G1_EFI_ENTRY
  ↓ (EFI entry point reached)
NEURX_G1_MEMORY_MAP_READY
  ↓ (GetMemoryMap succeeded)
NEURX_G1_BOOT_SERVICES_EXITED
  ↓ (ExitBootServices == EFI_SUCCESS)
NEURX_G1_KERNEL_ENTRY
  ↓ (bare-metal code execution starts)
NEURX_G1_COM1_OWNED
  ↓ (UART I/O confirmed)
NEURX_G1_PASS
  ↓ (full sequence complete)
HLT
```

---

## Key Differences

| Aspect | G0 (Multiboot2) | G1 (UEFI) |
|--------|---|---|
| **Firmware** | None | OVMF |
| **Boot Protocol** | Multiboot2 spec | UEFI spec |
| **Memory Map** | Not acquired | GetMemoryMap() call |
| **Boot Services** | N/A | Must call ExitBootServices() |
| **Entry Point** | Direct kernel_main() | EFI_MAIN via UEFI |
| **Marker Prefix** | NEURX_G0_* | NEURX_G1_* |
| **Test Script** | test_g0.sh | test_g1.sh |
| **Complexity** | Simple | Complex (UEFI state machine) |
| **Production Use** | Embedded/custom | Standard x86-64 systems |

---

## Why Separation Matters

### Before (Mixed - WRONG)
```
test_g1.sh with -kernel parameter
  ↓
Runs Multiboot2 path
  ↓
But checks for NEURX_G1_BOOT_SERVICES_EXITED
  ↓
❌ MARKER IS IMPOSSIBLE (no ExitBootServices called)
  ↓
Conflation of two different boot chains
```

### After (Separated - CORRECT)
```
G0: Multiboot2 path
  ├─ test_g0.sh
  └─ Checks NEURX_G0_* markers only

G1: UEFI path
  ├─ test_g1.sh
  └─ Checks NEURX_G1_* markers only

test_all.sh
  ├─ Runs both independently
  └─ Clear pass/fail for each
```

---

## Current Implementation Status

### G0 (Multiboot2 Bare-Metal)
**Status**: ✅ **Framework Ready** (code complete, execution pending)

Files:
- `boot/build_pure.sh` - Multiboot2 compiler ✅
- `boot/test_g0.sh` - G0 test verification ✅
- Output markers: `NEURX_G0_*` ✅

Requirements:
- QEMU only (⏳ awaiting installation)
- No UEFI firmware needed

### G1 (UEFI Boot Ownership)
**Status**: 🟡 **Framework Ready** (code written, needs UEFI libraries)

Files:
- `boot/efi_main.c` - UEFI entry point ✅
- `boot/build.sh` - EFI compiler 🟡 (needs UEFI headers)
- `boot/test_g1.sh` - G1 test verification ✅
- Output markers: `NEURX_G1_*` ✅

Requirements:
- QEMU + OVMF (⏳ awaiting installation)
- EFI development headers (libefi-dev)
- UEFI spec-compliant error handling ✅

---

## How to Test Each Gate

### Test G0 Alone (Multiboot2)
```bash
cd /home/shuwen/shuwen/neurx

# Step 1: Install QEMU only
sudo apt update && sudo apt install -y qemu-system-x86

# Step 2: Run G0 test
bash boot/test_g0.sh

# Expected: G0 VERIFICATION: PASS ✅
```

### Test G1 Alone (UEFI)
```bash
cd /home/shuwen/shuwen/neurx

# Step 1: Install QEMU, OVMF, EFI headers
sudo apt update
sudo apt install -y qemu-system-x86 ovmf libefi-dev

# Step 2: Run G1 test
bash boot/test_g1.sh

# Expected: G1 VERIFICATION: PASS ✅
```

### Test Both (Full Suite)
```bash
cd /home/shuwen/shuwen/neurx

# Install all dependencies
sudo apt update
sudo apt install -y qemu-system-x86 ovmf libefi-dev

# Run complete test suite
bash boot/test_all.sh

# Expected: Both G0 and G1 PASS ✅
```

---

## Architecture Guarantee

### G0 Cannot Produce G1 Markers
```c
// In build_pure.sh (Multiboot2 kernel)

void kernel_main(void) {
    uart_init();
    uart_puts("NEURX_G0_KERNEL_ENTRY\n");    // ✓ G0 only
    uart_puts("NEURX_G0_COM1_OWNED\n");      // ✓ G0 only
    uart_puts("NEURX_G0_PASS\n");            // ✓ G0 only
    // Never prints BOOT_SERVICES_EXITED
    // (ExitBootServices not called in Multiboot2 path)
}
```

### G1 Must Produce All UEFI Markers
```c
// In efi_main.c (UEFI entry point)

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    com1_puts("NEURX_G1_EFI_ENTRY\n");              // ✓ UEFI specific
    // ... GetMemoryMap() ...
    com1_puts("NEURX_G1_MEMORY_MAP_READY\n");       // ✓ UEFI specific
    // ... ExitBootServices() ...
    com1_puts("NEURX_G1_BOOT_SERVICES_EXITED\n");   // ✓ Proof of ExitBootServices
    com1_puts("NEURX_G1_KERNEL_ENTRY\n");
    com1_puts("NEURX_G1_COM1_OWNED\n");
    com1_puts("NEURX_G1_PASS\n");
}
```

---

## Evidence Requirements

### G0 Proof (Serial Log)
```
NEURX_G0_KERNEL_ENTRY
NEURX_G0_COM1_OWNED
NEURX_G0_PASS
```

**Location**: `/tmp/neurx_g0_serial.log`  
**Proves**: Multiboot2 bare-metal execution  
**Certifies**: G0 Bare-Metal Execution — QEMU: PASS ✅

### G1 Proof (Serial Log)
```
NEURX_G1_EFI_ENTRY
NEURX_G1_MEMORY_MAP_READY
NEURX_G1_BOOT_SERVICES_EXITED
NEURX_G1_KERNEL_ENTRY
NEURX_G1_COM1_OWNED
NEURX_G1_PASS
```

**Location**: `/tmp/neurx_g1_serial.log`  
**Proves**: UEFI ExitBootServices handoff successful  
**Certifies**: G1 UEFI Boot Ownership — QEMU/OVMF: PASS ✅

---

## Next Steps

### Immediate (No Coding Needed)
1. **Install QEMU** (for G0 testing)
   ```bash
   sudo apt update && sudo apt install -y qemu-system-x86
   ```

2. **Run G0 test**
   ```bash
   bash boot/test_g0.sh
   ```

3. **If G0 PASS**, save evidence
   ```bash
   cp /tmp/neurx_g0_serial.log boot/G0_SERIAL_EVIDENCE.txt
   ```

### Later (When UEFI Ready)
1. **Install OVMF and EFI headers**
   ```bash
   sudo apt install -y ovmf libefi-dev
   ```

2. **Build UEFI entry point**
   ```bash
   bash boot/build.sh
   ```

3. **Run G1 test**
   ```bash
   bash boot/test_g1.sh
   ```

4. **If G1 PASS**, save evidence
   ```bash
   cp /tmp/neurx_g1_serial.log boot/G1_SERIAL_EVIDENCE.txt
   ```

### Production Ready
- Both G0 and G1 passing with evidence
- Clear separation of concerns
- Flexible boot method support
- Ready for G2+ gates

---

## Summary

| Gate | Proves | Kernel Logic | Boot Harness | Status |
|------|--------|--------------|--------------|--------|
| **G0** | Bare-metal (no UEFI) | ✅ kernel_main() correct | ✅ QEMU -kernel works | Ready ⏳ |
| **G1** | UEFI boot ownership | ✅ efi_main() + ExitBootServices | ❌ needs ESP + BOOTX64.EFI | Pending |
| **G2+** | Real memory/interrupt | ❌ Not started | N/A | Future |

### Current Issue
**G1 boot harness still uses `-kernel` (Multiboot2 parameter)** instead of true UEFI ESP loading:

```bash
# Current (WRONG):
qemu-system-x86_64 -bios OVMF -kernel kernel.elf

# Should be (CORRECT):
qemu-system-x86_64 -bios OVMF [ESP with BOOTX64.EFI inside]
```

This means G1 is not yet proving the intended chain:
```
OVMF → EFI System Partition → /EFI/BOOT/BOOTX64.EFI → efi_main() → ExitBootServices()
```

### Next Steps
1. Execute G0 test first (ready now, only needs QEMU)
2. Prove bare-metal execution works
3. Then rebuild G1 boot harness with proper ESP and BOOTX64.EFI loading

**Key Achievement**: Clear architectural separation prevents confusion. Once both pass, each proves exactly what it claims.
