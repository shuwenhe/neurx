Phase 1 - Kernel Bonework

What I added:
- `src/kernel/syscall_compat.s` : basic syscall table + dispatch stub
- `src/kernel/scheduler_basic.s` : simple scheduler skeleton
- `src/mm/vm_basic.s` : virtual memory region manager skeleton
- smoke tests under `test/` for each component
- `phase0_missing_features.csv` : initial missing features list

Next steps:
- Implement syscall handlers and userland trap entry
- Extend scheduler with preemption and task states
- Wire VM regions to a physical page allocator
- Add CI job to run smoke tests using the S toolchain
