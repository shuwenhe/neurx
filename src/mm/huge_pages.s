package neurx.mm

use std.slices

struct huge_page {
    int base_address
    int size  
    bool free
    int pool_index
}

struct huge_pages_pool {
    huge_page[] pages_2mb
    huge_page[] pages_1gb
    int total_2mb
    int total_1gb
}

func (huge_pages_pool* hpool) init(int pages_2mb_count, int pages_1gb_count) (int, string) {
    hpool.pages_2mb = {}
    hpool.pages_1gb = {}
    hpool.total_2mb = pages_2mb_count
    hpool.total_1gb = pages_1gb_count
    
    i := 0
    for i < pages_2mb_count {
        page := huge_page{
            base_address: 0x200000 + i * 2097152,
            size: 2097152,
            free: true,
            i pool_index
        }
        hpool.pages_2mb = append(hpool.pages_2mb, page)
        i = i + 1
    }
    
    j := 0
    for j < pages_1gb_count {
        page := huge_page{
            base_address: 0x40000000 + j * 1073741824,
            size: 1073741824,
            free: true,
            j pool_index
        }
        hpool.pages_1gb = append(hpool.pages_1gb, page)
        j = j + 1
    }
    
    return 0, ""
}

func (huge_pages_pool* hpool) allocate_2mb() (huge_page, string) {
    i := 0
    for i < len(hpool.pages_2mb) {
        page := hpool.pages_2mb[i]
        if page.free {
            page.free = false
            hpool.pages_2mb[i] = page
            return page, ""
        }
        i = i + 1
    }
    return huge_page{}, "No free 2MB huge pages"
}

func (huge_pages_pool* hpool) allocate_1gb() (huge_page, string) {
    i := 0
    for i < len(hpool.pages_1gb) {
        page := hpool.pages_1gb[i]
        if page.free {
            page.free = false
            hpool.pages_1gb[i] = page
            return page, ""
        }
        i = i + 1
    }
    return huge_page{}, "No free 1GB huge pages"
}

func (huge_pages_pool* hpool) free_page(huge_page hp) (int, string) {
    if hp.size == 2097152 {
        i := 0
        for i < len(hpool.pages_2mb) {
            page := hpool.pages_2mb[i]
            if page.base_address == hp.base_address {
                page.free = true
                hpool.pages_2mb[i] = page
                return 0, ""
            }
            i = i + 1
        }
    } else if hp.size == 1073741824 {
        j := 0
        for j < len(hpool.pages_1gb) {
            page := hpool.pages_1gb[j]
            if page.base_address == hp.base_address {
                page.free = true
                hpool.pages_1gb[j] = page
                return 0, ""
            }
            j = j + 1
        }
    }
    return -1, "Page not found"
}

func (huge_pages_pool hpool) get_stats() (int, int, int, int) {
    free_2mb := 0
    free_1gb := 0
    
    i := 0
    for i < len(hpool.pages_2mb) {
        if hpool.pages_2mb[i].free {
            free_2mb = free_2mb + 1
        }
        i = i + 1
    }
    
    j := 0
    for j < len(hpool.pages_1gb) {
        if hpool.pages_1gb[j].free {
            free_1gb = free_1gb + 1
        }
        j = j + 1
    }
    
    return hpool.total_2mb - free_2mb, hpool.total_1gb - free_1gb, free_2mb, free_1gb
}
