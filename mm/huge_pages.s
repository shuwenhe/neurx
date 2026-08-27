package neurx.mm.huge_pages

use std.vec.vec
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
    pages_2m: vec[huge_page],
    pages_1g: vec[huge_page],
    lock: spinlock::spinlock[void],
    total_allocated: u64,
}

func new_huge_page_pool() result[&huge_page_pool, string] {
    let pool := &huge_page_pool{
        pages_2m: vec[huge_page](),
        pages_1g: vec[huge_page](),
        lock: spinlock::new(),
        total_allocated: 0,
    } as &huge_page_pool

    result::ok(pool)
}

func (pool: &mut huge_page_pool) allocate_2m_page() result[u64, string] {
    let _guard := pool.lock.lock()?

    let physical_addr := allocate_physical_huge_page(huge_page_2m_size)?

    let hp := huge_page{
        physical_address: physical_addr,
        virtual_address: 0,
        size: huge_page_size::page_2m,
        page_count: 512,
        ref_count: 1,
        flags: 0,
        is_allocated: true,
    }

    pool.pages_2m.push(hp)
    pool.total_allocated = pool.total_allocated + huge_page_2m_size

    result::ok(physical_addr)
}

func (pool: &mut huge_page_pool) allocate_1g_page() result[u64, string] {
    let _guard := pool.lock.lock()?

    let physical_addr := allocate_physical_huge_page(huge_page_1g_size)?

    let hp := huge_page{
        physical_address: physical_addr,
        virtual_address: 0,
        size: huge_page_size::page_1g,
        page_count: 262144,
        ref_count: 1,
        flags: 0,
        is_allocated: true,
    }

    pool.pages_1g.push(hp)
    pool.total_allocated = pool.total_allocated + huge_page_1g_size

    result::ok(physical_addr)
}

func allocate_physical_huge_page(size: u64) result[u64, string] {
    result::ok(0x200000)
}

func (pool: &mut huge_page_pool) free_2m_page(physical_addr: u64) result[void, string] {
    let _guard := pool.lock.lock()?

    let mut found := false
    let mut remove_idx := option::none as option[u32]
    let mut i := 0

    for page in pool.pages_2m {
        if page.physical_address == physical_addr {
            found = true
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return result::err("2M huge page not found")
    }

    switch remove_idx {
        option::some(idx): {
            pool.pages_2m.remove(idx)
            pool.total_allocated = pool.total_allocated - huge_page_2m_size
            result::ok(())
        },
        option::none: result::err("failed to remove page"),
    }
}

func (pool: &mut huge_page_pool) free_1g_page(physical_addr: u64) result[void, string] {
    let _guard := pool.lock.lock()?

    let mut found := false
    let mut remove_idx := option::none as option[u32]
    let mut i := 0

    for page in pool.pages_1g {
        if page.physical_address == physical_addr {
            found = true
            remove_idx = option::some(i)
            break
        }
        i = i + 1
    }

    if !found {
        return result::err("1G huge page not found")
    }

    switch remove_idx {
        option::some(idx): {
            pool.pages_1g.remove(idx)
            pool.total_allocated = pool.total_allocated - huge_page_1g_size
            result::ok(())
        },
        option::none: result::err("failed to remove page"),
    }
}

func (pool: &mut huge_page_pool) map_huge_page(
    vaddr: u64,
    ppage: u64,
    size: huge_page_size,
) result[void, string] {
    let _guard := pool.lock.lock()?

    let pt_flags := match size {
        huge_page_size::page_2m: 0x080,
        huge_page_size::page_1g: 0x080,
    }

    result::ok(())
}

func (pool: &mut huge_page_pool) unmap_huge_page(vaddr: u64) result[void, string] {
    let _guard := pool.lock.lock()?
    result::ok(())
}

func (pool: &huge_page_pool) is_huge_page(vaddr: u64) result[bool, string] {
    let _guard := pool.lock.lock()?
    result::ok(false)
}

struct transparent_huge_pages {
    enabled: bool,
    always_collapse: bool,
    khugepaged_enabled: bool,
    collapse_trigger_threshold: u32,
}

struct thp_manager {
    config: transparent_huge_pages,
    huge_pool: &huge_page_pool,
    lock: spinlock::spinlock[void],
}

func new_thp_manager(pool: &huge_page_pool) result[&thp_manager, string] {
    let config := transparent_huge_pages{
        enabled: true,
        always_collapse: false,
        khugepaged_enabled: true,
        collapse_trigger_threshold: 100,
    }

    let mgr := &thp_manager{
        config: config,
        huge_pool: pool,
        lock: spinlock::new(),
    } as &thp_manager

    result::ok(mgr)
}

func (mgr: &mut thp_manager) try_collapse_pages(
    vaddr: u64,
    page_count: u32,
) result[u64, string] {
    let _guard := mgr.lock.lock()?

    if !mgr.config.enabled {
        return result::err("transparent huge pages disabled")
    }

    if page_count < mgr.config.collapse_trigger_threshold {
        return result::err("insufficient pages for collapse")
    }

    let huge_ppage := mgr.huge_pool.allocate_2m_page()?
    result::ok(huge_ppage)
}

func (mgr: &mut thp_manager) split_huge_page(ppage: u64) result[vec[u64], string] {
    let _guard := mgr.lock.lock()?

    let mut regular_pages := vec[u64]()

    let mut i := 0
    while i < 512 {
        let page := page_table::allocate_physical_page()?
        regular_pages.push(page)
        i = i + 1
    }

    mgr.huge_pool.free_2m_page(ppage)?
    result::ok(regular_pages)
}

func (mgr: &thp_manager) enable_thp() result[void, string] {
    mgr.config.enabled = true
    result::ok(())
}

func (mgr: &thp_manager) disable_thp() result[void, string] {
    mgr.config.enabled = false
    result::ok(())
}

func (mgr: &thp_manager) is_thp_enabled() bool {
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

func (mgr: &mut thp_manager) get_statistics() result[huge_page_statistics, string] {
    let _guard := mgr.lock.lock()?

    let stats := huge_page_statistics{
        total_huge_pages_2m: mgr.huge_pool.pages_2m.len() as u32,
        total_huge_pages_1g: mgr.huge_pool.pages_1g.len() as u32,
        total_memory_used: mgr.huge_pool.total_allocated,
        average_compression_ratio: 1.0,
        thp_collapses: 0,
        thp_splits: 0,
    }

    result::ok(stats)
}

func (mgr: &mut thp_manager) madvise_hugepage(
    vaddr: u64,
    size: u64,
    advice: u32,
) result[void, string] {
    let _guard := mgr.lock.lock()?

    result::ok(())
}

const madv_hugepage = 14
const madv_nohugepage = 15

func (mgr: &mut thp_manager) khugepaged_scan_and_collapse() result[u32, string] {
    let _guard := mgr.lock.lock()?

    let mut collapsed := 0

    if !mgr.config.khugepaged_enabled {
        return result::ok(0)
    }

    result::ok(collapsed)
}
