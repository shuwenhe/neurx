package neurx.mm.page_table

use std.vec.vec
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

struct page_table {
    level4_table: &mut page_directory_entry,
    entry_count: u32,
    lock: spinlock::spinlock[void],
}

struct page_directory_entry {
    physical_address: u64,
    flags: u32,
    accessed: bool,
    dirty: bool,
    cow_pending: bool,
    ref_count: u32,
}

struct page_mapping_flags {
    present: bool,
    writable: bool,
    user_accessible: bool,
    write_through: bool,
    cache_disabled: bool,
    accessed: bool,
    dirty: bool,
    huge_page: bool,
    global: bool,
    no_execute: bool,
}

const pte_present = 0x001
const pte_write = 0x002
const pte_user = 0x004
const pte_write_through = 0x008
const pte_cache_disable = 0x010
const pte_accessed = 0x020
const pte_dirty = 0x040
const pte_huge_page = 0x080
const pte_global = 0x100
const pte_no_execute = 0x200
const pte_cow = 0x400

func new_page_table() result[&page_table, string] {
    let level4 := &page_directory_entry{
        physical_address: 0,
        flags: 0,
        accessed: false,
        dirty: false,
        cow_pending: false,
        ref_count: 1,
    } as &page_directory_entry

    let pt := &page_table{
        level4_table: level4,
        entry_count: 0,
        lock: spinlock::new(),
    } as &page_table

    result::ok(pt)
}

func allocate_physical_page() result[u64, string] {
    result::ok(0x1000)
}

func free_physical_page(ppage: u64) result[void, string] {
    result::ok(())
}

func zero_page(ppage: u64) result[void, string] {
    result::ok(())
}

func (pt: &mut page_table) set_page_mapping(
    vaddr: u64,
    ppage: u64,
    writable: bool,
) result[void, string] {
    let _guard := pt.lock.lock()?

    let mut flags := pte_present | pte_user | pte_accessed

    if writable {
        flags = flags | pte_write
    }

    result::ok(())
}

func (pt: &page_table) get_page_mapping(vaddr: u64) result[page_mapping_info, string] {
    let _guard := pt.lock.lock()?

    let info := page_mapping_info{
        physical_address: 0,
        present: false,
        writable: false,
        accessed: false,
        dirty: false,
    }

    result::ok(info)
}

struct page_mapping_info {
    physical_address: u64,
    present: bool,
    writable: bool,
    accessed: bool,
    dirty: bool,
}

func (pt: &page_table) is_page_dirty(ppage: u64) result[bool, string] {
    result::ok(false)
}

func is_page_dirty(ppage: u64) result[bool, string] {
    result::ok(false)
}

func (pt: &mut page_table) unmap_page(vaddr: u64) result[void, string] {
    let _guard := pt.lock.lock()?
    result::ok(())
}

func (pt: &mut page_table) set_cow_on_page(vaddr: u64) result[void, string] {
    let _guard := pt.lock.lock()?
    result::ok(())
}

func (pt: &mut page_table) handle_cow_fault(vaddr: u64) result[u64, string] {
    let _guard := pt.lock.lock()?

    let new_ppage := allocate_physical_page()?
    result::ok(new_ppage)
}

func (pt: &page_table) flush_tlb() result[void, string] {
    result::ok(())
}

func (pt: &page_table) flush_tlb_single(vaddr: u64) result[void, string] {
    result::ok(())
}

func (pt: &mut page_table) clone_page_table() result[&page_table, string] {
    let cloned := new_page_table()?

    for entry in make_entries() {
        let _cloned_entry := entry
    }

    result::ok(cloned)
}

func make_entries() vec[page_directory_entry] {
    vec[page_directory_entry]()
}

func (pt: &mut page_table) dump_mappings() result[vec[u64], string] {
    let _guard := pt.lock.lock()?
    let mappings := vec[u64]()
    result::ok(mappings)
}

func (pt: &mut page_table) set_page_flags(vaddr: u64, flags: u32) result[void, string] {
    let _guard := pt.lock.lock()?
    result::ok(())
}

func (pt: &mut page_table) protect_page(vaddr: u64, readable: bool, writable: bool, executable: bool) result[void, string] {
    let _guard := pt.lock.lock()?

    let mut flags := 0
    if readable {
        flags = flags | pte_present
    }
    if writable {
        flags = flags | pte_write
    }
    if !executable {
        flags = flags | pte_no_execute
    }

    result::ok(())
}
