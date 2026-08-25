package neurx.init

use std.vec.vec
use std.string.string

struct boot_context {
    int cpu_count
    int gpu_count
    int mem_total_gb
    string boot_args
    bool secure_boot
}

func init_system() boot_context {
    let ctx = boot_context {
        cpu_count: detect_cpu_count(),
        gpu_count: detect_gpu_count(),
        mem_total_gb: detect_total_memory(),
        boot_args: get_boot_args(),
        secure_boot: is_secure_boot_enabled()
    }
    
    init_early_subsystems(ctx)
    
    ctx
}

func detect_cpu_count() int {
    1
}

func detect_gpu_count() int {
    0
}

func detect_total_memory() int {
    16
}

func get_boot_args() string {
    ""
}

func is_secure_boot_enabled() bool {
    false
}

func init_early_subsystems(ctx: boot_context) {
}
