# Gate G1: Bare-Metal Boot Verification
## NeurX Kernel First Boot on x86_64

**Objective**: Prove NeurX Kernel can boot from bare metal (UEFI/BIOS) without Linux.

**Timeline**: 2-3 weeks

---

## Acceptance Criteria

### ✅ Requirements

```
1. CPU Control
   ✓ Kernel takes control from UEFI
   ✓ x86_64 long mode active
   ✓ Stack initialized
   ✓ No Linux kernel involved

2. Early Console
   ✓ Serial output (COM1 at 0x3F8)
   ✓ Boot messages printed
   ✓ Debugging visible

3. Memory Initialization
   ✓ Physical memory detected (from firmware)
   ✓ Page allocator functional
   ✓ Basic malloc/free works

4. Kernel Readiness
   ✓ Paging initialized
   ✓ IDT setup
   ✓ Timer/APIC initialized
   ✓ Kernel enters main loop
```

---

## Expected Serial Output

```
[BOOT] NeurX Kernel v0.1
[BOOT] Booting on x86_64...
[CPU ] CPU x86_64 initialized
[CPU ] Interrupts disabled during init
[MM  ] Physical memory initialized
[MM ] Total memory: 65536 MB
[MM  ] Physical page allocator ready
[VM  ] Virtual memory initialized
[VM  ] Page tables setup
[IRQ ] IDT initialized
[IRQ ] Exception handlers registered
[TMR ] APIC timer initialized
[HEAP] Kernel heap initialized
[KERNEL] Entering main loop

NeurX Kernel Ready.
```

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
