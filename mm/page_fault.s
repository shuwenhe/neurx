package neurx.mm.fault

func VM_OK() int { 0 }
func VM_OUT_OF_MEMORY() int { 1 }
func VM_SEGFAULT() int { 2 }
func VM_MAPPING_LIMIT() int { 3 }

struct vm_system {
    int frame_count
    [4096]bool frame_free
    [4096]int frame_refcount
    [4096]bool frame_dirty

    int mapping_count
    [8192]int map_pid
    [8192]int map_vpage
    [8192]int map_frame
    [8192]bool map_present
    [8192]bool map_writable
    [8192]bool map_cow
    [8192]bool map_accessed
    [8192]bool map_file_backed

    int page_faults
    int cow_faults
    int copy_events
    int reclaimed_pages
    int last_frame
    int last_result
}

func vm_system_create(int frames, int reserved_frames) vm_system {
    vm_system vm = vm_system {
        frame_count: frames,
        frame_free: [4096]bool{}, frame_refcount: [4096]int{},
        frame_dirty: [4096]bool{}, mapping_count: 0,
        map_pid: [8192]int{}, map_vpage: [8192]int{}, map_frame: [8192]int{},
        map_present: [8192]bool{}, map_writable: [8192]bool{},
        map_cow: [8192]bool{}, map_accessed: [8192]bool{},
        map_file_backed: [8192]bool{}, page_faults: 0, cow_faults: 0,
        copy_events: 0, reclaimed_pages: 0, last_frame: -1,
        last_result: VM_OK()
    }
    int frame = 0
    for frame < frames && frame < 4096 {
        if frame >= reserved_frames { vm.frame_free[frame] = true }
        frame = frame + 1
    }
    return vm
}

func find_mapping(vm_system vm, int pid, int vpage) int {
    int i = 0
    for i < vm.mapping_count {
        if vm.map_present[i] && vm.map_pid[i] == pid && vm.map_vpage[i] == vpage {
            return i
        }
        i = i + 1
    }
    return -1
}

func allocate_frame(vm_system vm) int {
    int frame = 0
    for frame < vm.frame_count && frame < 4096 {
        if vm.frame_free[frame] { return frame }
        frame = frame + 1
    }
    return -1
}

func install_mapping(vm_system vm, int pid, int vpage, int frame,
                     bool writable, bool file_backed) vm_system {
    if vm.mapping_count >= 8192 {
        vm.last_result = VM_MAPPING_LIMIT()
        return vm
    }
    slot := vm.mapping_count
    vm.map_pid[slot] = pid
    vm.map_vpage[slot] = vpage
    vm.map_frame[slot] = frame
    vm.map_present[slot] = true
    vm.map_writable[slot] = writable
    vm.map_cow[slot] = false
    vm.map_accessed[slot] = true
    vm.map_file_backed[slot] = file_backed
    vm.frame_free[frame] = false
    vm.frame_refcount[frame] = vm.frame_refcount[frame] + 1
    vm.mapping_count = vm.mapping_count + 1
    vm.last_frame = frame
    vm.last_result = VM_OK()
    return vm
}

func anonymous_page_fault(vm_system vm, int pid, int vpage, bool write) vm_system {
    vm.page_faults = vm.page_faults + 1
    mapping := find_mapping(vm, pid, vpage)
    if mapping < 0 {
        frame := allocate_frame(vm)
        if frame < 0 { vm.last_result = VM_OUT_OF_MEMORY(); return vm }
        vm = install_mapping(vm, pid, vpage, frame, true, false)
        if write { vm.frame_dirty[frame] = true }
        return vm
    }

    vm.map_accessed[mapping] = true
    frame := vm.map_frame[mapping]
    if !write { vm.last_frame = frame; vm.last_result = VM_OK(); return vm }
    if vm.map_cow[mapping] {
        vm.cow_faults = vm.cow_faults + 1
        if vm.frame_refcount[frame] > 1 {
            new_frame := allocate_frame(vm)
            if new_frame < 0 { vm.last_result = VM_OUT_OF_MEMORY(); return vm }
            vm.frame_refcount[frame] = vm.frame_refcount[frame] - 1
            vm.frame_free[new_frame] = false
            vm.frame_refcount[new_frame] = 1
            vm.map_frame[mapping] = new_frame
            vm.copy_events = vm.copy_events + 1
            frame = new_frame
        }
        vm.map_cow[mapping] = false
        vm.map_writable[mapping] = true
    }
    if !vm.map_writable[mapping] { vm.last_result = VM_SEGFAULT(); return vm }
    vm.frame_dirty[frame] = true
    vm.last_frame = frame
    vm.last_result = VM_OK()
    return vm
}

func map_file_page(vm_system vm, int pid, int vpage, bool writable) vm_system {
    frame := allocate_frame(vm)
    if frame < 0 { vm.last_result = VM_OUT_OF_MEMORY(); return vm }
    return install_mapping(vm, pid, vpage, frame, writable, true)
}

func fork_address_space(vm_system vm, int parent_pid, int child_pid) vm_system {
    int original_count = vm.mapping_count
    int i = 0
    for i < original_count {
        if vm.map_present[i] && vm.map_pid[i] == parent_pid {
            if vm.mapping_count >= 8192 { vm.last_result = VM_MAPPING_LIMIT(); return vm }
            slot := vm.mapping_count
            frame := vm.map_frame[i]
            vm.map_pid[slot] = child_pid
            vm.map_vpage[slot] = vm.map_vpage[i]
            vm.map_frame[slot] = frame
            vm.map_present[slot] = true
            vm.map_writable[slot] = false
            vm.map_cow[slot] = true
            vm.map_accessed[slot] = false
            vm.map_file_backed[slot] = vm.map_file_backed[i]
            vm.map_writable[i] = false
            vm.map_cow[i] = true
            vm.frame_refcount[frame] = vm.frame_refcount[frame] + 1
            vm.mapping_count = vm.mapping_count + 1
        }
        i = i + 1
    }
    vm.last_result = VM_OK()
    return vm
}

func age_pages(vm_system vm) vm_system {
    int i = 0
    for i < vm.mapping_count { vm.map_accessed[i] = false; i = i + 1 }
    return vm
}

func reclaim_clean_file_pages(vm_system vm, int target) vm_system {
    int reclaimed = 0
    int i = 0
    for i < vm.mapping_count && reclaimed < target {
        frame := vm.map_frame[i]
        if vm.map_present[i] && vm.map_file_backed[i] &&
           !vm.map_accessed[i] && !vm.frame_dirty[frame] {
            vm.map_present[i] = false
            vm.frame_refcount[frame] = vm.frame_refcount[frame] - 1
            if vm.frame_refcount[frame] == 0 { vm.frame_free[frame] = true }
            reclaimed = reclaimed + 1
        }
        i = i + 1
    }
    vm.reclaimed_pages = vm.reclaimed_pages + reclaimed
    vm.last_result = VM_OK()
    return vm
}
