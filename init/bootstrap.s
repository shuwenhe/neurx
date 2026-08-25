package neurx.init

use std.vec.vec
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

func kernel_main() (core_system, string) {
    let hal_cap = hal::detect_platform_capability()?
    
    let mem_pool = allocator::create_memory_pool(16384)?
    
    let task_scheduler = sched::create_scheduler()?
    
    let monitor_service = monitor::create_monitoring_service(1000)?
    
    let rpc_srv = rpc_framework::create_rpc_server(8080)?
    
    let state = system_state {
        is_running: true,
        active_task_count: 0,
        memory_usage_mb: 0,
        gpu_utilization: 0,
        inference_request_count: 0,
        training_task_count: 0
    }
    
    let core = core_system {
        state: &mut state,
        mem_pool: mem_pool,
        task_scheduler: task_scheduler,
        monitor_service: monitor_service,
        rpc_srv: rpc_srv
    }
    
    rpc_framework::start_rpc_server(&core.rpc_srv)?
    
    (core, "")
}

func run_main_event_loop(core_system* core) (int, string) {
    while core->state->is_running {
        let scheduled_task = sched::schedule_next_task(core->task_scheduler)?
        
        if scheduled_task > 0 {
            core->state->active_task_count = core->state->active_task_count + 1
        }
        
        monitor::collect_metrics(core->monitor_service)?
        
        rpc_framework::process_rpc_requests(core->rpc_srv)?
        
        sched::advance_scheduler_clock(core->task_scheduler)?
    }
    
    (0, "")
}

func init_platform_backends(core_system* core) (int, string) {
    let hal_cap = hal::detect_platform_capability()?
    
    if hal_cap.gpu_count > 0 {
        backend_selector::select_and_init_gpu_backend(&hal_cap)?
    }
    
    if hal_cap.cpu_count > 0 {
        backend_selector::init_cpu_backend(&hal_cap)?
    }
    
    (0, "")
}

func add_system_task(core_system* core, int task_type_id, int priority) (int, string) {
    let task_id = sched::schedule_task(core->task_scheduler, task_type_id, priority)?
    
    core->state->active_task_count = core->state->active_task_count + 1
    
    (task_id, "")
}

func shutdown_system(core_system* core) (int, string) {
    core->state->is_running = false
    
    monitor::flush_metrics(core->monitor_service)?
    
    rpc_framework::stop_rpc_server(core->rpc_srv)?
    
    sched::shutdown_scheduler(core->task_scheduler)?
    
    allocator::cleanup_memory_pool(core->mem_pool)?
    
    (0, "")
}

func get_system_status(core_system* core) system_state {
    core->state*
}

func update_system_metrics(core_system* core, int inference_count, int training_count) {
    core->state->inference_request_count = inference_count
    core->state->training_task_count = training_count
}
