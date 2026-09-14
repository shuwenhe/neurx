package kernel.trap
import (
    "kernel.syscall"
    "std.io.eprintln"
)
func syscall_trap(int num, []int args) int {
    eprintln("syscall_trap: num=" + num)
    return syscall_dispatch(num, args)
}
