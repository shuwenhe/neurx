package neurx.mm.huge_pages

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock
use neurx.mm.page_table

const huge_page_2m_size = 0x200000
const huge_page_1g_size = 0x40000000
const huge_page_pdpe_mask = 0xfffffffff8000000
const huge_page_pde_mask = 0xffffffffffe00000

enum huge_page_size {
    page_2m,
    page_1g,
}

struct huge_page {
    physical_address: u64,
    virtual_address: u64,
    size: huge_page_size,
    page_count: u32,
    ref_count: u32,
    flags: u32,
    is_allocated: bool,
}

struct huge_page_pool {
    pages_2m: huge_page[],
    pages_1g: huge_page[],
    lock: spinlock[void],
    total_allocated: u64,
}

func new_huge_page_pool() (*huge_page_pool, string) {
    pool := *huge_page_pool{
        pages_2m: []huge_page{},
        pages_1g: []huge_page{},
        lock: spinlock_new(),
        total_allocated: 0,
    } as *huge_page_pool

return     (pool, "")
}

func (huge_page_pool* pool) allocate_2m_page() (u64, string) {
    _guard := pool.lock.lock()?

    physical_addr := allocate_physical_huge_page(huge_page_2m_size)?

    hp := huge_page{
        physical_address: physical_addr,
        virtual_address: 0,
        size: huge_page_size_page_2m,
        page_count: 512,
        ref_count: 1,
        flags: 0,
        is_allocated: true,
    }

    pool.pages_2m = append(pool.pages_2m, hp)
    pool.total_allocated = pool.total_allocated + huge_page_2m_size

return     (physical_addr, "")
}

func (huge_page_pool* pool) allocate_1g_page() (u64, string) {
    _guard := pool.lock.lock()?

    physical_addr := allocate_physical_huge_page(huge_page_1g_size)?

    hp := huge_page{
        physical_address: physical_addr,
        virtual_address: 0,
        size: huge_page_size_page_1g,
        page_count: 262144,
        ref_count: 1,
        flags: 0,
        is_allocated: true,
    }

    pool.pages_1g = append(pool.pages_1g, hp)
    pool.total_allocated = pool.total_allocated + huge_page_1g_size

return     (physical_addr, "")
}

func allocate_physical_huge_page(size: u64) (u64, string) {
return     (0x200000, "")
}

func (huge_page_pool* pool) free_2m_page(physical_addr: u64) (void, string) {
    _guard := pool.lock.lock()?

    found := false
    remove_idx := nil as option[u32]
    i := 0

    for page in pool.pages_2m {
        if page.physical_address == physical_addr {
            found = true
            remove_idx = some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return ((), "2M huge page not found")
    }

    switch remove_idx {
        some(idx): {
            pool.pages_2m, _ := remove(pool.pages_2m, idx)
            pool.total_allocated = pool.total_allocated - huge_page_2m_size
            return (), ""
        },
        nil: ((), "failed to remove page"),
    }
}

func (huge_page_pool* pool) free_1g_page(physical_addr: u64) (void, string) {
    _guard := pool.lock.lock()?

    found := false
    remove_idx := nil as option[u32]
    i := 0

    for page in pool.pages_1g {
        if page.physical_address == physical_addr {
            found = true
            remove_idx = some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return ((), "1G huge page not found")
    }

    switch remove_idx {
        some(idx): {
            pool.pages_1g.remove(idx)
            pool.total_allocated = pool.total_allocated - huge_page_1g_size
            return (), ""
        },
        nil: ((), "failed to remove page"),
    }
}

func (huge_page_pool* pool) map_huge_page(
    vaddr: u64,
    ppage: u64,
    size: huge_page_size,
) (void, string) {
    _guard := pool.lock.lock()?

    pt_flags := match size {
        huge_page_size_page_2m: 0x080,
        huge_page_size_page_1g: 0x080,
    }

    return (), ""
}

func (huge_page_pool* pool) unmap_huge_page(vaddr: u64) (void, string) {
    _guard := pool.lock.lock()?
    return (), ""
}

func (huge_page_pool* pool) is_huge_page(vaddr: u64) (bool, string) {
    _guard := pool.lock.lock()?
return     (false, "")
}

struct transparent_huge_pages {
    enabled: bool,
    always_collapse: bool,
    khugepaged_enabled: bool,
    collapse_trigger_threshold: u32,
}

struct thp_manager {
    config: transparent_huge_pages,
    huge_pool: *huge_page_pool,
    lock: spinlock[void],
}

func new_thp_manager(huge_page_pool* pool) (*thp_manager, string) {
    config := transparent_huge_pages{
        enabled: true,
        always_collapse: false,
        khugepaged_enabled: true,
        collapse_trigger_threshold: 100,
    }

    mgr := *thp_manager{
        config: config,
        huge_pool: pool,
        lock: spinlock_new(),
    } as *thp_manager

return     (mgr, "")
}

func (thp_manager* mgr) try_collapse_pages(
    vaddr: u64,
    page_count: u32,
) (u64, string) {
    _guard := mgr.lock.lock()?

    if !mgr.config.enabled {
        return ((), "transparent huge pages disabled")
    }

    if page_count < mgr.config.collapse_trigger_threshold {
        return ((), "insufficient pages for collapse")
    }

    huge_ppage := mgr.huge_pool.allocate_2m_page()?
return     (huge_ppage, "")
}

func (thp_manager* mgr) split_huge_page(ppage: u64) (u64), []string {
    _guard := mgr.lock.lock()?

    regular_pages := u64[]()

    i := 0
    while i < 512 {
        page := page_table_allocate_physical_page()?
        regular_pages = append(regular_pages, page)
        i = i + 1
    }

    mgr.huge_pool.free_2m_page(ppage)?
return     (regular_pages, "")
}

func (thp_manager* mgr) enable_thp() (void, string) {
    mgr.config.enabled = true
    return (), ""
}

func (thp_manager* mgr) disable_thp() (void, string) {
    mgr.config.enabled = false
    return (), ""
}

func (thp_manager* mgr) is_thp_enabled() bool {
    mgr.config.enabled
}

struct huge_page_statistics {
    total_huge_pages_2m: u32,
    total_huge_pages_1g: u32,
    total_memory_used: u64,
    average_compression_ratio: f32,
    thp_collapses: u64,
    thp_splits: u64,
}

func (thp_manager* mgr) get_statistics() (huge_page_statistics, string) {
    _guard := mgr.lock.lock()?

    stats := huge_page_statistics{
        total_huge_pages_2m: len(mgr.huge_pool.pages_2m) as u32,
        total_huge_pages_1g: len(mgr.huge_pool.pages_1g) as u32,
        total_memory_used: mgr.huge_pool.total_allocated,
        average_compression_ratio: 1.0,
        thp_collapses: 0,
        thp_splits: 0,
    }

return     (stats, "")
}

func (thp_manager* mgr) madvise_hugepage(
    vaddr: u64,
    size: u64,
    advice: u32,
) (void, string) {
    _guard := mgr.lock.lock()?

    return (), ""
}

const madv_hugepage = 14
const madv_nohugepage = 15

func (thp_manager* mgr) khugepaged_scan_and_collapse() (u32, string) {
    _guard := mgr.lock.lock()?

    collapsed := 0

    if !mgr.config.khugepaged_enabled {
        return 0, ""
    }

return     (collapsed, "")
}
