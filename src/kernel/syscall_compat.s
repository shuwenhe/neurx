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

func sys_read(int fd, int buf_addr, int count) int {
    // stub: pretend we read 'count' bytes
    eprintln("sys_read called fd=" + int_to_string(fd) + " count=" + int_to_string(count))
    count
}

func sys_write(int fd, int buf_addr, int count) int {
    // stub: pretend we wrote 'count' bytes
    eprintln("sys_write called fd=" + int_to_string(fd) + " count=" + int_to_string(count))
    count
}

func sys_open(string path, int flags) int {
    eprintln("sys_open called path=" + path)
    // return fake fd
    3
}

func sys_close(int fd) int {
    eprintln("sys_close called fd=" + int_to_string(fd))
    0
}

func syscall_dispatch(int num, int[] args) int {
    eprintln("syscall_dispatch: " + int_to_string(num))
    // dispatch common syscalls by number
    if num == 0 {
        if len(args) >= 3 {
            return sys_read(args[0], args[1], args[2])
        }
        return -1
    } else if num == 1 {
        if len(args) >= 3 {
            return sys_write(args[0], args[1], args[2])
        }
        return -1
    } else if num == 2 {
        // open: args[0]=path_addr (not supported), args[1]=flags
        // we accept a synthetic path index as int for smoke tests
        if len(args) >= 2 {
            // if path represented as an int index, map to string
            path_str := "unknown"
            if args[0] == 1 {
                path_str = "/tmp/test"
            }
            return sys_open(path_str, args[1])
        }
        return -1
    } else if num == 3 {
        if len(args) >= 1 {
            return sys_close(args[0])
        }
        return -1
    }
    // unknown syscall
    -1
}
