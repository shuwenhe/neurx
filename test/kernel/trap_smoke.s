package test.kernel

use kernel.trap

func main() int {
    // simulate syscall trap for open/write/read/close
    fd := syscall_trap(2, int[]{1, 0})
    if fd != 3 {
        return 2
    }
    wrote := syscall_trap(1, int[]{fd, 0, 7})
    if wrote != 7 {
        return 3
    }
    read := syscall_trap(0, int[]{fd, 0, 4})
    if read != 4 {
        return 4
    }
    cl := syscall_trap(3, int[]{fd})
    if cl != 0 {
        return 5
    }
    0
}
