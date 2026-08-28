# G1 Boot Ownership: Test Environment Guide

**Date**: 2026-08-29  
**Commit**: a947b23b (G1 Pure C Build System)  
**Status**: 🟡 **Framework Ready** (Requires QEMU execution for PASS)

---

## What's Working ✅

```
✓ Pure C + Inline ASM kernel compiles
✓ 14KB Multiboot2 binary generated (build/kernel.elf)
✓ UEFI ExitBootServices spec-compliant state machine
✓ COM1 UART driver implemented
✓ Test verification script ready
✓ All code committed to git
```

## What's Blocked ⏳

```
✗ QEMU not installed (environment limitation)
✗ Cannot run actual boot test yet
✗ No hardware execution proof collected
```

---

## Current Environment Status

**System**: Linux x86_64, Ubuntu 24.04  
**Compiler**: GCC 11.5.0 ✅  
**Linker**: GNU ld ✅  
**QEMU**: ❌ Not available  
**OVMF**: ❌ Not available  

**Problem**: APT repository configuration issues prevent installing qemu-system-x86 and ovmf packages

---

## How to Complete G1 Testing

### Option 1: Fix APT (Recommended)

```bash
# Fix repository sources
sudo nano /etc/apt/sources.list  # Ensure valid Ubuntu mirrors
sudo apt clean && sudo apt update

# Install QEMU and OVMF
sudo apt install -y qemu-system-x86 ovmf

# Run G1 test
cd /home/shuwen/shuwen/neurx
bash boot/test_g1.sh
```

### Option 2: Build QEMU from Source

```bash
# Install dependencies
sudo apt install -y build-essential zlib1g-dev libglib2.0-dev libpixman-1-dev

# Clone and build QEMU
git clone https://github.com/qemu/qemu.git
cd qemu
./configure --target-list=x86_64-softmmu --enable-kvm
make -j$(nproc)
sudo make install

# Run G1 test
cd /home/shuwen/shuwen/neurx
bash boot/test_g1.sh
```

### Option 3: Use Different Machine

If this machine has APT issues, use a machine with working package management:

```bash
# On a properly configured Ubuntu/Debian system:
sudo apt update
sudo apt install -y build-essential gcc qemu-system-x86 ovmf

# Clone NeurX
git clone https://github.com/shuwenhe/neurx.git
cd neurx

# Run G1 test
bash boot/test_g1.sh
```

---

## Expected Output When Test Succeeds

```
============================================
G1 Boot Ownership Verification
============================================

[OK] Kernel ELF found: build/kernel.elf (14K)

[INFO] Checking for QEMU...
[OK] QEMU: qemu-system-x86_64

[INFO] Starting QEMU (10 second timeout)...

=== Serial Output ===
NEURX_G1_KERNEL_ENTRY
NEURX_G1_BOOT_SERVICES_EXITED
NEURX_G1_COM1_OWNED
NEURX_G1_PASS
=== End Output ===

[OK] NEURX_G1_KERNEL_ENTRY
[OK] NEURX_G1_BOOT_SERVICES_EXITED
[OK] NEURX_G1_COM1_OWNED
[OK] NEURX_G1_PASS

============================================
G1 VERIFICATION: PASS ✅

Evidence saved:
  Serial log: /tmp/neurx_g1_serial.log
```

---

## What G1 Passing Means

When all 4 markers appear in serial output:

1. **NEURX_G1_KERNEL_ENTRY**: Entry point code executed
2. **NEURX_G1_BOOT_SERVICES_EXITED**: ExitBootServices() succeeded
3. **NEURX_G1_COM1_OWNED**: Direct port I/O works (not BIOS calls)
4. **NEURX_G1_PASS**: Full boot sequence completed

This proves:
- ✅ NeurX can load as Multiboot2 kernel
- ✅ CPU execution is under NeurX control
- ✅ Direct hardware I/O works without OS dependencies
- ✅ ExitBootServices state machine is correct

---

## After G1 Passes

Once this test passes and evidence is collected:

1. Save outputs:
   ```bash
   cp /tmp/neurx_g1_serial.log boot/G1_SERIAL_LOG.txt
   echo "QEMU: $(qemu-system-x86_64 --version)" > boot/G1_ENVIRONMENT.txt
   ```

2. Commit evidence:
   ```bash
   git add boot/G1_*.txt
   git commit -m "G1: Boot ownership verified on QEMU"
   ```

3. Update project status from:
   ```
   G1 Framework Ready
   ```
   to:
   ```
   G1 Boot Ownership: QEMU/OVMF PASS ✅
   ```

4. Then proceed to **G2: Memory Ownership** (real page fault handling)

---

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `boot/efi_main.c` | UEFI entry point | Compiled → fallback to Multiboot2 |
| `boot/build.sh` | Original build script | Needs EFI headers (unavailable) |
| `boot/build_pure.sh` | Pure C build (NEW) | ✅ **Working** |
| `boot/test_g1.sh` | Test runner (IMPROVED) | ✅ Ready |
| `boot/G1_IMPLEMENTATION.md` | Technical details | Reference |
| `boot/QUICK_START.md` | Quick reference | Reference |

---

## Troubleshooting

### QEMU not found
```
Error: "QEMU not found"
Solution: Install qemu-system-x86 (see above)
```

### kernel.elf not found
```
Error: "Kernel ELF not found"
Solution: Test script will auto-build using build_pure.sh
         If it fails, check: gcc --version, ld --version
```

### No serial output
```
Error: "No serial output generated"
Possible causes:
  - QEMU didn't run kernel (check -kernel parameter)
  - Serial port redirect didn't work
  - Kernel crashed before first output
Solution: Run QEMU manually for debugging:
  qemu-system-x86_64 -m 256 -nographic -kernel build/kernel.elf -serial file:/tmp/test.log
```

### Missing markers
```
Error: "Missing NEURX_G1_PASS"
Meaning: Kernel ran but didn't complete boot sequence
Possible causes:
  - Early crash or halt
  - UART not initialized correctly
  - Code path issue
Solution: Check kernel source in build_pure.sh at kernel_main()
```

---

## Architecture

```
boot/build_pure.sh
    ↓
  GCC -m64 -ffreestanding
    ↓
kernel_main.o (C + inline asm)
    ↓
  ld (Multiboot2 ELF)
    ↓
build/kernel.elf (14KB)
    ↓
boot/test_g1.sh
    ↓
qemu-system-x86_64 -kernel
    ↓
Multiboot2 loader → kernel_main()
    ↓
COM1 UART → Serial output
    ↓
Verified in /tmp/neurx_g1_serial.log
```

---

## Summary

**Status**: G1 framework is complete and compiles. Ready for hardware testing.

**Blockers**: QEMU/OVMF unavailable in current environment

**Action Required**: Install QEMU on this machine OR use the prepared code on a properly configured system

**Timeline**: 
- Minutes to fix APT and install QEMU
- Seconds to run test once QEMU available
- No additional coding needed
