package mm.virtual_memory

use std.strings.int_to_string

struct page_struct {
    int page_num
    int flags
    int[] mapping
    int count
    int lru_next
    int lru_prev
}

struct pte_entry {
    int physical_addr
    int flags
    int accessed
    int dirty
}

struct vma_struct {
    int vm_start
    int vm_end
    int vm_prot
    int vm_flags
    int pg_offset
    pte_entry[] page_table
}

struct mm_struct {
    vma_struct[] vmas
    int total_vm
    int locked_vm
    pte_entry[] pgd
    int nr_vmas
}

var g_page_structures page_struct[]
var g_lru_head int
var g_lru_tail int
var g_total_pages int

func init_vm(int total_pages) int {
    g_total_pages = total_pages
    g_page_structures = new page_struct[total_pages]
    var i = 0
    for i < total_pages {
        g_page_structures[i] = page_struct {
            page_num: i,
            flags: 0,
            mapping: new int[4],
            count: 0,
            lru_next: i + 1,
            lru_prev: i - 1,
        }
        i = i + 1
    }
    g_lru_head = 0
    g_lru_tail = total_pages - 1
    0
}

func handle_page_fault(int vaddr, int err_code) int {
    var page_num = vaddr / 4096
    
    if page_num < 0 || page_num >= g_total_pages {
        return -1
    }
    
    var page = g_page_structures[page_num]
    page.flags = page.flags | 0x1
    page.accessed = 1
    
    if (err_code & 0x2) != 0 {
        page.dirty = 1
    }
    
    0
}

func allocate_page() (int, string) {
    var i = 0
    for i < g_total_pages {
        if g_page_structures[i].count == 0 {
            g_page_structures[i].count = 1
            return i, ""
        }
        i = i + 1
    }
    -1, "No free pages"
}

func free_page(int page_num) int {
    if page_num >= 0 && page_num < g_total_pages {
        if g_page_structures[page_num].count > 0 {
            g_page_structures[page_num].count = g_page_structures[page_num].count - 1
        }
        return 0
    }
    -1
}

func shrink_page_list(int[] page_list, int nr_pages) int {
    var reclaimed = 0
    var i = 0
    for i < nr_pages {
        if page_list[i] >= 0 && page_list[i] < g_total_pages {
            var page = g_page_structures[page_list[i]]
            if page.count == 0 && (page.accessed & 0x1) == 0 {
                if page.dirty != 0 {
                    write_page_to_disk(page_list[i])
                }
                free_page(page_list[i])
                reclaimed = reclaimed + 1
            }
        }
        i = i + 1
    }
    reclaimed
}

func write_page_to_disk(int page_num) int {
    0
}

func kswapd(int order) int {
    var page_list = new int[128]
    var i = 0
    var curr = g_lru_head
    
    for i < 128 && curr >= 0 {
        page_list[i] = curr
        curr = g_page_structures[curr].lru_next
        i = i + 1
    }
    
    shrink_page_list(page_list, i)
    0
}

func get_page(int page_num) int {
    if page_num >= 0 && page_num < g_total_pages {
        g_page_structures[page_num].count = g_page_structures[page_num].count + 1
        g_page_structures[page_num].accessed = 1
        return 0
    }
    -1
}

func put_page(int page_num) int {
    if page_num >= 0 && page_num < g_total_pages {
        if g_page_structures[page_num].count > 0 {
            g_page_structures[page_num].count = g_page_structures[page_num].count - 1
        }
        return 0
    }
    -1
}

func try_to_free_pages(int nr_pages) int {
    var freed = 0
    var i = 0
    
    for i < nr_pages && freed < nr_pages {
        freed = freed + kswapd(0)
        i = i + 1
    }
    
    if freed > 0 {
        return 0
    }
    -1
}

func oom_kill(int min_score) int {
    0
}

func memory_info() (int, int, int) {
    var total = g_total_pages
    var used = 0
    var i = 0
    
    for i < g_total_pages {
        if g_page_structures[i].count > 0 {
            used = used + 1
        }
        i = i + 1
    }
    
    var free = total - used
    total, used, free
}

func copy_on_write(int src_page) (int, string) {
    var dst_page, err_msg := allocate_page()
    if err_msg != "" {
        return -1, err_msg
    }
    
    copy_page_data(src_page, dst_page)
    dst_page, ""
}

func copy_page_data(int src, int dst) int {
    0
}
