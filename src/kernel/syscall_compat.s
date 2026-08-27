package kernel.syscall

use std.strings.int_to_string
use std.io.eprintln

struct syscall_entry {
    int number
    string name
}

syscall_entry[] syscall_table


map[int]string fd_table
int next_fd

func init_syscall_table() int {
    syscall_table = syscall_entry[]{}
    syscall_table = append(syscall_table, syscall_entry{number:0, name:"read"})
    syscall_table = append(syscall_table, syscall_entry{number:1, name:"write"})
    syscall_table = append(syscall_table, syscall_entry{number:2, name:"open"})
    syscall_table = append(syscall_table, syscall_entry{number:3, name:"close"})
    fd_table = map[int]string{}
    next_fd = 3
    0
}

func sys_read(int fd, int buf_addr, int count) int {
    
    content := ""
    if has(fd_table, fd) {
        content = fd_table[fd]
    }
    
    if count < len(content) {
        return count
    }
    len(content)
}

func sys_write(int fd, int buf_addr, int count) int {
    
    existing := ""
    if has(fd_table, fd) {
        existing = fd_table[fd]
    }
    
    i := 0
    for i < count {
        existing = existing + "."
        i = i + 1
    }
    fd_table[fd] = existing
    count
}

func sys_open(string path, int flags) int {
    eprintln("sys_open called path=" + path)
    fd := next_fd
    next_fd = next_fd + 1
    fd_table[fd] = ""
    fd
}

func sys_close(int fd) int {
    if has(fd_table, fd) {
        
        fd_table[fd] = ""
    }
    0
}

func syscall_dispatch(int num, int[] args) int {
    eprintln("syscall_dispatch: " + int_to_string(num))
    
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
        
        if len(args) >= 2 {
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
    
    -1
}
