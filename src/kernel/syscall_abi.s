package kernel.syscall

use std.strings.int_to_string
use std.io.eprintln

// ABI shim called from assembly syscall entry. Takes syscall number and
// six integer args in registers and forwards to `syscall_dispatch`.
func syscall_entry_from_asm(int num, int a0, int a1, int a2, int a3, int a4, int a5) int {
    eprintln("syscall_entry_from_asm num=" + int_to_string(num))
    args := int[]{a0, a1, a2, a3, a4, a5}
    return syscall_dispatch(num, args)
}
