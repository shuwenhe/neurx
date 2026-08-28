package kernel.mem
int[] phys_mem
func init_phys_mem() int {
    phys_mem = int[]{}
    i := 0
    size := 16 * 1024 * 1024
    for i < size {
        phys_mem = append(phys_mem, 0)
        i = i + 1
    }
    0
}

func mem_get(int addr, int count) int[] {
    res := int[]{}
    i := 0
    for i < count {
        if addr + i >= 0 && addr + i < len(phys_mem) {
            res = append(res, phys_mem[addr + i])
        } else {
            res = append(res, 0)
        }
        i = i + 1
    }
    res
}

func mem_set(int addr, int[] data) int {
    i := 0
    for i < len(data) {
        if addr + i >= 0 && addr + i < len(phys_mem) {
            phys_mem[addr + i] = data[i]
        }
        i = i + 1
    }
    0
}
