package test.kernel

use kernel.syscall

func main() {
    init_syscall_table()
    
    fd := syscall_dispatch(2, []int{1, 0})
    if fd != 3 {
        return 2
    }
    
    wrote := syscall_dispatch(1, []int{fd, 0, 12})
    if wrote != 12 {
        return 3
    }
    
    read := syscall_dispatch(0, []int{fd, 0, 8})
    if read != 8 {
        return 4
    }
    
    cl := syscall_dispatch(3, []int{fd})
    if cl != 0 {
        return 5
    }
    0
}
