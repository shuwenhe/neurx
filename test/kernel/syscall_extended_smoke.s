package test.kernel

use kernel.syscall

func main() {
    init_syscall_table()

    fs := syscall_dispatch(5, []int{3, 0})
    if fs != 0 {
        return 2
    }

    addr := syscall_dispatch(9, []int{0, 4096, 0, 0, -1, 0})
    if addr == -38 {
        return 3
    }

    br := syscall_dispatch(12, []int{0x300000})
    if br == -38 {
        return 4
    }

    ex := syscall_dispatch(60, []int{42})
    if ex != 42 {
        return 5
    }

    0
}
