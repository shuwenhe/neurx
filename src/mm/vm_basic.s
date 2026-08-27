package mm.vm

use std.io.eprintln

struct vm_region {
    int start
    int end
    int flags
}

vm_region[] regions

func init_vm() int {
    regions = vm_region[]{}
    0
}

func mmap_region(int start, int size, int flags) int {
    regions = append(regions, vm_region{start:start, end:start + size, flags:flags})
    0
}

func find_region(int addr) int {
    i := 0
    for i < len(regions) {
        if addr >= regions[i].start && addr < regions[i].end {
            return i
        }
        i = i + 1
    }
    -1
}
