# Gate G1: Minimal Bare-Metal Boot
## UEFI → NeurX Kernel → Serial Output → Halt

**Objective**: First undeniable proof of bare-metal control.

**Timeline**: 1-2 weeks (after P0 verification)

**Critical**: G1 is ONLY the boot path. Memory/IRQ/scheduler moved to G2/G3.

---

## Acceptance Criteria - Extreme Minimalism

### ✅ Requirements (G1 Only)

```
1. UEFI Handoff
   ✓ UEFI firmware loads NeurX EFI application
   ✓ _efi_main() is invoked
   ✓ ExitBootServices() called
   ✓ Boot Services no longer available

2. Kernel Takeover
   ✓ Control transfers to _neurx_kernel_entry
   ✓ x86_64 long mode confirmed active
   ✓ Interrupts disabled (RFLAGS.IF = 0)
   ✓ Linux is no longer running

3. Serial Console Control
   ✓ NeurX owns COM1 (0x3F8)
   ✓ Direct UART output (no OS intermediary)
   ✓ "NeurX Kernel Ready" printed

4. Execution Halt
   ✓ CPU enters hlt loop
   ✓ No crash, no hang, clean exit
```

---

## Expected Serial Output (ONLY)

```
NeurX Kernel Ready
```

**That's it.** No memory stats, no IRQ info, no timer output.

Just one line proving:
- UEFI loaded your code
- Your code printed to serial
- Your code halted cleanly

---

## What G1 DOES NOT Include

```
❌ Memory initialization (G2)
❌ Page tables / paging (G2)
❌ Interrupt descriptor table (G3)
❌ CPU scheduling (G3)
❌ Timer/APIC (G3)
❌ Device enumeration (G4)
```

These move to their proper gates.

---

## Delivery

### File Structure

```
kernel/
├── boot/
│   └── uefi/
│       ├── entry.s          ← UEFI main entry
│       ├── memory_map.s     ← Get UEFI memmap (for G2)
│       └── exit_boot.s      ← ExitBootServices()
│
└── arch/
    └── x86_64/
        ├── cpu.s           ← CPU detection, mode check
        ├── serial.s        ← COM1 UART output
        └── entry.s         ← kernel_entry after ExitBootServices
```

### Minimal boot.s Entry Point

```s
package neurx.kernel.boot.uefi

func _efi_main(handle: int, system_table: int) int {
    // Get UEFI memory map (save for G2)
    get_uefi_memory_map()
    
    // Exit boot services
    exit_boot_services(handle, system_table)
    
    // Transfer control to x86_64 kernel entry
    kernel_entry()
    
    0
}

func kernel_entry() {
    // We are now bare-metal
    // No UEFI boot services available
    
    // Detect x86_64 mode
    verify_x86_64_mode()
    
    // Initialize serial console (direct UART)
    init_serial_uart()
    
    // Print startup message
    print("NeurX Kernel Ready\n")
    
    // Halt CPU
    halt_cpu()
}

func halt_cpu() {
    loop {
        // hlt instruction (via intrinsic or inline asm)
    }
}
```

---

## Verification Checklist

- [ ] S compiler can compile to x86_64 EFI binary
- [ ] QEMU accepts binary as UEFI application
- [ ] QEMU boots and serial output appears
- [ ] "NeurX Kernel Ready" visible in console
- [ ] CPU halts (no exception, no reboot)
- [ ] Verify Linux is not involved:
  - [ ] No /proc/cpuinfo
  - [ ] No dmesg
  - [ ] No systemd services running
  - [ ] Only QEMU's UEFI + NeurX

---

## Success Markers

```
❌ Failure:
   - EFI binary doesn't load
   - Triple fault or general protection fault
   - No serial output
   - "ExitBootServices() failed" message
   - Code continues to Linux kernel

✅ Success:
   - QEMU boots NeurX EFI app
   - Serial: "NeurX Kernel Ready"
   - CPU halts cleanly
   - Nothing runs after that
```

---

## Why This Gate Is So Small

```
Reason 1: Signal Clarity
  One line of output = one undeniable proof
  No "memory initialization partially works"
  No "timer might be running"
  Pure binary result: prints or doesn't

Reason 2: Fastest Time to Truth
  2 weeks to beat Linux kernel is huge
  1 week proves concept is valid
  Earlier validation = faster iterations

Reason 3: Pure Architecture
  G1 proves: bare-metal boot chain works
  G2 proves: kernel manages memory
  G3 proves: kernel manages execution
  Clean separation

Reason 4: Risk Isolation
  If UEFI handoff fails → S compiler issue
  If serial doesn't work → x86_64 code issue
  If CPU halts wrong → instruction encoding
  Single-layer failure modes
```

---

## Dependency on S Compiler

**Must have (from P0 verification)**:
- S generates freestanding x86_64 code
- No Linux symbol injection
- Can link with custom linker script
- Can produce EFI binary format

---

## Next After G1 Success

Once "NeurX Kernel Ready" prints:

```
G1 Complete: UEFI → Serial → Halt
    ↓
G2 Start: Physical Memory
    ├─ Read UEFI memory map (already collected)
    ├─ Implement physical page allocator
    ├─ Implement malloc/free
    └─ Print: "Physical memory: X MB"

Then:
G3 (IDT + APIC + scheduler)
G4 (PCIe + device enumeration)
...
```

---

## Key Difference from Original G1

**Original G1 included**:
- Physical memory initialization
- Paging + virtual addressing
- Interrupt descriptor table
- APIC timer setup
- Kernel heap

**That was 3 weeks of work mixed in.**

**New G1 is**:
- Boot from UEFI
- Take bare-metal control
- Print one line
- Halt

**This is 1 week of work, crystal clear validation.**

The rest goes to G2, G3, G4 where it belongs.


---

## Development Environment

### Primary: QEMU x86_64
```bash
qemu-system-x86_64 \
  -bios OVMF.fd \
  -kernel neurx_kernel.elf \
  -serial stdio \
  -m 2G
```

### Secondary: Real x86_64 Server
```
After QEMU validation, test on:
- x86_64 server with UEFI
- NVIDIA GPU (optional for G1)
```

---

## Verification Checklist

- [ ] Code compiles to valid x86_64 ELF
- [ ] QEMU accepts kernel as -kernel parameter
- [ ] Serial output appears in QEMU console
- [ ] No Linux kernel runs
- [ ] Boot messages match expected output
- [ ] Kernel doesn't crash/halt unexpectedly
- [ ] Can add test code in kernel_main() and see output

---

## Success Markers

```
❌ Failure:
   - Kernel doesn't load
   - CPU halts/triple faults
   - No serial output
   - Still depends on Linux

✅ Success:
   - QEMU boots NeurX
   - Serial console shows boot sequence
   - Kernel reaches kernel_main()
   - "NeurX Kernel Ready." printed
```

---

## Dependency on S Compiler

### Required
```
S must be able to:
  ✓ Compile to x86_64 ELF binary
  ✓ Support freestanding target (no libc)
  ✓ Generate position-independent code
  ✓ Support inline assembly or intrinsics for CPU ops
```

### Potential Blockers
```
If S doesn't support:
  ❌ freestanding/kernel target
     → Need to patch S compiler
  
  ❌ x86_64 architecture
     → Need to add x86_64 backend
  
  ❌ Bare-metal binary generation
     → Need to implement ELF generation
```

---

## Next After G1 Success

```
G1 Complete (bare-metal boot)
    ↓
G2 Start (physical memory manager)
    ├─ Enhance init_physical_memory()
    ├─ Implement page allocator
    └─ Test malloc/free
    
Then:
G3 (interrupt/timer/scheduler)
G4 (PCIe/NVMe)
G5 (runtime migration)
G6 (GPU driver)
```

---

## Key Files

```
kernel/arch/x86_64/boot.s        ← Entry point
kernel/mm/physical.s              ← Memory mgmt
kernel/irq/idt.s                  ← Interrupts
kernel/time/apic.s                ← Timer
kernel/console/serial.s           ← Output
kernel/kernel.s                   ← Main loop
```

---

## Notes

- This is the **first true bare-metal NeurX execution**
- No Linux dependency
- Serial console is critical for debugging
- QEMU is preferred development environment
- Real hardware testing comes after QEMU validation
- This establishes the foundation for all subsequent gates
