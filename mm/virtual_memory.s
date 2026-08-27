package neurx.mm.virtual_memory

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.mutex
use neurx.kernel.locking.spinlock
use neurx.mm.page_table
use neurx.mm.memory_manager

struct virtual_address_space {
    vm_areas: vm_area[],
    page_table_root: *page_table::page_table,
    fault_handler: *fn(vaddr: u64, is_write: bool) -> result[void, string],
    lock: mutex::mutex[void],
}

struct vm_area {
    vm_start: u64,
    vm_end: u64,
    vm_flags: u32,
    backing_store: option[backing_file],
    page_cache: u64[],
    protection: prot_flags,
    merge_prev: option[*vm_area],
    merge_next: option[*vm_area],
}

struct backing_file {
    file_offset: u64,
    file_size: u64,
    page_in_handler: *fn(vpage: u64, offset: u64) -> result[void, string],
    page_out_handler: *fn(vpage: u64, offset: u64, dirty: bool) -> result[void, string],
}

enum prot_flags {
    prot_read,
    prot_write,
    prot_exec,
    prot_none,
}

enum vm_flags {
    vm_read = 1,
    vm_write = 2,
    vm_exec = 4,
    vm_shared = 8,
    vm_private = 16,
    vm_growsdown = 32,
    vm_growsup = 64,
    vm_cow = 128,
    vm_locked = 256,
    vm_io = 512,
}

func new_virtual_address_space(page_table* page_table_root::page_table) (*virtual_address_space, string) {
    vas := *virtual_address_space{
        vm_areas: vm_area[](),
        page_table_root: page_table_root,
        lock: mutex::new(),
        fault_handler: *default_fault_handler,
    } as *virtual_address_space

return     (vas, "")
}

func default_fault_handler(vaddr: u64, is_write: bool) (void, string) {
    ((), "default handler - not implemented")
}

func (virtual_address_space* vas) map_vma(
    start: u64,
    size: u64,
    flags: u32,
    backing: option[backing_file],
) (void, string) {
    _guard := vas.lock.lock()?

    if size == 0 {
        return ((), "vma size cannot be zero")
    }

    end := start + size
    overlap_check := false
    
    for area in vas.vm_areas {
        if (start < area.vm_end) && (end > area.vm_start) {
            overlap_check = true
            break
        }
    }

    if overlap_check {
        return ((), "vma overlaps with existing area")
    }

    vma := vm_area{
        vm_start: start,
        vm_end: end,
        vm_flags: flags,
        backing_store: backing,
        page_cache: u64[](),
        protection: decode_prot_flags(flags),
        merge_prev: option::none,
        merge_next: option::none,
    }

    vas.vm_areas = append(vas.vm_areas, vma)
    return (), ""
}

func decode_prot_flags(flags: u32) prot_flags {
    has_write := (flags & (vm_flags::vm_write as u32)) != 0
    has_exec := (flags & (vm_flags::vm_exec as u32)) != 0
    
    switch (has_write, has_exec) {
        (true, true): prot_flags::prot_write,
        (true, false): prot_flags::prot_write,
        (false, true): prot_flags::prot_exec,
        (false, false): prot_flags::prot_read,
    }
}

func (virtual_address_space* vas) handle_page_fault(
    vaddr: u64,
    is_write: bool,
) (void, string) {
    _guard := vas.lock.lock()?

    found_vma := option::none as option[*vm_area]
    
    for area in vas.vm_areas {
        if (vaddr >= area.vm_start) && (vaddr < area.vm_end) {
            found_vma = option::some(*area)
            break
        }
    }

    switch found_vma {
        option::some(vma): {
            check_write := (vma.vm_flags & (vm_flags::vm_write as u32)) != 0
            
            if is_write && !check_write {
                return ((), "write fault on read-only vma")
            }

            fault_in_page(vas, vma, vaddr, is_write)?
            return (), ""
        },
        option::none: ((), "segmentation fault - no vma found"),
    }
}

func fault_in_page(
    vas: *virtual_address_space,
    vma: *vm_area,
    vaddr: u64,
    is_write: bool,
) (void, string) {
    page_offset := vaddr - vma.vm_start
    ppage := page_table::allocate_physical_page()?

    switch vma.backing_store {
        option::some(backing): {
            handler := backing.page_in_handler
            handler(ppage, page_offset)?
            page_table::set_page_mapping(vas.page_table_root, vaddr, ppage, is_write)?
            return (), ""
        },
        option::none: {
            page_table::zero_page(ppage)?
            page_table::set_page_mapping(vas.page_table_root, vaddr, ppage, is_write)?
            return (), ""
        },
    }
}

func (virtual_address_space* vas) unmap_vma(start: u64) (void, string) {
    _guard := vas.lock.lock()?

    remove_idx := option::none as option[u32]
    
    i := 0
    for area in vas.vm_areas {
        if area.vm_start == start {
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    switch remove_idx {
        option::some(idx): {
            idx_usize := idx as u32
            removed := vas.vm_areas.remove(idx_usize as u32)
            return (), ""
        },
        option::none: ((), "vma not found for unmap"),
    }
}

func (virtual_address_space* vas) find_vma(vaddr: u64) option[*vm_area] {
    for area in vas.vm_areas {
        if (vaddr >= area.vm_start) && (vaddr < area.vm_end) {
            return option::some(*area)
        }
    }
    option::none
}

func (virtual_address_space* vas) expand_vma_down(
    vma_start: u64,
    new_start: u64,
) (void, string) {
    _guard := vas.lock.lock()?

    if new_start >= vma_start {
        return ((), "cannot expand down - invalid range")
    }

    for area in vas.vm_areas {
        if (area.vm_start == vma_start) && (area.vm_flags & (vm_flags::vm_growsdown as u32) != 0) {
            if (new_start >= area.vm_end) {
                return ((), "overlaps with next vma")
            }
            area.vm_start = new_start
            return return (), ""
        }
    }

    ((), "vma not found or cannot grow")
}

func (virtual_address_space* vas) merge_vmas(vma1_start: u64, vma2_start: u64) (void, string) {
    _guard := vas.lock.lock()?

    vma1_idx := option::none as option[u32]
    vma2_idx := option::none as option[u32]

    i := 0
    for area in vas.vm_areas {
        if area.vm_start == vma1_start {
            vma1_idx = option::some(i)
        }
        if area.vm_start == vma2_start {
            vma2_idx = option::some(i)
        }
        i = i + 1
    }

    switch (vma1_idx, vma2_idx) {
        (option::some(idx1), option::some(idx2)): {
            if idx2 != idx1 + 1 {
                return ((), "vmas not adjacent")
            }
            return (), ""
        },
        _: ((), "one or both vmas not found"),
    }
}

struct page_reclaim_stats {
    pages_scanned: u64,
    pages_freed: u64,
    pages_written_back: u64,
}

func (virtual_address_space* vas) reclaim_pages(target_pages: u64) (page_reclaim_stats, string) {
    _guard := vas.lock.lock()?

    stats := page_reclaim_stats{
        pages_scanned: 0,
        pages_freed: 0,
        pages_written_back: 0,
    }

    for vma in vas.vm_areas {
        if (vma.vm_flags & (vm_flags::vm_locked as u32)) != 0 {
            continue
        }

        for page_idx in range(0, len(vma.page_cache)) {
            if stats.pages_freed >= target_pages {
                break
            }

            stats.pages_scanned = stats.pages_scanned + 1

            page_addr := vma.page_cache.get(page_idx as u32) as u64
            is_dirty := page_table::is_page_dirty(page_addr)?

            if is_dirty {
                switch vma.backing_store {
                    option::some(backing): {
                        handler := backing.page_out_handler
                        handler(page_addr, page_idx as u64, true)?
                        stats.pages_written_back = stats.pages_written_back + 1
                    },
                    option::none: {},
                }
            }

            page_table::free_physical_page(page_addr)?
            stats.pages_freed = stats.pages_freed + 1
        }
    }

return     (stats, "")
}

func range(start: u32, end: u32) u32[] {
    result := u32[]()
    i := start
    while i < end {
        result = append(result, i)
        i = i + 1
    }
    result
}
