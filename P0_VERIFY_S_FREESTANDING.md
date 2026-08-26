# P0: Verify S Compiler Freestanding Capability
## Critical Prerequisite Before Any Kernel Work

**Status**: 🔴 BLOCKING - Must complete before kernel development

---

## The Problem

You can write:
```s
package neurx.kernel.boot.uefi

func _efi_main() int {
    return 0
}
```

But S compiler might silently inject:
```
- libc.so (stdio, malloc, memset)
- ld-linux (dynamic linker)
- Runtime startup code (__libc_start_main)
- Linux syscall stubs
```

**You won't know until binary inspection.**

---

## Verification Steps

### Step 1: Minimal Freestanding Test
Create test file:
```s
package test.freestanding

func main() int {
    1
}
```

Compile with S compiler (check flags):
```bash
s -target x86_64-unknown-none \
  -freestanding \
  -nostdlib \
  test_freestanding.s \
  -o test_freestanding.o
```

### Step 2: Binary Inspection

Check for unwanted dependencies:
```bash
# Show all undefined symbols
nm -u test_freestanding.o

# Show all defined symbols
nm -D test_freestanding.o

# Check dependencies
readelf -d test_freestanding.o

# Disassemble and look for syscall/int 0x80
objdump -d test_freestanding.o | grep -E "syscall|int.*0x80"
```

### Step 3: Expected Results

✅ **Freestanding is working if:**
```
nm -u test_freestanding.o
# Output: (empty or only arch-specific symbols like __libc_csu_init)

readelf -d test_freestanding.o
# No NEEDED libc.so.6, ld-linux-x86-64.so.2

objdump -d test_freestanding.o | grep syscall
# (empty - no syscalls)
```

❌ **Freestanding is broken if:**
```
nm -u test_freestanding.o
undefined symbol: printf
undefined symbol: malloc
undefined symbol: memset
undefined symbol: __libc_start_main

readelf -d test_freestanding.o
  NEEDED                libc.so.6
  NEEDED                ld-linux-x86-64.so.2

objdump -d test_freestanding.o | grep syscall
  ... syscall instructions found ...
```

---

## What Each Symbol Means

| Symbol | Means | Status |
|--------|-------|--------|
| `printf` | Needs C stdlib | ❌ Freestanding broken |
| `malloc` | Needs libc memory | ❌ Freestanding broken |
| `memset` | Should inline, not call | ⚠️ May be OK if intrinsic |
| `__libc_start_main` | Needs Linux startup | ❌ Freestanding broken |
| `mmap` | Needs Linux syscall | ❌ Freestanding broken |
| `write` | Needs Linux syscall | ❌ Freestanding broken |
| `exit` | Needs Linux syscall | ❌ Freestanding broken |

---

## Architectural Implications

### If S Supports Freestanding

```
S source (freestanding)
    ↓
S compiler (with -freestanding)
    ↓
x86_64 machine code (NO Linux deps)
    ↓
Can link with UEFI or bare-metal
```

**Path forward**: Proceed with kernel development

### If S Does NOT Support Freestanding

```
S source
    ↓
S compiler (injects Linux runtime)
    ↓
Binary with libc/ld-linux/syscalls
    ↓
UEFI rejects
BARE-METAL FAILS
```

**Options**:
1. Patch S compiler to add `-freestanding` support
2. Write kernel in C/Rust with known freestanding support
3. Use S runtime on top of minimal C kernel bootstrap

---

## Compiler Flags to Check

Ask S compiler support for:
```bash
s --help | grep -E "freestanding|nostdlib|target|no-"
```

Look for:
- `-freestanding` (compile without assuming hosted environment)
- `-nostdlib` (don't link standard library)
- `-target x86_64-unknown-none` or similar (bare-metal target)
- `-fno-stack-protector` (no canary)
- `-fno-pie` (no position independent code)

---

## Next Steps Based on Result

### ✅ If Freestanding Works

1. Proceed to kernel/boot/uefi/entry.s
2. Write minimal UEFI stub that:
   - Takes control from UEFI firmware
   - Calls ExitBootServices()
   - Jumps to _efi_main()
3. Add serial port output
4. Test on QEMU
5. Move to G1

### ❌ If Freestanding Fails

1. **Option A**: Patch S compiler
   - Add `-freestanding` mode
   - Suppress automatic runtime injection
   - Timeline: 1-2 weeks if S has clean architecture

2. **Option B**: Hybrid approach
   - Write minimal x86_64 bootstrap in inline asm within S
   - Minimal C runtime layer
   - Timeline: 1 week

3. **Option C**: Fall back to C kernel
   - Use TinyCore or minimal C bootstrap
   - Integrate S later as runtime layer
   - Timeline: Different architecture, may delay 2-3 weeks

---

## Success Criteria

```
✅ PASS:
   - S produces freestanding object
   - No Linux symbols present
   - Can link with custom linker script
   - Can load as UEFI application
   - Outputs to serial port

❌ FAIL:
   - S injects libc/ld-linux
   - Symbols undefined at UEFI load time
   - Runtime startup code conflicts
```

---

## Timeline

**P0 Verification**: 1-2 days
- Test minimal S freestanding program
- Binary analysis
- Document findings
- Decision on path forward

**If needed**: Compiler patch or hybrid approach
- Add freestanding support: 1-2 weeks
- Or proceed with hybrid/alternative approach

---

## DO NOT SKIP THIS

You cannot build bare-metal OS on top of a runtime that secretly depends on Linux.

**Verify S freestanding first. Everything else depends on this.**
