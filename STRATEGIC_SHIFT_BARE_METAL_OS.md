# NeurX: From AI Runtime to Bare-Metal AI Operating System
## Strategic Shift - 2026-08-26

### Previous Direction (❌ Paused)
```
NeurX Runtime (on Linux)
    ↓
Device ABI → CUDA Driver
    ↓
Linux-managed GPU
```

### New Direction (✅ Active)
```
NeurX = Independent Bare-Metal AI OS

UEFI/BIOS
    ↓
NeurX Bootloader
    ↓
NeurX Kernel
    ├─ Memory Manager
    ├─ Interrupt/Timer
    ├─ Scheduler
    ├─ PCIe/Device Support
    └─ S Runtime
    ↓
S Code (Tensor/AI)
    ↓
Physical Hardware
```

---

## 6-Gate Validation Model

| Gate | Status | Target | Timeline |
|------|--------|--------|----------|
| **G0** | ✅ In Progress | S → Linux CUDA → GPU | 1-2 weeks |
| **G1** | 🔴 NEXT | UEFI → NeurX Kernel Boot | 2-3 weeks |
| **G2** | ⏳ PENDING | Memory Management (Physical+Virtual) | 3 weeks |
| **G3** | ⏳ PENDING | Interrupt/Timer/Scheduler | 3 weeks |
| **G4** | ⏳ PENDING | PCIe/NVMe/NIC | 2-3 weeks |
| **G5** | ⏳ PENDING | S Runtime on NeurX Kernel | 2 weeks |
| **G6** | ⏳ PENDING | GPU Execution (bare metal) | 3-4 weeks |

**Total Timeline**: ~16 weeks to bare-metal AI OS

---

## Critical Architectural Principle

```
Kernel MUST NOT depend on Runtime
Runtime MUST depend on Kernel

✅ Correct dependency:
   S code
     ↓
   NeurX Runtime
     ↓
   NeurX Kernel
     ↓
   Hardware

❌ Wrong (current state):
   S code
     ↓
   NeurX Runtime
     ↓
   Linux Kernel
     ↓
   Hardware
```

---

## Directory Structure (New)

```
neurx/
├── kernel/                    ← 🔴 HIGHEST PRIORITY
│   ├── arch/
│   │   └── x86_64/
│   │       ├── boot.s         ← UEFI entry
│   │       ├── cpu.s          ← CPU initialization
│   │       ├── paging.s       ← Virtual memory
│   │       ├── interrupt.s    ← IDT/exceptions
│   │       └── context.s      ← Context switch
│   │
│   ├── mm/
│   │   ├── physical.s         ← Page allocator
│   │   ├── virtual.s          ← Page tables
│   │   └── heap.s             ← Kernel heap
│   │
│   ├── sched/
│   │   ├── thread.s
│   │   └── scheduler.s
│   │
│   ├── irq/
│   │   ├── idt.s
│   │   └── apic.s
│   │
│   ├── time/
│   ├── pci/
│   ├── console/
│   └── kernel.s               ← Main entry
│
├── drivers/                   ← 🟠 After G4
│   ├── serial/
│   ├── pci/
│   ├── nvme/
│   ├── network/
│   └── gpu/
│
├── runtime/                   ← 🟡 After G5
│   ├── allocator/
│   ├── scheduler/
│   └── executor/
│
├── inference/                 ← 🟢 After G6
│   └── transformer/
│
├── tools/
│   └── qemu/                  ← Development environment
│       ├── run.sh
│       └── gdb.sh
│
└── doc/
    ├── ARCHITECTURE.md
    ├── BOOT_PROCESS.md
    ├── MEMORY_DESIGN.md
    └── GATES.md
```

---

## G0 Status (Current Week)

### What to Complete
```
✅ gpu_basic_add.s (S code on Linux)
✅ Device ABI CUDA bindings
✅ 5 Gates verification (on Linux + NVIDIA GPU)
```

### Key Achievement
```
Proof: S can control real GPU on Linux
Evidence:
  - Functional: Output correct
  - Physical: VRAM changes
  - Runtime: CUDA success
```

### Then STOP GPU Work
```
❌ Do NOT continue:
   - GEMM
   - RoPE
   - Attention
   - Transformer inference

✅ Immediately START:
   - Kernel/boot.s (G1)
```

---

## G1 Priority (Next 2-3 Weeks)

### Milestone: First Bare-Metal Boot

### Acceptance Criteria
```
Server powered on
    ↓
UEFI loads NeurX bootloader
    ↓
NeurX Kernel Entry
    ↓
CPU x86_64 initialized
    ↓
Serial console output:

[BOOT] UEFI handoff complete
[CPU ] CPU x86_64 initialized
[MM  ] Physical memory OK
[VM  ] Paging initialized
[IRQ ] IDT initialized
[TMR ] Timer initialized

NeurX Kernel Ready.
```

### No Linux involved
```
❌ No Linux Kernel
❌ No glibc
❌ No systemd
✅ Pure bare metal x86_64 execution
```

### Development Environment
```
Primary: QEMU x86_64
  $ qemu-system-x86_64 -bios OVMF.fd -kernel neurx_kernel

Secondary: Real x86_64 server (after G1 stable)
```

---

## Why This Order

```
❌ Wrong: GPU first
   → Requires Linux driver
   → Extends Linux dependency
   → Delays bare-metal milestone

✅ Right: Kernel first
   → Establishes independence from Linux
   → Creates foundation for all drivers
   → Enables G6 GPU driver later
```

---

## Key Design Decisions

### 1. Kernel ABI
```
S language → NeurX Kernel syscall interface
(To be defined in kernel/kernel.s)

NOT Linux syscall
(We're replacing Linux, not relying on it)
```

### 2. Memory Model
```
Physical Memory Manager
    ↓
Page Allocator (4KB pages)
    ↓
Virtual Memory (64-bit VA)
    ↓
Kernel Heap (malloc/free)
    ↓
S Runtime Allocator
    ↓
Tensor/Model allocation
```

### 3. Execution Model
```
NOT: Process/fork/exec
    (Traditional POSIX model)

Instead:
- Thread (kernel execution context)
- Task/Job (AI workload unit)
- Model (Transformer instance)
```

---

## Current GPU Work (G0) Status

### What We Built
```
✅ sys/device_abi_cuda.s (framework)
✅ test/gpu_basic_add.s (test harness)
✅ test/GPU_BASIC_ADD_VALIDATION.md (spec)
```

### What We Need
```
⚠️  CUDA Driver API bindings (FFI implementation)
    - Depends on S compiler FFI capability
    - Currently blocking G0 completion
```

### After G0 Completes
```
✅ Archive: All GPU/CUDA work for later
✅ Lesson: Proof that S → CUDA → GPU works
✅ Freeze: gpu_basic_add code (reference)
✅ Move: Full team focus to Kernel (G1)
```

---

## Next Immediate Actions

### This Session
1. ✅ Document strategic shift (this file)
2. ✅ Create kernel/ directory structure
3. ⏳ Commit: "Strategic shift: bare-metal OS priority"

### Next Session (Tomorrow or when ready)
1. Investigate S compiler FFI capability
2. If FFI available: Complete CUDA bindings (G0)
3. If FFI unavailable: Document limitation, move to G1 prep
4. Create kernel/arch/x86_64/boot.s stub
5. Define NeurX Kernel entry point in S

### Week 2
1. Complete kernel boot (G1)
2. Demonstrate QEMU boot output
3. Add memory initialization (G2 prep)

---

## Success Criteria

### G0 Success
```
gpu_basic_add runs on H100
All 5 Gates PASS
```

### G1 Success
```
NeurX Kernel boots on QEMU
Serial console outputs boot messages
No Linux kernel involved
```

### Project Success (6+ months)
```
Bare-metal AI OS
    ↓
Runs Transformer model
    ↓
Controls multiple GPUs
    ↓
100% independent of Linux
```

---

## Important Notes

### Why GPU comes AFTER Kernel
```
Linux Dependency Chain:
  GPU → NVIDIA Linux Driver → Linux Kernel
  
NeurX Independence Chain:
  NeurX Kernel → Device Driver → GPU
  
We must establish Kernel first,
then device drivers can depend on it.
```

### CUDA ABI Work is NOT Wasted
```
✅ Valuable for:
   - Proof that S language can integrate C APIs
   - Test/validation on Linux before bare-metal
   - Reference implementation for later GPU driver
   
❌ But NOT final solution:
   - libcuda.so depends on Linux
   - Long-term: NeurX GPU driver replaces libcuda
```

### Timeline is Realistic
```
Kernel + boot:        2-3 weeks
Memory:               3 weeks
Scheduling:           3 weeks
PCIe:                 2-3 weeks
Runtime migration:    2 weeks
GPU integration:      3-4 weeks
────────────────
Total:               ~16 weeks
```

By end of Q4 2026 or Q1 2027: Production bare-metal AI OS

---

## Strategic Value

```
When NeurX boots without Linux:
  ✅ No more dependency on open-source kernel
  ✅ Full control of resource allocation
  ✅ Optimized for AI (not general purpose)
  ✅ Competitive advantage vs traditional OS
  ✅ Clear "AI Operating System" positioning

This is the moment NeurX becomes truly differentiated.
```
