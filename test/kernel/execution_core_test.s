package neurx.test.kernel

import (
    "neurx.kernel.core.cpu_offline"
    "neurx.kernel.core.cpu_online"
    "neurx.kernel.core.enqueue_task"
    "neurx.kernel.core.execution_core"
    "neurx.kernel.core.execution_core_create"
    "neurx.kernel.core.highres_clock"
    "neurx.kernel.core.highres_clock_create"
    "neurx.kernel.core.highres_clock_update"
    "neurx.kernel.core.schedule_cpu"
    "neurx.kernel.core.scheduler_tick"
    "neurx.kernel.core.select_task"
)

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0

    highres_clock clock = highres_clock_create(24000000)
    clock = highres_clock_update(clock, 24000)
    failures = failures + expect(clock.monotonic_ns == 1000000, "24MHz clock converts to ns")
    clock = highres_clock_update(clock, 12000)
    failures = failures + expect(clock.monotonic_ns == 1000000 && clock.backward_events == 1,
        "monotonic clock rejects backward cycles")

    execution_core core = execution_core_create(4)
    core = cpu_online(core, 0, 0)
    core = cpu_online(core, 1, 2)
    failures = failures + expect(core.online_cpus == 2 && core.apic_id[1] == 2,
        "SMP CPU online and per-CPU APIC state")

    core = enqueue_task(core, 100, 10, -1, 5000000, 1000000)
    core = enqueue_task(core, 101, 20, 1, 4000000, 500000)
    core = enqueue_task(core, 102, 20, 1, 3000000, 500000)
    selected := select_task(core, 1, 0)
    failures = failures + expect(selected == 2, "priority then earliest-deadline selection")

    core = schedule_cpu(core, 1, 0)
    core = scheduler_tick(core, 1, 500000)
    failures = failures + expect(core.running_task[1] == 2 && core.need_reschedule[1],
        "per-CPU runtime and timeslice preemption")

    core = cpu_offline(core, 1)
    failures = failures + expect(core.online_cpus == 1 && core.task_runnable[2] && core.migrations == 1,
        "CPU offline migrates runnable work")
    return failures
}

func _start() int { return main() }
