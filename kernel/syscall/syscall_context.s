package neurx.kernel.syscall

struct trap_frame {
    int64 rax
    int64 rbx
    int64 rcx
    int64 rdx
    int64 rsi
    int64 rdi
    int64 r8
    int64 r9
    int64 r10
    int64 r11
    int64 r12
    int64 r13
    int64 r14
    int64 r15
    int64 rbp
    int64 rsp
    int64 rip
    int64 rflags
    int64 cs
    int64 ds
    int64 es
    int64 fs
    int64 gs
}

struct syscall_context {
    int syscall_number
    trap_frame* frame
    int errno
    int return_value
    string syscall_name
}

struct syscall_stats {
    int64 total_syscalls
    int64 total_time_ns
    int64 errors
    int64 by_type[256]
}

func trap_frame_create() trap_frame {
    frame := trap_frame {
        rax: 0, rbx: 0, rcx: 0, rdx: 0,
        rsi: 0, rdi: 0, r8: 0, r9: 0,
        r10: 0, r11: 0, r12: 0, r13: 0,
        r14: 0, r15: 0, rbp: 0, rsp: 0,
        rip: 0, rflags: 0, cs: 0, ds: 0,
        es: 0, fs: 0, gs: 0
    }
    return frame
}

func syscall_context_create(int number, trap_frame* frame) syscall_context {
    ctx := syscall_context {
        syscall_number: number,
        frame: frame,
        errno: 0,
        return_value: 0,
        syscall_name: ""
    }
    return ctx
}

func set_syscall_return(syscall_context* ctx, int value) {
    ctx.return_value = value
    ctx.frame.rax = value as int64
}

func set_syscall_error(syscall_context* ctx, int error_code) {
    ctx.errno = error_code
    ctx.frame.rax = (-error_code) as int64
}

func get_syscall_arg1(syscall_context* ctx) int64 {
    return ctx.frame.rdi
}

func get_syscall_arg2(syscall_context* ctx) int64 {
    return ctx.frame.rsi
}

func get_syscall_arg3(syscall_context* ctx) int64 {
    return ctx.frame.rdx
}

func get_syscall_arg4(syscall_context* ctx) int64 {
    return ctx.frame.r10
}

func get_syscall_arg5(syscall_context* ctx) int64 {
    return ctx.frame.r8
}

func get_syscall_arg6(syscall_context* ctx) int64 {
    return ctx.frame.r9
}

func syscall_stats_create() syscall_stats {
    stats := syscall_stats {
        total_syscalls: 0,
        total_time_ns: 0,
        errors: 0,
        by_type: [256]int64{}
    }
    return stats
}
