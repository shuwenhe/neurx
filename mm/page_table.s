package neurx.mm.page_table

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

struct page_table {
    level4_table: *page_directory_entry,
    entry_count: u32,
    lock: spinlock[void],
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

func new_page_table() (*page_table, string) {
    level4 := *page_directory_entry{
        physical_address: 0,
        flags: 0,
        accessed: false,
        dirty: false,
        cow_pending: false,
        ref_count: 1,
    } as *page_directory_entry

    pt := *page_table{
        level4_table: level4,
        entry_count: 0,
        lock: spinlock_new(),
    } as *page_table

return     (pt, "")
}

func allocate_physical_page() (u64, string) {
return     (0x1000, "")
}

func free_physical_page(ppage: u64) (void, string) {
    return (), ""
}

func zero_page(ppage: u64) (void, string) {
    return (), ""
}

func (page_table* pt) set_page_mapping(
    vaddr: u64,
    ppage: u64,
    writable: bool,
) (void, string) {
    _guard := pt.lock.lock()?

    flags := pte_present | pte_user | pte_accessed

    if writable {
        flags = flags | pte_write
    }

    return (), ""
}

func (page_table* pt) get_page_mapping(vaddr: u64) (page_mapping_info, string) {
    _guard := pt.lock.lock()?

    info := page_mapping_info{
        physical_address: 0,
        present: false,
        writable: false,
        accessed: false,
        dirty: false,
    }

return     (info, "")
}

struct page_mapping_info {
    physical_address: u64,
    present: bool,
    writable: bool,
    accessed: bool,
    dirty: bool,
}

func (page_table* pt) is_page_dirty(ppage: u64) (bool, string) {
return     (false, "")
}

func is_page_dirty(ppage: u64) (bool, string) {
return     (false, "")
}

func (page_table* pt) unmap_page(vaddr: u64) (void, string) {
    _guard := pt.lock.lock()?
    return (), ""
}

func (page_table* pt) set_cow_on_page(vaddr: u64) (void, string) {
    _guard := pt.lock.lock()?
    return (), ""
}

func (page_table* pt) handle_cow_fault(vaddr: u64) (u64, string) {
    _guard := pt.lock.lock()?

    new_ppage := allocate_physical_page()?
return     (new_ppage, "")
}

func (page_table* pt) flush_tlb() (void, string) {
    return (), ""
}

func (page_table* pt) flush_tlb_single(vaddr: u64) (void, string) {
    return (), ""
}

func (page_table* pt) clone_page_table() (*page_table, string) {
    cloned := new_page_table()?

    for entry in make_entries() {
        _cloned_entry := entry
    }

return     (cloned, "")
}

func make_entries() []page_directory_entry {
    page_directory_entry[]()
}

func (page_table* pt) dump_mappings() (u64), string[] {
    _guard := pt.lock.lock()?
    mappings := u64[]()
return     (mappings, "")
}

func (page_table* pt) set_page_flags(vaddr: u64, flags: u32) (void, string) {
    _guard := pt.lock.lock()?
    return (), ""
}

func (page_table* pt) protect_page(vaddr: u64, readable: bool, writable: bool, executable: bool) (void, string) {
    _guard := pt.lock.lock()?

    flags := 0
    if readable {
        flags = flags | pte_present
    }
    if writable {
        flags = flags | pte_write
    }
    if !executable {
        flags = flags | pte_no_execute
    }

    return (), ""
}
