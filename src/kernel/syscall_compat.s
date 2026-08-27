package kernel.syscall

use std.strings.int_to_string
use std.io.eprintln

struct syscall_entry {
    int number
    string name
}

syscall_entry[] syscall_table

func init_syscall_table() int {
    syscall_table = syscall_entry[]{}
    syscall_table = append(syscall_table, syscall_entry{number:0, name:"read"})
    syscall_table = append(syscall_table, syscall_entry{number:1, name:"write"})
    syscall_table = append(syscall_table, syscall_entry{number:2, name:"open"})
    syscall_table = append(syscall_table, syscall_entry{number:3, name:"close"})
    0
}

func syscall_dispatch(int num, int[] args) int {
    eprintln("syscall_dispatch: " + int_to_string(num))
    // TODO: implement syscall handling and mapping to internal primitives
    -1
}
