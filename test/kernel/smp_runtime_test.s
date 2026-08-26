package neurx.test.kernel

use neurx.kernel.smp.smp_runtime
use neurx.kernel.smp.cpu_context
use neurx.kernel.smp.smp_runtime_create
use neurx.kernel.smp.cpu_context_create
use neurx.kernel.smp.register_madt_cpu
use neurx.kernel.smp.prepare_per_cpu
use neurx.kernel.smp.bsp_online
use neurx.kernel.smp.send_init
use neurx.kernel.smp.send_sipi
use neurx.kernel.smp.ap_online
use neurx.kernel.smp.send_ipi
use neurx.kernel.smp.receive_ipi
use neurx.kernel.smp.set_next_task
use neurx.kernel.smp.apic_timer_tick
use neurx.kernel.smp.CPU_ONLINE
use neurx.kernel.smp.IPI_RESCHEDULE

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0
    smp_runtime runtime = smp_runtime_create()
    runtime = register_madt_cpu(runtime, 0)
    runtime = register_madt_cpu(runtime, 2)
    runtime = prepare_per_cpu(runtime, 0, 2097152, 2162688, 2228224, 2232320)
    runtime = prepare_per_cpu(runtime, 1, 2293760, 2359296, 2424832, 2428928)
    runtime = bsp_online(runtime)
    runtime = send_init(runtime, 1)
    runtime = send_sipi(runtime, 1)
    runtime = send_sipi(runtime, 1)
    runtime = ap_online(runtime, 1)
    failures = failures + expect(runtime.online_count == 2 &&
        runtime.state[1] == CPU_ONLINE() && runtime.sipi_attempts[1] == 2,
        "MADT to INIT-SIPI-SIPI AP online sequence")

    runtime = send_ipi(runtime, 1, IPI_RESCHEDULE())
    runtime = receive_ipi(runtime, 1)
    failures = failures + expect(runtime.need_reschedule[1] &&
        runtime.ipi_sent == 1 && runtime.ipi_received == 1,
        "cross-CPU reschedule IPI mailbox")

    cpu_context next = cpu_context_create()
    next.instruction_pointer = 4194304
    next.stack_pointer = 8388608
    next.address_space = 4096
    runtime = set_next_task(runtime, 1, 42, next)
    runtime = apic_timer_tick(runtime, 1)
    failures = failures + expect(runtime.current_task[1] == 42 &&
        runtime.context_switches == 1 && runtime.timer_ticks[1] == 1,
        "APIC timer commits scheduler context switch")
    return failures
}

func _start() int { return main() }
