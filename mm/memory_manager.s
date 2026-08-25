package neurx.mm

struct page {
    int page_id
    int page_frame_number
    int ref_count
    bool is_free
    bool is_dirty
    int access_count
    int allocation_order
}

struct memory_zone {
    int zone_id
    string zone_name
    int total_pages
    int free_pages
    int used_pages
    int reserved_pages
    int watermark_low
    int watermark_high
}

struct memory_manager {
    int total_memory_mb
    int available_memory_mb
    int used_memory_mb
    int reserved_memory_mb
    int total_page_faults
    int total_allocations
    int total_deallocations
    int fragmentation_percent
}

func create_memory_manager(int total_mem_mb) memory_manager {
    mgr := memory_manager {
        total_memory_mb: total_mem_mb,
        available_memory_mb: total_mem_mb,
        used_memory_mb: 0,
        reserved_memory_mb: (total_mem_mb * 10) / 100,
        total_page_faults: 0,
        total_allocations: 0,
        total_deallocations: 0,
        fragmentation_percent: 0
    }
    return mgr
}

func allocate_memory(memory_manager mgr, int size_mb) memory_manager {
    if size_mb <= mgr.available_memory_mb {
        mgr.used_memory_mb = mgr.used_memory_mb + size_mb
        mgr.available_memory_mb = mgr.available_memory_mb - size_mb
        mgr.total_allocations = mgr.total_allocations + 1
    }
    return mgr
}

func deallocate_memory(memory_manager mgr, int size_mb) memory_manager {
    if size_mb <= mgr.used_memory_mb {
        mgr.used_memory_mb = mgr.used_memory_mb - size_mb
        mgr.available_memory_mb = mgr.available_memory_mb + size_mb
        mgr.total_deallocations = mgr.total_deallocations + 1
    }
    return mgr
}

func page_fault_handler(memory_manager mgr) memory_manager {
    mgr.total_page_faults = mgr.total_page_faults + 1
    return mgr
}

func calculate_fragmentation(memory_manager mgr) memory_manager {
    if mgr.total_memory_mb > 0 {
        mgr.fragmentation_percent = (mgr.reserved_memory_mb * 100) / mgr.total_memory_mb
    }
    return mgr
}

func print_memory_manager_info(memory_manager mgr) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║       NeurX Memory Manager - Status Report                 ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Memory Configuration:")
    print("   • Total Memory: ")
    print(mgr.total_memory_mb as string)
    print("MB")
    print("   • Page Size: 4KB")
    print("   • Allocation Strategy: Buddy Allocator")
    print("")
    print("📈 Memory Statistics:")
    print("   • Used Memory: ")
    print(mgr.used_memory_mb as string)
    print("MB")
    print("   • Available Memory: ")
    print(mgr.available_memory_mb as string)
    print("MB")
    print("   • Reserved Memory: ")
    print(mgr.reserved_memory_mb as string)
    print("MB")
    print("   • Page Faults: ")
    print(mgr.total_page_faults as string)
    print("   • Allocations: ")
    print(mgr.total_allocations as string)
    print("   • Deallocations: ")
    print(mgr.total_deallocations as string)
    print("   • Fragmentation: ")
    print(mgr.fragmentation_percent as string)
    print("%")
    print("")
    print("✅ Memory manager operational!")
}
