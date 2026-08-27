package test.kernel

use kernel.syscall

func main() {
    init_syscall_table()

    // fstat on synthetic fd
    fs := syscall_dispatch(5, int[]{3, 0})
    if fs != 0 {
        return 2
    }

    // mmap request
    addr := syscall_dispatch(9, int[]{0, 4096, 0, 0, -1, 0})
    if addr == -38 { // ENOSYS
        return 3
    }

    // brk
    br := syscall_dispatch(12, int[]{0x300000})
    if br == -38 {
        return 4
    }

    // exit (should return code)
    ex := syscall_dispatch(60, int[]{42})
    if ex != 42 {
        return 5
    }

    0
}
