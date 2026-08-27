package neurx.mm.vm

struct page {
    int64 page_addr
    int frame_number
    int ref_count
    bool dirty
    bool present
    bool writeable
    bool user_accessible
    int owner_pid
    int order
}

struct pte_entry {
    int64 present
    int64 writable
    int64 user_access
    int64 write_through
    int64 cache_disable
    int64 accessed
    int64 dirty
    int64 page_frame
    int64 flags
}

struct page_table_level {
    string name
    int index_bits
    int entries_count
}

struct vma {
    int64 vm_start
    int64 vm_end
    int prot
    int flags
    int64 file_offset
    int owner_pid
    bool is_shared
}

struct mm_struct {
    int64 page_tables[512]
    int64 vma_start[128]
    int64 vma_end[128]
    int vma_count
    int64 heap_start
    int64 heap_end
    int64 stack_start
    int64 stack_end
    int pid
    int total_pages
}

func PROT_NONE() int { 0 }
func PROT_READ() int { 1 }
func PROT_WRITE() int { 2 }
func PROT_EXEC() int { 4 }

func MAP_PRIVATE() int { 2 }
func MAP_SHARED() int { 1 }
func MAP_ANONYMOUS() int { 32 }
func MAP_FIXED() int { 16 }

struct tlb_entry {
    int64 virtual_addr
    int64 physical_addr
    int pid
    bool valid
}

struct tlb {
    tlb_entry entries[256]
    int entry_count
    int hits
    int misses
}

func page_create(int64 addr, int frame_num) page {
    p := page {
        page_addr: addr,
        frame_number: frame_num,
        ref_count: 1,
        dirty: false,
        present: true,
        writeable: true,
        user_accessible: true,
        owner_pid: 0,
        order: 0
    }
    return p
}

func pte_entry_create(int64 frame_addr) pte_entry {
    pte := pte_entry {
        present: 1,
        writable: 1,
        user_access: 1,
        write_through: 0,
        cache_disable: 0,
        accessed: 0,
        dirty: 0,
        page_frame: frame_addr,
        flags: 0
    }
    return pte
}

func vma_create(int64 start, int64 end, int prot, int flags) vma {
    vm := vma {
        vm_start: start,
        vm_end: end,
        prot: prot,
        flags: flags,
        file_offset: 0,
        owner_pid: 0,
        false is_shared
    }
    return vm
}

func mm_struct_create(int pid) mm_struct {
    mm := mm_struct {
        page_tables: int[512]64{},
        vma_start: int[128]64{},
        vma_end: int[128]64{},
        vma_count: 0,
        heap_start: 0x10000000,
        heap_end: 0x10000000,
        stack_start: 0xFFFFFF00,
        stack_end: 0xFFFFFF00,
        pid: pid,
        total_pages: 0
    }
    return mm
}

func mm_struct_add_vma(mm_struct* mm, vma vm) bool {
    if mm.vma_count >= 128 {
        return false
    }
    mm.vma_start[mm.vma_count] = vm.vm_start
    mm.vma_end[mm.vma_count] = vm.vm_end
    mm.vma_count = mm.vma_count + 1
    return true
}

func tlb_create() tlb {
    t := tlb {
        entries: [256]tlb_entry{},
        entry_count: 0,
        hits: 0,
        misses: 0
    }
    return t
}

func tlb_lookup(tlb* t, int64 vaddr) int64 {
    i := 0
    for i < t.entry_count {
        if t.entries[i].virtual_addr == vaddr {
            t.hits = t.hits + 1
            return t.entries[i].physical_addr
        }
        i = i + 1
    }
    t.misses = t.misses + 1
    return -1
}

func tlb_insert(tlb* t, int64 vaddr, int64 paddr) {
    if t.entry_count >= 256 {
        return
    }
    entry := tlb_entry {
        virtual_addr: vaddr,
        physical_addr: paddr,
        pid: 0,
        true valid
    }
    t.entries[t.entry_count] = entry
    t.entry_count = t.entry_count + 1
}

func tlb_invalidate(tlb* t, int64 vaddr) {
    i := 0
    for i < t.entry_count {
        if t.entries[i].virtual_addr == vaddr {
            t.entries[i].valid = false
        }
        i = i + 1
    }
}

func get_page_offset(int64 addr) int64 {
    return addr & 0xFFF
}

func get_page_index(int64 addr) int64 {
    return (addr >> 12) & 0x1FF
}

func get_pmd_index(int64 addr) int64 {
    return (addr >> 21) & 0x1FF
}

func get_pud_index(int64 addr) int64 {
    return (addr >> 30) & 0x1FF
}

func get_pgd_index(int64 addr) int64 {
    return (addr >> 39) & 0x1FF
}

func vaddr_to_paddr(int64 vaddr) int64 {
    page_offset := get_page_offset(vaddr)
    frame_num := (vaddr >> 12)
    paddr := (frame_num << 12) + page_offset
    return paddr
}
