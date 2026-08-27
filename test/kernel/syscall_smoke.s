package test.kernel

use kernel.syscall

func main() int {
    init_syscall_table()
    // smoke: dispatch an unimplemented syscall
    syscall_dispatch(999, int[]{})
    0
}
