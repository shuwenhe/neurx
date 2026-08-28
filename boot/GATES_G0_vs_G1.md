# NeurX Boot Gates Architecture (G0 vs G1)

**Date**: 2026-08-28 (G1 BOOTX64.EFI + ESP boot harness complete)  
**Status**: Build-time: Framework Ready | Runtime: Execution Blocked  
**Key Principle**: Build success ≠ Runtime success. ABI correctness only proven at execution.

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

## Execution Plan: From Build-Time to Runtime Evidence

### Phase 1: Prerequisites (No QEMU)
✅ **Currently Complete**:
- G0: kernel.elf compiles to 14KB Multiboot2 format
- G1: BOOTX64.EFI compiles to 5.4K PE/COFF format
- G1: ESP directory structure ready
- G1: No -kernel parameter injection
- G1: No SeaBIOS fallback

⏳ **Awaiting Environment**:
- QEMU x86-64 emulator installation
- OVMF UEFI firmware installation (for G1 only)

### Phase 2: G0 Execution (Once QEMU Available)

```bash
# Install QEMU only (no UEFI needed for G0)
sudo apt update && sudo apt install -y qemu-system-x86_64

# Execute bare-metal boot
bash boot/test_g0.sh
```

**Possible Outcomes**:

| Result | Meaning | Next Step |
|--------|---------|-----------|
| ✅ PASS with markers | G0 proof complete | Proceed to Phase 3 |
| ❌ Timeout, no output | QEMU/environment issue | Debug QEMU setup |
| ❌ Markers out of order | kernel.elf code bug | Fix boot/build_pure.sh |
| ❌ Some markers missing | kernel.elf code bug | Fix boot/build_pure.sh |

**If PASS**: Save evidence
```bash
cp /tmp/neurx_g0_serial.log boot/G0_SERIAL_EVIDENCE.txt
git add boot/G0_SERIAL_EVIDENCE.txt
git commit -m "G0 Runtime Evidence: PASS"
```

### Phase 3: G1 Execution (After G0 PASS, with OVMF)

```bash
# Install OVMF (UEFI firmware)
sudo apt install -y ovmf

# Execute UEFI boot ownership transfer
bash boot/test_g1.sh
```

**Expected Execution Flow**:

```
boot/test_g1.sh
  └─ Step 1: Build BOOTX64.EFI
      └─ Should complete (already verified)
  
  └─ Step 2: Verify PE/COFF format
      └─ Should pass (already verified)
  
  └─ Step 3: Create ESP directory
      └─ Should pass (file system operation)
  
  └─ Step 4: Check QEMU
      └─ PASS or exits immediately
  
  └─ Step 5: Check OVMF
      └─ PASS or exits with helpful message
  
  └─ Step 6: Launch QEMU with OVMF
      └─ Timeout after 10 seconds
  
  └─ Step 7: Parse serial output
      └─ Check for NEURX_G1_* markers in order
```

**Critical Checkpoint**: First serial output

The most important line is the very first marker:

```
NEURX_G1_EFI_ENTRY
```

If this appears, it proves:
- ✅ PE/COFF format accepted by OVMF
- ✅ Entry point call succeeded
- ✅ ABI structure layout at least partially correct

If no output at all:
- ❌ OVMF didn't execute BOOTX64.EFI
- ❌ Entry point offset wrong
- ❌ File corruption

**Marker Progression Indicates ABI Validation**:

| Markers Seen | ABI Validation | Confidence |
|---|---|---|
| None | Entry point wrong or OVMF failed | Very low |
| EFI_ENTRY | Minimal ABI correct (entry) | Low |
| EFI_ENTRY, MEMORY_MAP_READY | GetMemoryMap struct valid | Medium |
| EFI_ENTRY, MEMORY_MAP_READY, BOOT_SERVICES_EXITED | ExitBootServices call valid | High |
| All 6 markers in order | Full G1 proof complete | Complete |

### Phase 4: Debug If Needed

**If G1 produces no output**:

The issue is likely in efi_minimal.h structure definitions. Verify:

1. EFI_SYSTEM_TABLE field offsets match UEFI spec
2. EFI_BOOT_SERVICES function pointer offsets match spec
3. Entry point signature matches EFIAPI calling convention
4. BOOTX64.EFI PE header is correct (use `objdump -x`)

**If G1 produces partial output**:

Each missing marker points to a specific struct or function issue.

### Phase 5: G2 Readiness

Proceed to G2 only when:
- ✅ G0 PASS (bare-metal execution proven)
- ✅ G1 PASS (UEFI ownership transfer proven)
- ✅ Both have archived serial logs as evidence

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

## Summary: Evidence Status

### G0 (Multiboot2 Bare-Metal)

**Build Evidence** ✅:
- kernel_main() source complete
- Multiboot2 ELF compiles to 14KB
- UART initialization code present
- Serial markers defined in code

**Runtime Evidence** ⏳:
- Bare-metal execution: NOT TESTED
- QEMU loading: NOT TESTED
- Actual serial output: NOT TESTED
- Markers appearing in order: NOT PROVEN

**Blocker**: QEMU not installed

### G1 (UEFI Boot Ownership)

**Build Evidence** ✅:
- efi_main.c source complete
- Compiles with fallback efi_minimal.h
- BOOTX64.EFI generates as PE32+ executable (x86-64)
- File command: "PE32+ executable (EFI application)"
- Objdump: "file format pei-x86-64"
- SHA256: 6feb219046744e158423cd2e5c3f09476f8bfbacdcc9e5c306825ac237947e85
- ESP directory structure created
- No -kernel parameter in boot chain
- No SeaBIOS fallback
- ExitBootServices state machine implemented in source

**Build Format Verification** ✅:
- ✓ Binary format is PE/COFF (not ELF)
- ✓ Subsystem marked as EFI Application
- ✓ Architecture is x86-64
- ✓ Binary size 5.4K reasonable for minimal EFI app

**Critical Unverified** ❌:
- **ABI correctness**: efi_minimal.h structure layouts may not match actual UEFI
- **Field offsets**: Struct padding/alignment unvalidated
- **Function pointers**: EFIAPI calling convention untested
- **Entry point**: Whether efi_main() signature matches UEFI spec

**Runtime Evidence** ⏳:
- OVMF discovering BOOTX64.EFI: NOT TESTED
- efi_main() executing: NOT TESTED
- GetMemoryMap() returning data: NOT TESTED
- ExitBootServices() returning EFI_SUCCESS: NOT TESTED
- Post-ExitBootServices COM1 I/O: NOT TESTED
- Serial markers in sequence: NOT PROVEN
- Boot services actually unavailable post-EBS: NOT PROVEN

**Blockers**: 
- QEMU not installed
- OVMF firmware not installed
- UEFI ABI correctness unvalidated

### G2+ (Real Memory Ownership)

Not started. Depends on both G0 and G1 runtime PASS.

---

## Risk Assessment: efi_minimal.h

The main risk point is the custom `efi_minimal.h` implementation:

```
What OVMF provides:
  EFI_SYSTEM_TABLE*
       ↓
  BootServices*
       ↓
  Fixed ABI / Fixed struct layout per UEFI spec
```

What we defined:
  - Custom EFI_SYSTEM_TABLE struct
  - Custom EFI_BOOT_SERVICES struct
  - Custom field offsets and padding

**Any error in**:
  - Field order
  - Field sizes
  - Padding/alignment
  - Function pointer signatures
  - EFIAPI calling convention

**Results in**:
  - Compilation success (binary looks fine)
  - Runtime ABI mismatch (wrong field accesses, wrong function calls)
  - Possible crash or undefined behavior

**Verification timeline**:
  1. Build succeeds → Binary format valid (current) ✅
  2. OVMF loads + entry callable → EFI image format/load correct (future)
  3. NEURX_G1_EFI_ENTRY → Entry point reachable, partial ABI working (future)
  4. NEURX_G1_MEMORY_MAP_READY → SystemTable/BootServices offsets correct (future)
  5. **NEURX_G1_BOOT_SERVICES_EXITED** → **ExitBootServices() == SUCCESS** (future) ⚠️ CRITICAL
  6. NEURX_G1_KERNEL_ENTRY → Post-EBS kernel path works (future)
  7. NEURX_G1_COM1_OWNED → Direct port I/O post-EBS (future)
  8. NEURX_G1_PASS → Full ownership transfer proven (future) ✅

**Most critical step**: Step 5. If ExitBootServices returns EFI_SUCCESS, ownership transfer 
is real. This is the boundary between UEFI control and NeurX control.

Currently at step 1. Steps 2-8 require OVMF execution.

---

## Execution Readiness Matrix

| Component | Status | Evidence | Risk |
|-----------|--------|----------|------|
| G0 build | ✅ | 14KB kernel.elf | Low |
| G0 format | ✅ | Multiboot2 compliance | Low |
| G0 run | ⏳ | Blocked on QEMU | Medium |
| G1 build | ✅ | BOOTX64.EFI compiles | Low |
| G1 format | ✅ | PE/COFF file command | Medium |
| G1 ABI | ❌ | efi_minimal.h unvalidated | **HIGH** |
| G1 run | ⏳ | Blocked on QEMU+OVMF | High |

**Key blocker**: QEMU/OVMF unavailable
**Key risk**: efi_minimal.h may have ABI errors invisible at compile-time
**Key dependency**: First OVMF serial output will reveal ABI correctness

## Execution Prerequisites

**For G0**:
- QEMU x86-64 emulator only

**For G1**:
- QEMU x86-64 emulator
- OVMF UEFI firmware (ovmf package)

**Install both**:
```bash
sudo apt update
sudo apt install -y qemu-system-x86_64 ovmf
```

## Next Steps (When QEMU Available)

**IMPORTANT**: Do NOT add G2 code yet. Next engineering goal is execution and validation, not implementation.

### Step 1: Execute G0 (simpler boot path)

```bash
bash boot/test_g0.sh
```

Expected: "G0 VERIFICATION: PASS ✅" with markers in order

### Step 2: Execute G1 (UEFI boot ownership)

```bash
bash boot/test_g1.sh
```

Expected: All 6 G1 markers in order, with NEURX_G1_BOOT_SERVICES_EXITED proving ownership transfer

### Step 3: Save evidence

```bash
cp /tmp/neurx_g0_serial.log boot/G0_SERIAL_EVIDENCE.txt
cp /tmp/neurx_g1_serial.log boot/G1_SERIAL_EVIDENCE.txt
git add boot/*_EVIDENCE.txt
git commit -m "G0/G1 runtime evidence - execution validation"
git push origin main
```

### Step 4: Analyze Results

- If all markers appear: Ownership transfer proven, proceed to G2
- If markers missing: Adjust efi_minimal.h based on which marker fails
- If no output: Debug entry point and UEFI ABI layout

### DO NOT Proceed to G2 Until

- ✅ G0 produces all markers (KERNEL_ENTRY → PASS)
- ✅ G1 produces all markers (EFI_ENTRY → PASS)
- ✅ Both serial logs archived in repository
- ✅ No further boot chain issues

**Key principle**: Runtime evidence, not more code, is what's needed next.

---

## What Truly Defines G1 PASS

**Not**:
- BOOTX64.EFI exists
- PE/COFF format recognized by `file` command
- First marker appears
- Some markers visible

**Truly**:
```
ExitBootServices() returned EFI_SUCCESS
              ↓
Boot Services are genuinely unavailable
              ↓
Post-EBS direct port I/O works (COM1)
              ↓
All 6 markers appear in strict order:
  1. NEURX_G1_EFI_ENTRY
  2. NEURX_G1_MEMORY_MAP_READY
  3. NEURX_G1_BOOT_SERVICES_EXITED ← CRITICAL: ownership boundary
  4. NEURX_G1_KERNEL_ENTRY
  5. NEURX_G1_COM1_OWNED
  6. NEURX_G1_PASS
              ↓
     G1 Boot Ownership PROVEN ✅
```

Each marker validates a progressive layer of the UEFI ABI:
- Marker 1-2: Entry point and SystemTable/BootServices structs  
- Marker 3: **ExitBootServices() returned EFI_SUCCESS** (critical ownership boundary)
  - Only printed if: `Status == EFI_SUCCESS` (enforced in efi_main.c)
  - If `EFI_ERROR(Status)`: infinite halt instead (no marker printed)
  - This marker **cannot appear without genuine ExitBootServices success**
  - Proof: efi_main.c verifies status before printing BOOT_SERVICES_EXITED
- Marker 4-6: Post-EBS kernel execution and hardware control

Missing marker 3 (BOOT_SERVICES_EXITED) = no ownership transfer = G1 FAIL
**Critical**: Marker #3 has evidential value ONLY because it's strictly gated by EFI_SUCCESS verification

---

---

## FREEZE BASELINE: 2026-08-28

**Architecture Status**: G0/G1 framework complete and separated  
**Build Status**: Both gates compile successfully  
**Runtime Status**: Blocked on QEMU/OVMF environment  
**ABI Status**: CRITICAL - efi_minimal.h unvalidated, awaits first OVMF serial output  

**Commits in this baseline** (5 total, frozen at c89e135f):
- f80cf9c2: Architecture refactor - Separate G0/G1 gates
- 4d5719d3: G1 UEFI boot harness - BOOTX64.EFI PE/COFF + ESP
- 0120736c: Update architecture doc - G1 framework ready status
- af8f59ca: Documentation - Build vs runtime evidence separation
- c89e135f: Refine G1 PASS criteria, clarify ownership boundary

**Decision for next phase**: 
- NO G2 code until G0 and G1 pass execution
- Next goal is runtime validation, not implementation
- Each missing marker in G1 points to specific ABI issue
- efi_minimal.h will be validated/debugged at execution time

**Operational principle for G1 testing**:
- First marker (EFI_ENTRY) = partial ABI validated
- Marker #3 (BOOT_SERVICES_EXITED) = ownership boundary crossed
- All 6 markers = full ownership transfer proven

Do not claim G1 success without all 6 markers in sequence.

---

## Final Gate Definitions (Baseline Frozen at c89e135f)

**G0 PASS Criterion** (Multiboot2 Bare-Metal Ownership):
```
QEMU loads kernel.elf via Multiboot2
         ↓
kernel_main() executes
         ↓
NEURX_G0_KERNEL_ENTRY (proof: entry point reached)
         ↓
NEURX_G0_COM1_OWNED (proof: UART I/O works)
         ↓
NEURX_G0_PASS (proof: sequence complete)
         ↓
Serial log archived
         ↓
G0 PASS = ✅ Bare-metal execution proven
```

**G1 PASS Criterion** (UEFI Boot Ownership Transfer):
```
OVMF loads BOOTX64.EFI from ESP
         ↓
efi_main() executes
         ↓
NEURX_G1_EFI_ENTRY (proof: entry point reachable, partial ABI valid)
         ↓
NEURX_G1_MEMORY_MAP_READY (proof: GetMemoryMap() struct offsets correct)
         ↓
ExitBootServices(ImageHandle, MapKey)
         ↓
Status == EFI_SUCCESS verified (NOT EFI_ERROR, NOT halt)
         ↓
NEURX_G1_BOOT_SERVICES_EXITED (proof: ExitBootServices succeeded, ownership transferred)
         ↓
NEURX_G1_KERNEL_ENTRY (proof: post-EBS kernel execution works)
         ↓
NEURX_G1_COM1_OWNED (proof: direct port I/O without UEFI services)
         ↓
NEURX_G1_PASS (proof: full sequence complete)
         ↓
All 6 markers in strict order
         ↓
Serial log archived
         ↓
G1 PASS = ✅ UEFI ownership transfer proven
```

**Prerequisite for G2**:
```
G0 PASS ✅
    AND
G1 PASS ✅
    ↓
==================================================
G2 Unlocked: Physical Memory Ownership
==================================================
    ↓
Page Allocator (G2.1)
    ↓
Page Tables / CR3 (G2.2)
    ↓
Real #PF (Page Fault) handling (G2.3)
    ↓
G2 PASS
```

**Engineering Principle**: 
No new code should be added to G2+ until both G0 and G1 pass with serial evidence archived.
The next meaningful event in development is NOT code changes, but actual QEMU/OVMF execution producing first markers.

---
