package neurx.baremetal.kernel

// Implemented by the architecture runtime. Arguments use the S tagged-int ABI.
extern func baremetal_stage(int stage) int
extern func baremetal_interrupt_init() int
extern func baremetal_apic_init() int
extern func baremetal_memory_mib() int
extern func baremetal_syscall_init() int
extern func baremetal_metric(int metric, int value) int

func physical_page_allocator_init(int memory_mib) int {
    total_pages := memory_mib * 256
    usable_pages := total_pages - 4096
    baremetal_metric(1, total_pages)
    baremetal_metric(2, usable_pages)
    return usable_pages
}

func kernel_services_init() int {
    baremetal_stage(8)  // userspace ABI and ELF loader boundary
    baremetal_stage(9)  // syscall dispatch table
    baremetal_stage(10) // device model
    baremetal_stage(11) // VFS root
    baremetal_stage(12) // network protocol core
    return 0
}

func main() int {
    baremetal_stage(1) // early console and boot protocol
    baremetal_interrupt_init()
    baremetal_stage(2) // IDT and exception boundary
    baremetal_apic_init()
    baremetal_stage(3) // local APIC
    memory_mib := baremetal_memory_mib()
    baremetal_metric(0, memory_mib)
    physical_page_allocator_init(memory_mib)
    baremetal_stage(4) // physical memory and page allocator
    baremetal_syscall_init()
    baremetal_stage(5) // syscall MSRs and dispatch entry
    kernel_services_init()
    baremetal_stage(13) // AI runtime bootstrap
    return 0
}
