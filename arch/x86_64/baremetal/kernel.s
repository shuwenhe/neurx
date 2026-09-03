package neurx.baremetal.kernel

extern func baremetal_stage(int stage) int
extern func baremetal_interrupt_init() int
extern func baremetal_apic_init() int
extern func baremetal_memory_mib() int
extern func baremetal_syscall_init() int
extern func baremetal_metric(int metric, int value) int
extern func baremetal_bitmap_test(int frame) int
extern func baremetal_bitmap_set(int frame) int
extern func baremetal_bitmap_clear(int frame) int
extern func baremetal_tss_init() int
extern func baremetal_apic_timer_init() int
extern func baremetal_pci_vendor(int device) int
extern func baremetal_initramfs_files() int
extern func baremetal_ring3_image_valid() int
extern func baremetal_virtio_net_probe() int
extern func baremetal_logical_cpu_count() int
extern func baremetal_tsc_cycles() int

func frame_alloc(int first_frame, int frame_limit) int {
    int frame = first_frame
    for frame < frame_limit {
        used := baremetal_bitmap_test(frame)
        if used == 0 {
            baremetal_bitmap_set(frame)
            return frame
        }
        frame = frame + 1
    }
    return -1
}

func frame_free(int frame) int {
    return baremetal_bitmap_clear(frame)
}

func pci_scan_bus_zero() int {
    int device = 0
    int found = 0
    for device < 32 {
        vendor := baremetal_pci_vendor(device)
        if vendor != 65535 {
            found = found + 1
        }
        device = device + 1
    }
    return found
}

func physical_page_allocator_init(int memory_mib) int {
    total_pages := memory_mib * 256
    usable_pages := total_pages - 4096
    baremetal_metric(1, total_pages)
    baremetal_metric(2, usable_pages)
    frame := frame_alloc(4096, total_pages)
    baremetal_metric(3, frame)
    frame_free(frame)
    recycled := frame_alloc(4096, total_pages)
    baremetal_metric(4, recycled)
    return usable_pages
}

func kernel_services_init() int {
    elf_valid := baremetal_ring3_image_valid()
    baremetal_metric(5, elf_valid)
    baremetal_stage(8)  
    files := baremetal_initramfs_files()
    baremetal_metric(6, files)
    baremetal_stage(9)  
    pci_devices := pci_scan_bus_zero()
    baremetal_metric(7, pci_devices)
    baremetal_stage(10) 
    virtio_net := baremetal_virtio_net_probe()
    baremetal_metric(8, virtio_net)
    baremetal_stage(11) 
    baremetal_stage(12) 
    return 0
}

func main() int {
    baremetal_stage(1) 
    cpu_count := baremetal_logical_cpu_count()
    baremetal_metric(9, cpu_count)
    boot_cycles := baremetal_tsc_cycles()
    baremetal_metric(10, boot_cycles)
    baremetal_stage(14) 
    baremetal_interrupt_init()
    baremetal_tss_init()
    baremetal_stage(2) 
    baremetal_apic_init()
    baremetal_apic_timer_init()
    baremetal_stage(3) 
    memory_mib := baremetal_memory_mib()
    baremetal_metric(0, memory_mib)
    physical_page_allocator_init(memory_mib)
    baremetal_stage(4) 
    baremetal_syscall_init()
    baremetal_stage(5) 
    kernel_services_init()
    baremetal_stage(13) 
    return 0
}
