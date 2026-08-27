package neurx.kernel.smp

func CPU_ABSENT() int { 0 }
func CPU_DISCOVERED() int { 1 }
func CPU_PREPARED() int { 2 }
func CPU_INIT_SENT() int { 3 }
func CPU_SIPI_SENT() int { 4 }
func CPU_ONLINE() int { 5 }
func CPU_FAILED() int { 6 }

func IPI_RESCHEDULE() int { 1 }
func IPI_CALL_FUNCTION() int { 2 }
func IPI_CPU_STOP() int { 4 }

struct cpu_context {
    int instruction_pointer
    int stack_pointer
    int flags
    int address_space
    int task_id
}

struct smp_runtime {
    int cpu_count
    int online_count
    int[64] apic_id
    int[64] state
    int[64] sipi_attempts
    int[64] kernel_stack_top
    int[64] interrupt_stack_top
    int[64] gdt_address
    int[64] tss_address
    int[64] ipi_pending
    int[64] current_task
    int[64] next_task
    int[64] timer_ticks
    bool[64] need_reschedule
    [64]cpu_context context
    int context_switches
    int ipi_sent
    int ipi_received
}

func cpu_context_create() cpu_context {
    cpu_context {
        instruction_pointer: 0, stack_pointer: 0, flags: 514,
        address_space: 0, task_id: -1
    }
}

func smp_runtime_create() smp_runtime {
    smp_runtime runtime = smp_runtime {
        cpu_count: 0, online_count: 0,
        apic_id: int[64]{}, state: int[64]{}, sipi_attempts: int[64]{},
        kernel_stack_top: int[64]{}, interrupt_stack_top: int[64]{},
        gdt_address: int[64]{}, tss_address: int[64]{},
        ipi_pending: int[64]{}, current_task: int[64]{}, next_task: int[64]{},
        timer_ticks: int[64]{}, need_reschedule: bool[64]{},
        context: [64]cpu_context{}, context_switches: 0,
        ipi_sent: 0, ipi_received: 0
    }
    int cpu = 0
    for cpu < 64 {
        runtime.apic_id[cpu] = -1
        runtime.current_task[cpu] = -1
        runtime.next_task[cpu] = -1
        runtime.context[cpu] = cpu_context_create()
        cpu = cpu + 1
    }
    return runtime
}


func register_madt_cpu(smp_runtime runtime, int apic) smp_runtime {
    if runtime.cpu_count >= 64 { return runtime }
    slot := runtime.cpu_count
    runtime.apic_id[slot] = apic
    runtime.state[slot] = CPU_DISCOVERED()
    runtime.cpu_count = runtime.cpu_count + 1
    return runtime
}

func prepare_per_cpu(smp_runtime runtime, int cpu, int kernel_stack,
                     int interrupt_stack, int gdt, int tss) smp_runtime {
    if cpu < 0 || cpu >= runtime.cpu_count { return runtime }
    runtime.kernel_stack_top[cpu] = kernel_stack
    runtime.interrupt_stack_top[cpu] = interrupt_stack
    runtime.gdt_address[cpu] = gdt
    runtime.tss_address[cpu] = tss
    runtime.state[cpu] = CPU_PREPARED()
    return runtime
}

func bsp_online(smp_runtime runtime) smp_runtime {
    if runtime.cpu_count == 0 { return runtime }
    runtime.state[0] = CPU_ONLINE()
    runtime.online_count = 1
    return runtime
}

func send_init(smp_runtime runtime, int cpu) smp_runtime {
    if cpu <= 0 || cpu >= runtime.cpu_count { return runtime }
    if runtime.state[cpu] != CPU_PREPARED() { return runtime }
    runtime.state[cpu] = CPU_INIT_SENT()
    return runtime
}

func send_sipi(smp_runtime runtime, int cpu) smp_runtime {
    if cpu <= 0 || cpu >= runtime.cpu_count { return runtime }
    if runtime.state[cpu] != CPU_INIT_SENT() && runtime.state[cpu] != CPU_SIPI_SENT() {
        return runtime
    }
    runtime.sipi_attempts[cpu] = runtime.sipi_attempts[cpu] + 1
    runtime.state[cpu] = CPU_SIPI_SENT()
    return runtime
}

func ap_online(smp_runtime runtime, int cpu) smp_runtime {
    if cpu <= 0 || cpu >= runtime.cpu_count { return runtime }
    if runtime.state[cpu] == CPU_SIPI_SENT() {
        runtime.state[cpu] = CPU_ONLINE()
        runtime.online_count = runtime.online_count + 1
    }
    return runtime
}

func send_ipi(smp_runtime runtime, int cpu, int reason) smp_runtime {
    if cpu < 0 || cpu >= runtime.cpu_count || runtime.state[cpu] != CPU_ONLINE() {
        return runtime
    }
    runtime.ipi_pending[cpu] = runtime.ipi_pending[cpu] + reason
    runtime.ipi_sent = runtime.ipi_sent + 1
    return runtime
}

func receive_ipi(smp_runtime runtime, int cpu) smp_runtime {
    if cpu < 0 || cpu >= runtime.cpu_count { return runtime }
    pending := runtime.ipi_pending[cpu]
    if pending > 0 {
        if pending == IPI_RESCHEDULE() { runtime.need_reschedule[cpu] = true }
        if pending == IPI_CPU_STOP() { runtime.state[cpu] = CPU_FAILED() }
        runtime.ipi_pending[cpu] = 0
        runtime.ipi_received = runtime.ipi_received + 1
    }
    return runtime
}

func set_next_task(smp_runtime runtime, int cpu, int task_id,
                   cpu_context next_context) smp_runtime {
    if cpu < 0 || cpu >= runtime.cpu_count { return runtime }
    runtime.next_task[cpu] = task_id
    runtime.context[cpu] = next_context
    runtime.need_reschedule[cpu] = true
    return runtime
}



func apic_timer_tick(smp_runtime runtime, int cpu) smp_runtime {
    if cpu < 0 || cpu >= runtime.cpu_count || runtime.state[cpu] != CPU_ONLINE() {
        return runtime
    }
    runtime.timer_ticks[cpu] = runtime.timer_ticks[cpu] + 1
    if runtime.need_reschedule[cpu] && runtime.next_task[cpu] >= 0 {
        runtime.current_task[cpu] = runtime.next_task[cpu]
        cpu_context switched = runtime.context[cpu]
        switched.task_id = runtime.next_task[cpu]
        runtime.context[cpu] = switched
        runtime.next_task[cpu] = -1
        runtime.need_reschedule[cpu] = false
        runtime.context_switches = runtime.context_switches + 1
    }
    return runtime
}
