package neurx.kernel.syscall

use std.slices

struct syscall_handler_entry {
    int syscall_number
    string name
    int arg_count
}

struct syscall_dispatcher {
    vec[syscall_handler_entry]* handlers
    syscall_stats* stats
    bool initialized
}

func syscall_dispatcher_create() syscall_dispatcher {
    dispatcher := syscall_dispatcher {
        handlers: vec[syscall_handler_entry](),
        stats: syscall_stats_create() as syscall_stats*,
        initialized: false
    }
    return dispatcher
}

func register_syscall_handler(syscall_dispatcher* dispatcher, 
                             int number, 
                             string name, 
                             int arg_count) {
    entry := syscall_handler_entry {
        syscall_number: number,
        name: name,
        arg_count: arg_count
    }
}

func syscall_handler_read(syscall_context* ctx) {
    fd := get_syscall_arg1(ctx) as int
    buf := get_syscall_arg2(ctx)
    count := get_syscall_arg3(ctx) as int
    
    if fd < 0 || fd >= 1024 {
        set_syscall_error(ctx, 9)
        return
    }
    
    set_syscall_return(ctx, count)
}

func syscall_handler_write(syscall_context* ctx) {
    fd := get_syscall_arg1(ctx) as int
    buf := get_syscall_arg2(ctx)
    count := get_syscall_arg3(ctx) as int
    
    if fd < 0 || fd >= 1024 {
        set_syscall_error(ctx, 9)
        return
    }
    
    set_syscall_return(ctx, count)
}

func syscall_handler_open(syscall_context* ctx) {
    filename := get_syscall_arg1(ctx)
    flags := get_syscall_arg2(ctx) as int
    mode := get_syscall_arg3(ctx) as int
    
    fd := 3
    set_syscall_return(ctx, fd)
}

func syscall_handler_close(syscall_context* ctx) {
    fd := get_syscall_arg1(ctx) as int
    
    if fd < 0 || fd >= 1024 {
        set_syscall_error(ctx, 9)
        return
    }
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_fork(syscall_context* ctx) {
    new_pid := 100
    set_syscall_return(ctx, new_pid)
}

func syscall_handler_execve(syscall_context* ctx) {
    filename := get_syscall_arg1(ctx)
    argv := get_syscall_arg2(ctx)
    envp := get_syscall_arg3(ctx)
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_exit(syscall_context* ctx) {
    code := get_syscall_arg1(ctx) as int
}

func syscall_handler_wait4(syscall_context* ctx) {
    pid := get_syscall_arg1(ctx) as int
    wstatus := get_syscall_arg2(ctx)
    options := get_syscall_arg3(ctx) as int
    rusage := get_syscall_arg4(ctx)
    
    set_syscall_return(ctx, 100)
}

func syscall_handler_getpid(syscall_context* ctx) {
    set_syscall_return(ctx, 1)
}

func syscall_handler_gettid(syscall_context* ctx) {
    set_syscall_return(ctx, 1)
}

func syscall_handler_mmap(syscall_context* ctx) {
    addr := get_syscall_arg1(ctx)
    length := get_syscall_arg2(ctx) as int
    prot := get_syscall_arg3(ctx) as int
    flags := get_syscall_arg4(ctx) as int
    fd := get_syscall_arg5(ctx) as int
    offset := get_syscall_arg6(ctx) as int
    
    mapped_addr := 0x7FFF0000
    set_syscall_return(ctx, mapped_addr)
}

func syscall_handler_munmap(syscall_context* ctx) {
    addr := get_syscall_arg1(ctx)
    length := get_syscall_arg2(ctx) as int
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_rt_sigaction(syscall_context* ctx) {
    signum := get_syscall_arg1(ctx) as int
    act := get_syscall_arg2(ctx)
    oldact := get_syscall_arg3(ctx)
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_rt_sigprocmask(syscall_context* ctx) {
    how := get_syscall_arg1(ctx) as int
    set_syscall_arg2(ctx)
    oset := get_syscall_arg3(ctx)
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_socket(syscall_context* ctx) {
    domain := get_syscall_arg1(ctx) as int
    type_val := get_syscall_arg2(ctx) as int
    protocol := get_syscall_arg3(ctx) as int
    
    sockfd := 3
    set_syscall_return(ctx, sockfd)
}

func syscall_handler_connect(syscall_context* ctx) {
    sockfd := get_syscall_arg1(ctx) as int
    addr := get_syscall_arg2(ctx)
    addrlen := get_syscall_arg3(ctx) as int
    
    set_syscall_return(ctx, 0)
}

func syscall_handler_kill(syscall_context* ctx) {
    pid := get_syscall_arg1(ctx) as int
    sig := get_syscall_arg2(ctx) as int
    
    set_syscall_return(ctx, 0)
}

func syscall_dispatch(syscall_context* ctx) {
    number := ctx.syscall_number
    name := get_syscall_name(number)
    ctx.syscall_name = name
    
    if number == SYS_read() { 
        syscall_handler_read(ctx)
    } else if number == SYS_write() {
        syscall_handler_write(ctx)
    } else if number == SYS_open() {
        syscall_handler_open(ctx)
    } else if number == SYS_close() {
        syscall_handler_close(ctx)
    } else if number == SYS_fork() {
        syscall_handler_fork(ctx)
    } else if number == SYS_execve() {
        syscall_handler_execve(ctx)
    } else if number == SYS_exit() {
        syscall_handler_exit(ctx)
    } else if number == SYS_wait4() {
        syscall_handler_wait4(ctx)
    } else if number == SYS_getpid() {
        syscall_handler_getpid(ctx)
    } else if number == SYS_gettid() {
        syscall_handler_gettid(ctx)
    } else if number == SYS_mmap() {
        syscall_handler_mmap(ctx)
    } else if number == SYS_munmap() {
        syscall_handler_munmap(ctx)
    } else if number == SYS_rt_sigaction() {
        syscall_handler_rt_sigaction(ctx)
    } else if number == SYS_rt_sigprocmask() {
        syscall_handler_rt_sigprocmask(ctx)
    } else if number == SYS_socket() {
        syscall_handler_socket(ctx)
    } else if number == SYS_connect() {
        syscall_handler_connect(ctx)
    } else if number == SYS_kill() {
        syscall_handler_kill(ctx)
    } else {
        set_syscall_error(ctx, 38)
    }
}

func syscall_entry_handler(int number, trap_frame* frame) int64 {
    ctx := syscall_context_create(number, frame)
    syscall_dispatch(*ctx)
    return frame.rax
}
