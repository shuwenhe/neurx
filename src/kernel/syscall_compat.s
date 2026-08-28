package kernel.syscall
use std.strings.int_to_string
use std.io.eprintln
use mm.vm
use kernel.mem
struct syscall_entry {
    int number
    string name
}
syscall_entry[] syscall_table
map[int]int[] fd_table
int next_fd
const enosys = -38
func init_syscall_table() int {
    syscall_table = syscall_entry[]{}
    syscall_table = append(syscall_table, syscall_entry{number:0, name:"read"})
    syscall_table = append(syscall_table, syscall_entry{number:1, name:"write"})
    syscall_table = append(syscall_table, syscall_entry{number:2, name:"open"})
    syscall_table = append(syscall_table, syscall_entry{number:3, name:"close"})
    fd_table = map[int]int[]{}
    next_fd = 3
    init_phys_mem()
    0
}
func sys_read(int fd, int buf_addr, int count) int {
    data := int[]{}
    if has(fd_table, fd) {
        data = fd_table[fd]
    }
    n := count
    if n > len(data) {
        n = len(data)
    }
    slice := int[]{}
    i := 0
    for i < n {
        slice = append(slice, data[i])
        i = i + 1
    }
    mem_set(buf_addr, slice)
    n
}
func sys_write(int fd, int buf_addr, int count) int {
    bytes := mem_get(buf_addr, count)
    existing := int[]{}
    if has(fd_table, fd) {
        existing = fd_table[fd]
    }
    i := 0
    for i < len(bytes) {
        existing = append(existing, bytes[i])
        i = i + 1
    }
    fd_table[fd] = existing
    len(bytes)
}
func sys_open(string path, int flags) int {
    eprintln("sys_open called path=" + path)
    fd := next_fd
    next_fd = next_fd + 1
    fd_table[fd] = int[]{}
    fd
}
func sys_close(int fd) int {
    if has(fd_table, fd) {
        fd_table[fd] = int[]{}
    }
    0
}
func sys_fstat(int fd, int stat_buf_addr) int {
    eprintln("sys_fstat fd=" + int_to_string(fd))
    0
}
func sys_mmap(int addr, int length, int prot, int flags, int fd, int offset) int {
    mmap_region(0x100000, length, prot)
    0x100000
}
func sys_brk(int brk_addr) int {
    eprintln("sys_brk called: " + int_to_string(brk_addr))
    0x200000
}
func sys_exit(int code) int {
    eprintln("sys_exit called: code=" + int_to_string(code))
    code
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
        return enosys
    } else if num == 3 {
        if len(args) >= 1 {
            return sys_close(args[0])
        }
        return -1
    } else if num == 5 {
        if len(args) >= 2 {
            return sys_fstat(args[0], args[1])
        }
        return enosys
    } else if num == 9 {
        if len(args) >= 6 {
            return sys_mmap(args[0], args[1], args[2], args[3], args[4], args[5])
        }
        return enosys
    } else if num == 12 {
        if len(args) >= 1 {
            return sys_brk(args[0])
        }
        return ENOSYS
    } else if num == 60 {
        if len(args) >= 1 {
            return sys_exit(args[0])
        }
        return sys_exit(0)
    }
    -1
}
