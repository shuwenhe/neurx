package test.mm

use mm.vm

func main() int {
    init_vm()
    mmap_region(0x1000, 0x10000, 0)
    idx := find_region(0x2000)
    if idx < 0 {
        return 1
    }
    0
}
