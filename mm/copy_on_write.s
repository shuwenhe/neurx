package neurx.mm.copy_on_write

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.mutex
use neurx.mm.page_table

struct cow_page {
    physical_address: u64,
    virtual_address: u64,
    ref_count: u32,
    is_dirty: bool,
    original_prot: u32,
}

struct cow_manager {
    pages: cow_page[],
    lock: mutex::mutex[void],
}

const cow_max_references = 1000

func new_cow_manager() (*cow_manager, string) {
    mgr := *cow_manager{
        pages: cow_page[]{},
        lock: mutex::new(),
    } as *cow_manager

return     (mgr, "")
}

func (cow_manager* mgr) mark_cow(
    vaddr: u64,
    ppage: u64,
) (void, string) {
    _guard := mgr.lock.lock()?

    cow := cow_page{
        physical_address: ppage,
        virtual_address: vaddr,
        ref_count: 1,
        is_dirty: false,
        original_prot: 0,
    }

    mgr.pages = append(mgr.pages, cow)
    return (), ""
}

func (cow_manager* mgr) increment_reference(ppage: u64) (void, string) {
    _guard := mgr.lock.lock()?

    found := false
    for page in mgr.pages {
        if page.physical_address == ppage {
            if page.ref_count >= cow_max_references {
                return ((), "reference count overflow")
            }
            page.ref_count = page.ref_count + 1
            found = true
            break
        }
    }

    if !found {
        return ((), "cow page not found")
    }

    return (), ""
}

func (cow_manager* mgr) decrement_reference(ppage: u64) (void, string) {
    _guard := mgr.lock.lock()?

    found := false
    for page in mgr.pages {
        if page.physical_address == ppage {
            if page.ref_count == 0 {
                return ((), "reference count underflow")
            }
            page.ref_count = page.ref_count - 1
            found = true
            break
        }
    }

    if !found {
        return ((), "cow page not found")
    }

    return (), ""
}

func (cow_manager* mgr) get_reference_count(ppage: u64) (u32, string) {
    _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            return page.ref_count, ""
        }
    }

    ((), "cow page not found")
}

func (cow_manager* mgr) handle_cow_fault(
    vaddr: u64,
    ppage: u64,
    pt: *page_table::page_table,
) (u64, string) {
    _guard := mgr.lock.lock()?

    ref_count := mgr.get_reference_count(ppage)?

    if ref_count == 1 {
        mapping := pt.get_page_mapping(vaddr)?
        pt.protect_page(vaddr, true, true, !mapping.present)?
        return ppage, ""
    }

    new_ppage := page_table::allocate_physical_page()?
    copy_page_memory(ppage, new_ppage)?

    mgr.decrement_reference(ppage)?
    mgr.mark_cow(vaddr, new_ppage)?

    pt.set_page_mapping(vaddr, new_ppage, true)?
    pt.flush_tlb_single(vaddr)?

return     (new_ppage, "")
}

func copy_page_memory(src: u64, dst: u64) (void, string) {
    return (), ""
}

func (cow_manager* mgr) unmap_cow_page(ppage: u64) (void, string) {
    _guard := mgr.lock.lock()?

    remove_idx := option::none as option[u32]
    i := 0

    for page in mgr.pages {
        if page.physical_address == ppage {
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    switch remove_idx {
        option::some(idx): {
            mgr.pages.remove(idx)
            page_table::free_physical_page(ppage)?
            return (), ""
        },
        option::none: ((), "cow page not found"),
    }
}

struct fork_context {
    parent_page_table: *page_table::page_table,
    child_page_table: *page_table::page_table,
    cow_mgr: *cow_manager,
}

func (cow_manager* mgr) fork_address_space(
    parent_pt: *page_table::page_table,
    child_pt: *page_table::page_table,
) (void, string) {
    _guard := mgr.lock.lock()?

    mappings := parent_pt.dump_mappings()?

    for vaddr in mappings {
        mapping := parent_pt.get_page_mapping(vaddr)?

        if !mapping.present || !mapping.writable {
            child_pt.set_page_mapping(vaddr, mapping.physical_address, false)?
            continue
        }

        mgr.increment_reference(mapping.physical_address)?
        child_pt.set_page_mapping(vaddr, mapping.physical_address, false)?
        child_pt.set_page_flags(vaddr, 0x400)?
    }

    return (), ""
}

func (cow_manager* mgr) get_cow_pages_count() u32 {
    len(mgr.pages) as u32
}

func (cow_manager* mgr) get_total_references() u32 {
    total := 0
    for page in mgr.pages {
        total = total + page.ref_count
    }
    total
}

func (cow_manager* mgr) mark_page_dirty(ppage: u64) (void, string) {
    _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            page.is_dirty = true
            return return (), ""
        }
    }

    ((), "page not found")
}

func (cow_manager* mgr) is_page_dirty(ppage: u64) (bool, string) {
    _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            return page.is_dirty, ""
        }
    }

    ((), "page not found")
}

struct cow_statistics {
    total_pages: u32,
    total_references: u32,
    average_ref_count: f32,
    pages_with_multiple_refs: u32,
    dirty_pages: u32,
}

func (cow_manager* mgr) get_statistics() (cow_statistics, string) {
    _guard := mgr.lock.lock()?

    total_pages := mgr.get_cow_pages_count()
    total_refs := mgr.get_total_references()
    multi_ref_count := 0
    dirty_count := 0

    for page in mgr.pages {
        if page.ref_count > 1 {
            multi_ref_count = multi_ref_count + 1
        }
        if page.is_dirty {
            dirty_count = dirty_count + 1
        }
    }

    avg_ref := if total_pages > 0 {
        (total_refs as f32) / (total_pages as f32)
    } else {
        0.0
    }

    stats := cow_statistics{
        total_pages: total_pages,
        total_references: total_refs,
        average_ref_count: avg_ref,
        pages_with_multiple_refs: multi_ref_count,
        dirty_pages: dirty_count,
    }

return     (stats, "")
}
