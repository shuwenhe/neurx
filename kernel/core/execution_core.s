package neurx.kernel.core

func MAX_CPUS() int { 64 }
func MAX_TASKS() int { 1024 }
func NO_CPU() int { -1 }
func NO_TASK() int { -1 }

struct highres_clock {
    int frequency_hz
    int last_cycles
    int monotonic_ns
    int remainder
    int backward_events
}

struct execution_core {
    int possible_cpus
    int online_cpus
    bool[64] cpu_online
    int[64] apic_id
    int[64] running_task
    int[64] cpu_runtime_ns
    bool[64] need_reschedule

    int task_count
    int[1024] task_id
    int[1024] task_priority
    int[1024] task_affinity
    int[1024] task_deadline_ns
    int[1024] task_runtime_ns
    int[1024] task_slice_ns
    bool[1024] task_runnable
    int context_switches
    int migrations
}

func highres_clock_create(int frequency_hz) highres_clock {
    highres_clock {
        frequency_hz: frequency_hz,
        last_cycles: 0,
        monotonic_ns: 0,
        remainder: 0,
        backward_events: 0
    }
}

func highres_clock_update(highres_clock clock, int cycles) highres_clock {
    if cycles < clock.last_cycles {
        clock.backward_events = clock.backward_events + 1
        return clock
    }
    delta := cycles - clock.last_cycles
    scaled := delta * 1000000000 + clock.remainder
    clock.monotonic_ns = clock.monotonic_ns + scaled / clock.frequency_hz
    clock.remainder = scaled % clock.frequency_hz
    clock.last_cycles = cycles
    return clock
}

func execution_core_create(int possible_cpus) execution_core {
    execution_core core = execution_core {
        possible_cpus: possible_cpus,
        online_cpus: 0,
        cpu_online: bool[64]{},
        apic_id: int[64]{},
        running_task: int[64]{},
        cpu_runtime_ns: int[64]{},
        need_reschedule: bool[64]{},
        task_count: 0,
        task_id: int[1024]{},
        task_priority: int[1024]{},
        task_affinity: int[1024]{},
        task_deadline_ns: int[1024]{},
        task_runtime_ns: int[1024]{},
        task_slice_ns: int[1024]{},
        task_runnable: bool[1024]{},
        context_switches: 0,
        migrations: 0
    }
    int cpu = 0
    for cpu < MAX_CPUS() {
        core.running_task[cpu] = NO_TASK()
        core.apic_id[cpu] = -1
        cpu = cpu + 1
    }
    return core
}

func cpu_online(execution_core core, int cpu, int apic) execution_core {
    if cpu < 0 || cpu >= core.possible_cpus || cpu >= MAX_CPUS() { return core }
    if !core.cpu_online[cpu] {
        core.cpu_online[cpu] = true
        core.apic_id[cpu] = apic
        core.online_cpus = core.online_cpus + 1
    }
    return core
}

func enqueue_task(execution_core core, int id, int priority, int affinity,
                  int deadline_ns, int slice_ns) execution_core {
    if core.task_count >= MAX_TASKS() { return core }
    slot := core.task_count
    core.task_id[slot] = id
    core.task_priority[slot] = priority
    core.task_affinity[slot] = affinity
    core.task_deadline_ns[slot] = deadline_ns
    core.task_runtime_ns[slot] = 0
    core.task_slice_ns[slot] = slice_ns
    core.task_runnable[slot] = true
    core.task_count = core.task_count + 1
    return core
}

func select_task(execution_core core, int cpu, int now_ns) int {
    int selected = -1
    int selected_priority = -1
    int selected_deadline = 0
    int i = 0
    for i < core.task_count {
        affinity_ok := core.task_affinity[i] == NO_CPU() || core.task_affinity[i] == cpu
        if core.task_runnable[i] && affinity_ok {
            deadline := core.task_deadline_ns[i]
            better_priority := core.task_priority[i] > selected_priority
            same_priority_earlier_deadline := core.task_priority[i] == selected_priority &&
                deadline > 0 && (selected_deadline == 0 || deadline < selected_deadline)
            if better_priority || same_priority_earlier_deadline {
                selected = i
                selected_priority = core.task_priority[i]
                selected_deadline = deadline
            }
        }
        i = i + 1
    }
    return selected
}

func schedule_cpu(execution_core core, int cpu, int now_ns) execution_core {
    if cpu < 0 || cpu >= core.possible_cpus || !core.cpu_online[cpu] { return core }
    selected := select_task(core, cpu, now_ns)
    if selected < 0 { return core }
    old := core.running_task[cpu]
    if old >= 0 && old < core.task_count {
        core.task_runnable[old] = true
    }
    core.task_runnable[selected] = false
    core.running_task[cpu] = selected
    core.need_reschedule[cpu] = false
    core.context_switches = core.context_switches + 1
    return core
}

func scheduler_tick(execution_core core, int cpu, int elapsed_ns) execution_core {
    if cpu < 0 || cpu >= core.possible_cpus || !core.cpu_online[cpu] { return core }
    core.cpu_runtime_ns[cpu] = core.cpu_runtime_ns[cpu] + elapsed_ns
    running := core.running_task[cpu]
    if running >= 0 && running < core.task_count {
        core.task_runtime_ns[running] = core.task_runtime_ns[running] + elapsed_ns
        if core.task_runtime_ns[running] >= core.task_slice_ns[running] {
            core.need_reschedule[cpu] = true
        }
    }
    return core
}

func cpu_offline(execution_core core, int cpu) execution_core {
    if cpu <= 0 || cpu >= core.possible_cpus || !core.cpu_online[cpu] { return core }
    running := core.running_task[cpu]
    if running >= 0 && running < core.task_count {
        core.task_runnable[running] = true
        core.migrations = core.migrations + 1
    }
    core.running_task[cpu] = NO_TASK()
    core.cpu_online[cpu] = false
    core.online_cpus = core.online_cpus - 1
    return core
}
