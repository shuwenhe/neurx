package kernel.trap

use std.io.eprintln
use kernel.syscall

// Simulated trap entry for syscalls. In real kernel this is invoked from
// the exception/interrupt path with register state; here we expose a
// simple entry for smoke-testing and integration.
func syscall_trap(int num, int[] args) int {
    eprintln("syscall_trap: num=" + num)
    return syscall_dispatch(num, args)
}
