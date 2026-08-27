package neurx.init

use std.slices
use std.string.string
use neurx.hal
use neurx.mm.allocator
use neurx.kernel.sched
use neurx.sys.monitor
use neurx.sys.rpc_framework
use neurx.backend_selector

struct system_state {
    bool is_running
    int active_task_count
    int memory_usage_mb
    int gpu_utilization
    int inference_request_count
    int training_task_count
}

struct core_system {
    system_state* state
    memory_pool* mem_pool
    scheduler* task_scheduler
    monitoring_service* monitor_service
    rpc_server* rpc_srv
}

func kernel_main() (core_system) {
    hal_cap := hal_detect_platform_capability()
    
    mem_pool := allocator_create_memory_pool(16384)
    
    task_scheduler := sched_create_scheduler()
    
    monitor_service := monitor_create_monitoring_service(1000)
    
    rpc_srv := rpc_framework_create_rpc_server(8080)
    
    state := system_state {
        is_running: true,
        active_task_count: 0,
        memory_usage_mb: 0,
        gpu_utilization: 0,
        inference_request_count: 0,
        training_task_count: 0
    }
    
    core := core_system {
        state: *state,
        mem_pool: mem_pool,
        task_scheduler: task_scheduler,
        monitor_service: monitor_service,
        rpc_srv rpc_srv
    }
    
    rpc_framework_start_rpc_server(*core.rpc_srv)
    core, ""
}

func run_main_event_loop(core_system* core) (int, string) {
    for core.state.is_running {
        scheduled_task := sched_schedule_next_task(core.task_scheduler)
        
        if scheduled_task > 0 {
            core.state.active_task_count = core.state.active_task_count + 1
        }
        
        monitor_collect_metrics(core.monitor_service)
        
        rpc_framework_process_rpc_requests(core.rpc_srv)
        
        sched_advance_scheduler_clock(core.task_scheduler)
    }
    0, ""
}

func init_platform_backends(core_system* core) (int, string) {
    hal_cap := hal_detect_platform_capability()
    
    if hal_cap.gpu_count > 0 {
        backend_selector_select_and_init_gpu_backend(*hal_cap)
    }
    
    if hal_cap.cpu_count > 0 {
        backend_selector_init_cpu_backend(*hal_cap)
    }
    0, ""
}

func add_system_task(core_system* core, int task_type_id, int priority) (int, string) {
    task_id := sched_schedule_task(core.task_scheduler, task_type_id, priority)
    
    core.state.active_task_count = core.state.active_task_count + 1
    task_id, ""
}

func shutdown_system(core_system* core) (int, string) {
    core.state.is_running = false
    
    monitor_flush_metrics(core.monitor_service)
    
    rpc_framework_stop_rpc_server(core.rpc_srv)
    
    sched_shutdown_scheduler(core.task_scheduler)
    
    allocator_cleanup_memory_pool(core.mem_pool)
    0, ""
}

func get_system_status(core_system* core) system_state {
    core.state*
}

func update_system_metrics(core_system* core, int inference_count, int training_count) {
    core.state.inference_request_count = inference_count
    core.state.training_task_count = training_count
}
