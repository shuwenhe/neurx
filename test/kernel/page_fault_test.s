package neurx.test.kernel

use neurx.mm.fault.vm_system
use neurx.mm.fault.vm_system_create
use neurx.mm.fault.anonymous_page_fault
use neurx.mm.fault.fork_address_space
use neurx.mm.fault.find_mapping
use neurx.mm.fault.map_file_page
use neurx.mm.fault.age_pages
use neurx.mm.fault.reclaim_clean_file_pages
use neurx.mm.fault.VM_OK

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0
    vm_system vm = vm_system_create(128, 16)
    vm = anonymous_page_fault(vm, 100, 4096, true)
    parent_map := find_mapping(vm, 100, 4096)
    original_frame := vm.map_frame[parent_map]
    failures = failures + expect(vm.last_result == VM_OK() && original_frame == 16 &&
        vm.frame_dirty[original_frame], "demand allocate anonymous page")

    vm = fork_address_space(vm, 100, 101)
    child_map := find_mapping(vm, 101, 4096)
    failures = failures + expect(vm.map_frame[child_map] == original_frame &&
        vm.frame_refcount[original_frame] == 2 && vm.map_cow[parent_map] && vm.map_cow[child_map],
        "fork shares page read-only with COW")

    vm = anonymous_page_fault(vm, 101, 4096, true)
    child_frame := vm.map_frame[child_map]
    failures = failures + expect(child_frame != original_frame && vm.copy_events == 1 &&
        vm.frame_refcount[original_frame] == 1 && vm.frame_refcount[child_frame] == 1,
        "write fault copies shared frame")

    vm = map_file_page(vm, 100, 8192, false)
    vm = age_pages(vm)
    vm = reclaim_clean_file_pages(vm, 1)
    failures = failures + expect(vm.reclaimed_pages == 1,
        "reclaim inactive clean file-backed page")
    return failures
}

func _start() int { return main() }
