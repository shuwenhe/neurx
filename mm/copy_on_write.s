package neurx.mm.copy_on_write

use std.vec.vec
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
    pages: vec[cow_page],
    lock: mutex::mutex[void],
}

const cow_max_references = 1000

func new_cow_manager() result[&cow_manager, string] {
    let mgr := &cow_manager{
        pages: vec[cow_page](),
        lock: mutex::new(),
    } as &cow_manager

    result::ok(mgr)
}

func (mgr: &mut cow_manager) mark_cow(
    vaddr: u64,
    ppage: u64,
) result[void, string] {
    let _guard := mgr.lock.lock()?

    let cow := cow_page{
        physical_address: ppage,
        virtual_address: vaddr,
        ref_count: 1,
        is_dirty: false,
        original_prot: 0,
    }

    mgr.pages.push(cow)
    result::ok(())
}

func (mgr: &mut cow_manager) increment_reference(ppage: u64) result[void, string] {
    let _guard := mgr.lock.lock()?

    let mut found := false
    for page in mgr.pages {
        if page.physical_address == ppage {
            if page.ref_count >= cow_max_references {
                return result::err("reference count overflow")
            }
            page.ref_count = page.ref_count + 1
            found = true
            break
        }
    }

    if !found {
        return result::err("cow page not found")
    }

    result::ok(())
}

func (mgr: &mut cow_manager) decrement_reference(ppage: u64) result[void, string] {
    let _guard := mgr.lock.lock()?

    let mut found := false
    for page in mgr.pages {
        if page.physical_address == ppage {
            if page.ref_count == 0 {
                return result::err("reference count underflow")
            }
            page.ref_count = page.ref_count - 1
            found = true
            break
        }
    }

    if !found {
        return result::err("cow page not found")
    }

    result::ok(())
}

func (mgr: &mut cow_manager) get_reference_count(ppage: u64) result[u32, string] {
    let _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            return result::ok(page.ref_count)
        }
    }

    result::err("cow page not found")
}

func (mgr: &mut cow_manager) handle_cow_fault(
    vaddr: u64,
    ppage: u64,
    pt: &mut page_table::page_table,
) result[u64, string] {
    let _guard := mgr.lock.lock()?

    let ref_count := mgr.get_reference_count(ppage)?

    if ref_count == 1 {
        let mapping := pt.get_page_mapping(vaddr)?
        pt.protect_page(vaddr, true, true, !mapping.present)?
        return result::ok(ppage)
    }

    let new_ppage := page_table::allocate_physical_page()?
    copy_page_memory(ppage, new_ppage)?

    mgr.decrement_reference(ppage)?
    mgr.mark_cow(vaddr, new_ppage)?

    pt.set_page_mapping(vaddr, new_ppage, true)?
    pt.flush_tlb_single(vaddr)?

    result::ok(new_ppage)
}

func copy_page_memory(src: u64, dst: u64) result[void, string] {
    result::ok(())
}

func (mgr: &mut cow_manager) unmap_cow_page(ppage: u64) result[void, string] {
    let _guard := mgr.lock.lock()?

    let mut remove_idx := option::none as option[u32]
    let mut i := 0

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
            result::ok(())
        },
        option::none: result::err("cow page not found"),
    }
}

struct fork_context {
    parent_page_table: &page_table::page_table,
    child_page_table: &mut page_table::page_table,
    cow_mgr: &mut cow_manager,
}

func (mgr: &mut cow_manager) fork_address_space(
    parent_pt: &page_table::page_table,
    child_pt: &mut page_table::page_table,
) result[void, string] {
    let _guard := mgr.lock.lock()?

    let mappings := parent_pt.dump_mappings()?

    for vaddr in mappings {
        let mapping := parent_pt.get_page_mapping(vaddr)?

        if !mapping.present || !mapping.writable {
            child_pt.set_page_mapping(vaddr, mapping.physical_address, false)?
            continue
        }

        mgr.increment_reference(mapping.physical_address)?
        child_pt.set_page_mapping(vaddr, mapping.physical_address, false)?
        child_pt.set_page_flags(vaddr, 0x400)?
    }

    result::ok(())
}

func (mgr: &mut cow_manager) get_cow_pages_count() u32 {
    mgr.pages.len() as u32
}

func (mgr: &mut cow_manager) get_total_references() u32 {
    let mut total := 0
    for page in mgr.pages {
        total = total + page.ref_count
    }
    total
}

func (mgr: &mut cow_manager) mark_page_dirty(ppage: u64) result[void, string] {
    let _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            page.is_dirty = true
            return result::ok(())
        }
    }

    result::err("page not found")
}

func (mgr: &mut cow_manager) is_page_dirty(ppage: u64) result[bool, string] {
    let _guard := mgr.lock.lock()?

    for page in mgr.pages {
        if page.physical_address == ppage {
            return result::ok(page.is_dirty)
        }
    }

    result::err("page not found")
}

struct cow_statistics {
    total_pages: u32,
    total_references: u32,
    average_ref_count: f32,
    pages_with_multiple_refs: u32,
    dirty_pages: u32,
}

func (mgr: &mut cow_manager) get_statistics() result[cow_statistics, string] {
    let _guard := mgr.lock.lock()?

    let total_pages := mgr.get_cow_pages_count()
    let total_refs := mgr.get_total_references()
    let mut multi_ref_count := 0
    let mut dirty_count := 0

    for page in mgr.pages {
        if page.ref_count > 1 {
            multi_ref_count = multi_ref_count + 1
        }
        if page.is_dirty {
            dirty_count = dirty_count + 1
        }
    }

    let avg_ref := if total_pages > 0 {
        (total_refs as f32) / (total_pages as f32)
    } else {
        0.0
    }

    let stats := cow_statistics{
        total_pages: total_pages,
        total_references: total_refs,
        average_ref_count: avg_ref,
        pages_with_multiple_refs: multi_ref_count,
        dirty_pages: dirty_count,
    }

    result::ok(stats)
}
