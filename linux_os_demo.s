package main

use neurx.block.io_scheduler_algorithms
use neurx.kernel.irq.interrupt_exception_system
use neurx.kernel.cgroup.cgroup_v2
use neurx.kernel.sched.scheduler_enhanced
use neurx.kernel.virt.container_engine
use neurx.power.power_manager
use neurx.driver.device_manager
use neurx.kernel.bpf.bpf_runtime
use neurx.kernel.trace.ftrace_system
use neurx.linux_os_integration

func main() {
    neurx_demo_linux_os()
}

func neurx_demo_linux_os() {
    print("=" + "=" * 78)
    print("NeurX: AI Operating System - Linux Architecture Integration Demo")
    print("=" + "=" * 78)
    print("")
    
    os := linux_os_create(128, 1024000)
    os.initialize_all_subsystems()?
    
    print("1. BLOCK DEVICE I/O SCHEDULING")
    print("   ================================")
    demo_block_io()
    print("")
    
    print("2. INTERRUPT & EXCEPTION HANDLING")
    print("   ================================")
    demo_irq_exceptions()
    print("")
    
    print("3. CGROUP v2 RESOURCE MANAGEMENT")
    print("   ================================")
    demo_cgroups()
    print("")
    
    print("4. ADVANCED CPU SCHEDULING (CFS/RT/Deadline)")
    print("   ================================")
    demo_scheduler()
    print("")
    
    print("5. CONTAINER VIRTUALIZATION")
    print("   ================================")
    demo_containers()
    print("")
    
    print("6. POWER MANAGEMENT (CPUFreq/CPUidle)")
    print("   ================================")
    demo_power_management()
    print("")
    
    print("7. DEVICE MANAGEMENT & HOTPLUG")
    print("   ================================")
    demo_device_management()
    print("")
    
    print("8. BPF RUNTIME (In-Kernel VM)")
    print("   ================================")
    demo_bpf()
    print("")
    
    print("9. FTRACE SYSTEM (Kernel Tracing)")
    print("   ================================")
    demo_tracing()
    print("")
    
    print("10. SYSTEM INTEGRATION STATUS")
    print("    ================================")
    print(os.system_info())
    print(os.feature_status())
    
    flags := os.get_capability_flags()?
    print("Capability flags: " + flags as string)
    
    print("")
    print("=" + "=" * 78)
    print("NeurX Linux OS Integration Complete ✓")
    print("=" + "=" * 78)
}

func demo_block_io() {
    cfq := cfq_create()
    
    req1 := io_queue_entry {
        request_id: 1,
        device_id: 0,
        sector_offset: 0,
        sector_count: 4096,
        is_read: true,
        priority: 5,
        arrival_time_us: 0,
        start_time_us: 0
    }
    
    cfq.cfq_add_request(req1)
    
    switch cfq.cfq_dispatch_request() {
        result::ok(req) : {
            print("   CFQ dispatched read request: sectors=" + req.sector_count as string)
            cfq.cfq_request_complete(req)
            print("   Request completed. Total requests: " + cfq.stats.total_requests as string)
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    deadline := deadline_create()
    req2 := io_queue_entry {
        request_id: 2,
        device_id: 1,
        sector_offset: 8192,
        sector_count: 2048,
        is_read: false,
        priority: 3,
        arrival_time_us: 0,
        start_time_us: 0
    }
    
    deadline.deadline_add_request(req2)
    
    switch deadline.deadline_dispatch() {
        result::ok(req) : {
            print("   Deadline dispatched write request: sectors=" + req.sector_count as string)
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   I/O Scheduler: CFQ/Deadline operational")
}

func demo_irq_exceptions() {
    ctrl := interrupt_controller_create()
    
    switch ctrl.register_handler(32, "timer_irq", interrupt_type::hardware_interrupt, 10) {
        result::ok(irq_num) : {
            print("   Registered IRQ " + irq_num as string + ": timer")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch ctrl.register_handler(33, "network_irq", interrupt_type::hardware_interrupt, 5) {
        result::ok(irq_num) : {
            print("   Registered IRQ " + irq_num as string + ": network")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch ctrl.handle_interrupt(32) {
        result::ok(num) : {
            print("   Handled interrupt " + num as string)
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    mgr := exception_manager_create()
    
    switch mgr.register_exception_handler(0, "divide_by_zero") {
        result::ok(num) : {
            print("   Registered exception " + num as string + ": divide_by_zero")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   Interrupt/Exception system operational: " + mgr.exception_stats())
}

func demo_cgroups() {
    hier := cgroup_hierarchy_v2_create("system")
    
    switch hier.add_cgroup("apps", 0) {
        result::ok(cg_id) : {
            print("   Created cgroup 'apps' (ID: " + cg_id as string + ")")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch hier.add_cgroup("services", 0) {
        result::ok(cg_id) : {
            print("   Created cgroup 'services' (ID: " + cg_id as string + ")")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   cgroups v2: " + hier.total_cgroups as string + " groups, CPU=" + hier.total_cpu_usage() as string + "us, Mem=" + hier.total_memory_used() as string + "B")
}

func demo_scheduler() {
    sched := scheduler_create(128)
    
    task1 := task_struct {
        pid: 1000,
        comm: "inference_engine",
        policy: sched_class::sched_normal,
        prio: 120,
        nice: 0,
        se: se_stats {
            vruntime: 0,
            sum_exec_runtime: 0,
            exec_start: 0,
            prev_sum_exec_runtime: 0
        },
        cpu_id: 0,
        state: 0,
        flags: 0
    }
    
    sched.enqueue_task(0, task1)?
    print("   Enqueued task pid=1000 on CPU 0")
    
    switch sched.pick_next_task(0) {
        option::some(task) : {
            print("   Picked next task: " + task.comm + " (pid=" + task.pid as string + ")")
        }
        option::none : {
            print("   No task to run")
        }
    }
    
    print("   CFS Scheduler: " + sched.cpu_stats(0))
}

func demo_containers() {
    engine := container_engine_create()
    
    switch engine.create_container("container_01", "neurx-inference:latest") {
        result::ok(config) : {
            print("   Created container: " + config.container_id)
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch engine.start_container("container_01", 5001) {
        result::ok(_) : {
            print("   Started container container_01 with PID 5001")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   Container Engine: " + engine.total_stats())
}

func demo_power_management() {
    mgr := power_manager_create(128)
    
    switch mgr.set_cpufreq_governor(0, cpu_freq_governor::schedutil) {
        result::ok(_) : {
            print("   CPU 0: Set governor to schedutil")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch mgr.scale_cpu_frequency(0, 2400) {
        result::ok(old_freq) : {
            print("   CPU 0: Scaled frequency from " + old_freq as string + "MHz to 2400MHz")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch mgr.enter_c_state(1, 2, 5000) {
        result::ok(_) : {
            print("   CPU 1: Entered C2 state for 5000us")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   Power Management: " + mgr.system_idle_stats())
}

func demo_device_management() {
    mgr := device_manager_create()
    
    switch mgr.register_bus("pci") {
        result::ok(_) : {
            print("   Registered PCI bus")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    gpu_dev := device_create("gpu0", "NVIDIA_A100", device_type::device_gpu)
    switch mgr.add_device("pci", gpu_dev) {
        result::ok(_) : {
            print("   Added GPU device: gpu0")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    net_dev := device_create("eth0", "Ethernet", device_type::device_network)
    switch mgr.add_device("pci", net_dev) {
        result::ok(_) : {
            print("   Added Network device: eth0")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   Device Management: " + mgr.device_discovery_stats())
}

func demo_bpf() {
    runtime := bpf_runtime_create()
    
    prog := bpf_program_create(1, "trace_syscalls", bpf_program_type::bpf_tracepoint)
    prog.add_instruction(1, 0, 0, 0, 0)?
    prog.add_instruction(2, 0, 1, 0, 10)?
    prog.add_instruction(95, 0, 0, 0, 0)?
    
    switch runtime.register_program(prog) {
        result::ok(prog_id) : {
            print("   Loaded BPF program " + prog_id as string + ": trace_syscalls")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    bpf_map := bpf_map_create(1, "events", bpf_map_type::bpf_map_type_ringbuf, 8, 256, 16384)
    switch runtime.register_map(bpf_map) {
        result::ok(map_id) : {
            print("   Created BPF map " + map_id as string + ": events")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    print("   BPF Runtime: " + runtime.runtime_stats())
}

func demo_tracing() {
    ctrl := ftrace_controller_create()
    
    switch ctrl.register_tracepoint("sys_enter_read", trace_event_type::event_syscall) {
        result::ok(tp_id) : {
            print("   Registered tracepoint " + tp_id as string + ": sys_enter_read")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch ctrl.register_kprobe("do_page_fault", 0xffffffff81000000) {
        result::ok(kp_id) : {
            print("   Registered kprobe " + kp_id as string + ": do_page_fault")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    switch ctrl.register_kretprobe("kmalloc", 0xffffffff81000100) {
        result::ok(krp_id) : {
            print("   Registered kretprobe " + krp_id as string + ": kmalloc")
        }
        result::err(e) : {
            print("   Error: " + e)
        }
    }
    
    ctrl.enable_tracing()?
    print("   Tracing System: " + ctrl.trace_stats())
}
