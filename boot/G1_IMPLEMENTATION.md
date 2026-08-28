# G1 Boot Ownership - Implementation Guide

**Goal**: Prove CPU control is in NeurX, not Linux. No external OS involvement.

**Verification**: QEMU serial output must show these exact strings in order:
```
NEURX_G1_KERNEL_ENTRY
NEURX_G1_BOOT_SERVICES_EXITED
NEURX_G1_COM1_OWNED
NEURX_G1_PASS
```

---

## G1 Architecture

```
UEFI Firmware (OVMF)
    ↓ loads
efi_main.c (compiled as EFI application)
    ↓ calls
ExitBootServices()
    ↓ transition to bare-metal
Initialize COM1 UART (direct I/O port access)
    ↓
Output verification strings
    ↓
HLT loop (CPU ownership ends here - NeurX controls hardware)
```

**Key distinction**: After `ExitBootServices()`, all UEFI services are gone. 
Only code is NeurX. If it works, WE own the hardware.

---

## Prerequisites

### Required Software
```bash
# Linux toolchain
sudo apt install -y build-essential
sudo apt install -y binutils

# QEMU emulator
sudo apt install -y qemu-system-x86

# UEFI firmware (optional, but recommended)
sudo apt install -y ovmf

# Assembler (for Multiboot2 alternative)
sudo apt install -y nasm

# For EFI development (optional)
sudo apt install -y gnu-efi-dev
```

### Verify Installation
```bash
gcc --version
ld --version
qemu-system-x86_64 --version
objcopy --help | grep -q "Usage" && echo "objcopy OK"
nasm -version
ls -la /usr/share/OVMF/OVMF_CODE.fd 2>/dev/null || echo "OVMF firmware not found"
```

---

## Build Process

### Step 1: Compile
```bash
cd /home/shuwen/shuwen/neurx/boot

# Try primary build (with EFI libraries)
bash build.sh

# If that fails, try alternative (Multiboot2)
bash build_alternative.sh
```

Expected output:
```
[OK] Build directory: build
[OK] Required tools available
[OK] efi_main.o generated
[OK] build/kernel.elf generated
Binary Information:
-rw-r--r-- 1 user user XXXXX build/kernel.elf
...
Build complete!
```

### Step 2: Verify Binary Exists
```bash
ls -lh build/kernel.elf
file build/kernel.elf
```

Should show:
- ELF 64-bit or 32-bit executable
- At least a few KB in size
- Contains symbol `efi_main` or entry point

---

## Test Execution

### Step 1: Make Test Script Executable
```bash
chmod +x boot/test_g1.sh
```

### Step 2: Run G1 Verification
```bash
cd /home/shuwen/shuwen/neurx
bash boot/test_g1.sh
```

### Expected Output

```
============================================
G1 Boot Ownership Verification
============================================

[OK] Kernel ELF found: ./build/kernel.elf
[INFO] Starting QEMU with kernel...
[INFO] Waiting up to 10s for serial output...

============================================
Serial Output Log:
============================================
NEURX_G1_KERNEL_ENTRY
NEURX_G1_BOOT_SERVICES_EXITED
NEURX_G1_COM1_OWNED
NEURX_G1_PASS
NEURX_G1_HALTING
============================================

[PASS] Found: NEURX_G1_KERNEL_ENTRY
[PASS] Found: NEURX_G1_BOOT_SERVICES_EXITED
[PASS] Found: NEURX_G1_COM1_OWNED
[PASS] Found: NEURX_G1_PASS

========================================
G1 VERIFICATION: PASS ✅
========================================

Boot ownership achieved:
  ✓ UEFI firmware loaded NeurX image
  ✓ ExitBootServices() confirmed
  ✓ CPU control passed to NeurX kernel entry
  ✓ COM1 UART initialized and functional
  ✓ NeurX owns hardware
```

### If Test Fails

**Case 1: Build Error**
```
[FAIL] Kernel ELF not found
→ Run build.sh or build_alternative.sh first
```

**Case 2: QEMU Not Found**
```
Command 'qemu-system-x86_64' not found
→ sudo apt install qemu-system-x86
```

**Case 3: No Serial Output**
```
[FAIL] Missing: NEURX_G1_KERNEL_ENTRY
→ Serial I/O initialization failed
→ Check COM1 port address (0x3F8)
→ Verify QEMU redirects serial to file
```

**Case 4: Incomplete Output**
```
[PASS] NEURX_G1_KERNEL_ENTRY
[PASS] NEURX_G1_BOOT_SERVICES_EXITED
[FAIL] Missing: NEURX_G1_COM1_OWNED
→ UART initialization failed after ExitBootServices()
→ Check assembly I/O operations
```

---

## Technical Details

### UEFI Flow

1. **efi_main()**
   - Receives control from UEFI firmware with SystemTable pointer
   - Gets memory map (needed for ExitBootServices)
   - Calls ExitBootServices() - **CRITICAL TRANSITION**
   
2. **After ExitBootServices()**
   - No UEFI services available
   - Direct hardware access only
   - COM1 must be initialized via I/O ports
   
3. **COM1 Initialization** (0x3F8 UART port)
   - Set baud rate divisor to 1 (115200 baud)
   - Set 8 bits, 1 stop bit, no parity
   - Set DTR, RTS control lines
   - Enable transmission

4. **Serial Output**
   - Direct `outb()` to port 0x3F8 (data)
   - Poll port 0x3F8+6 (line status) for TXRE bit
   - If TXRE set, transmit is ready

### G1 Verification Criteria

**PASS**: All 4 strings appear in serial output in order
```
NEURX_G1_KERNEL_ENTRY          (kernel entry confirmed)
NEURX_G1_BOOT_SERVICES_EXITED  (bare-metal mode confirmed)
NEURX_G1_COM1_OWNED            (UART working)
NEURX_G1_PASS                  (all systems go)
```

**FAIL**: Any missing string or wrong order

---

## What G1 Proves

✅ **What Works**:
- UEFI can load and execute our binary
- ExitBootServices() transition successful
- CPU is executing NeurX code (not Linux)
- Direct hardware I/O operations work
- Serial UART is functional and owned by NeurX
- Bootstrap complete

❌ **What's NOT Tested Yet**:
- Virtual memory (that's G2)
- Interrupts (that's G3)
- Task scheduling (that's G4)

---

## Next Steps After G1 PASS

Once G1 passes repeatedly:

1. **Commit to Git**
   ```bash
   git add boot/
   git commit -m "G1: Boot ownership achieved - UEFI → bare-metal → UART"
   git push
   ```

2. **Prepare for G2**
   - Real page fault handling
   - Virtual memory setup
   - Page table manipulation
   - IDT installation

3. **Maintain Verification**
   - Keep test_g1.sh running
   - Ensure G1 remains passing before moving to G2
   - G2 must not break G1

---

## Troubleshooting Checklist

- [ ] GCC is installed and working
- [ ] QEMU can run (or will be installed)
- [ ] build.sh or build_alternative.sh completes without error
- [ ] kernel.elf exists and is larger than 1KB
- [ ] test_g1.sh is executable (chmod +x)
- [ ] test_g1.sh runs QEMU for at least 5 seconds
- [ ] Serial output file is created and contains some output
- [ ] All 4 required strings appear in correct order
- [ ] No critical errors in QEMU log

---

## File Structure

```
neurx/
├── boot/
│   ├── efi_main.c           (UEFI entry point, COM1 I/O, main flow)
│   ├── build.sh             (Primary build script)
│   ├── build_alternative.sh (Multiboot2 alternative)
│   ├── test_g1.sh           (G1 verification script - strict criteria)
│   └── G1_IMPLEMENTATION.md (this file)
└── build/                   (created by build script)
    ├── kernel.elf           (final bootable kernel)
    ├── efi_main.o           (compiled object)
    ├── qemu.log             (QEMU debug output)
    └── ...
```

---

## Success Definition

**G1 COMPLETE** when:
```bash
./boot/test_g1.sh
# ...output...
G1 VERIFICATION: PASS ✅
# Exit code: 0
```

That's it. Simple, verifiable, repeatable hardware proof.
