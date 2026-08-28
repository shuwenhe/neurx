package kernel.trap
use std.io.eprintln
use kernel.syscall
func syscall_trap(int num, int[] args) int {
    eprintln("syscall_trap: num=" + num)
    return syscall_dispatch(num, args)
}
