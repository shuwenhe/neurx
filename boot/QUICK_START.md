# G1 Quick Start - 3 Steps

**Time to try G1**: 5-10 minutes (if tools are installed)

## Step 1: Check Environment (2 min)

```bash
# Run this to check if you have required tools
cd /home/shuwen/shuwen/neurx/boot

# Check tools
gcc --version && echo "✓ gcc"
ld --version | head -1 && echo "✓ ld"
objcopy --help > /dev/null && echo "✓ objcopy"
nasm -version 2>/dev/null && echo "✓ nasm" || echo "✗ nasm (optional)"
qemu-system-x86_64 --version 2>/dev/null && echo "✓ qemu" || echo "✗ qemu (needs install)"
```

**If all green**: Go to Step 2
**If nasm missing**: Still OK, will use only C
**If qemu missing**: Install: `sudo apt install -y qemu-system-x86`

---

## Step 2: Build (3 min)

```bash
cd /home/shuwen/shuwen/neurx/boot

# Make build executable
chmod +x build.sh build_alternative.sh

# Try to build
bash build.sh

# If that fails:
bash build_alternative.sh
```

**Success indicators**:
- `[OK] Build directory: build`
- `[OK] efi_main.o generated`
- `[OK] build/kernel.elf generated`
- File `build/kernel.elf` exists

**If build fails**:
```bash
# Try minimal manual compile
gcc -c efi_main.c -o build/efi_main.o
# If that works, try minimal link
ld -nostdlib build/efi_main.o -o build/kernel.elf
```

---

## Step 3: Test G1 (5 min)

```bash
cd /home/shuwen/shuwen/neurx

# Make test executable
chmod +x boot/test_g1.sh

# Run test (this starts QEMU)
bash boot/test_g1.sh

# WAIT 10 seconds for QEMU to run and output
```

**Success**: You see this at the end:
```
G1 VERIFICATION: PASS ✅
```

**Failure**: You see:
```
G1 VERIFICATION: FAIL ❌
```

---

## What's Happening

```
You run test_g1.sh
    ↓
test_g1.sh starts QEMU with kernel.elf
    ↓
QEMU loads UEFI firmware
    ↓
UEFI loads NeurX EFI app (kernel.elf)
    ↓
NeurX efi_main() runs
    ↓
ExitBootServices() - CPU ownership to NeurX
    ↓
NeurX initializes COM1 serial port
    ↓
NeurX outputs 4 test messages to serial
    ↓
QEMU redirects serial to file: /tmp/neurx_g1_serial.log
    ↓
test_g1.sh reads file and checks for required strings
    ↓
If all 4 strings present: PASS ✅
```

---

## Troubleshooting Quick Ref

| Problem | Solution |
|---------|----------|
| "gcc not found" | `sudo apt install build-essential` |
| "ld not found" | `sudo apt install binutils` |
| "qemu not found" | `sudo apt install qemu-system-x86` |
| Build fails | Try `bash build_alternative.sh` |
| Test hangs | Wait 10 sec, then Ctrl+C (it's OK) |
| No serial output | Check `/tmp/neurx_g1_serial.log` exists |
| File is empty | QEMU may not have started correctly |
| "only 2 strings found" | Kernel entry works but UART init failed |

---

## What G1 Proves (If PASS)

✅ NeurX can be loaded from UEFI  
✅ ExitBootServices() call works  
✅ CPU executes NeurX code after boot  
✅ Direct hardware I/O (UART) works  
✅ NeurX owns the CPU  
✅ Linux is NOT involved  

---

## Files You Need

```bash
# These are already created:
ls -la boot/efi_main.c
ls -la boot/build.sh
ls -la boot/test_g1.sh
ls -la boot/G1_IMPLEMENTATION.md
```

All present? Great, you're ready!

---

## Next After G1 PASS

1. Commit to git: `git add boot/ && git commit -m "G1: Boot ownership"`
2. Document results
3. Move to G2: Real page fault handling (but keep G1 passing)

---

## Run This Now

```bash
cd /home/shuwen/shuwen/neurx
bash boot/test_g1.sh
```

Report result:
- **PASS ✅**: You own the CPU
- **FAIL ❌**: Debug using test script output
- **ERROR**: Check prerequisites

Good luck! 🚀
