package test.kernel

use kernel.syscall

func main() int {
    init_syscall_table()
    // smoke: call basic syscalls
    // sys_open: use synthetic path id 1, flags=0 -> expect fd 3
    fd := syscall_dispatch(2, int[]{1, 0})
    if fd != 3 {
        return 2
    }
    // sys_write: fd, buf_addr (ignored), count
    wrote := syscall_dispatch(1, int[]{fd, 0, 12})
    if wrote != 12 {
        return 3
    }
    // sys_read: fd, buf_addr, count
    read := syscall_dispatch(0, int[]{fd, 0, 8})
    if read != 8 {
        return 4
    }
    // sys_close
    cl := syscall_dispatch(3, int[]{fd})
    if cl != 0 {
        return 5
    }
    0
}
