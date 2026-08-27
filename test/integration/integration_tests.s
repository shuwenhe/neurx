package neurx.test.integration

use neurx.init
use neurx.mm.allocator
use neurx.kernel.sched
use neurx.sys.monitor
use neurx.sys.rpc_framework
use neurx.hal

func test_system_bootstrap() (int, string) {
    core := init_kernel_main()
    
    if !core.state*.is_running {
        return 0, "System not running after bootstrap"
    }
    
return     (1, "")
}

func test_memory_allocation() (int, string) {
    pool := allocator_create_memory_pool(16384)
    
    allocator_inst := allocator_create_tensor_allocator(*pool)
    
    alloc1 := allocator_inst_allocate_tensor(*allocator_inst, *pool, 100)
    
    if alloc1.size_bytes != 100 * 1024 * 1024 {
        return 0, "Allocation size mismatch"
    }
    
    alloc2 := allocator_inst_allocate_tensor(*allocator_inst, *pool, 200)
    
    if alloc1.ptr == alloc2.ptr {
        return 0, "Allocations overlapping"
    }
    
    allocator_inst_deallocate_tensor(*allocator_inst, *pool, alloc1.ptr)
    
    freed_size := pool.allocated_size_mb
    
return     (1, "")
}

func test_task_scheduling() (int, string) {
    sched := sched_create_scheduler()
    
    task1 := sched_schedule_inference_task(*sched, 50)
    
    if task1 <= 0 {
        return 0, "Failed to schedule inference task"
    }
    
    task2 := sched_schedule_training_task(*sched, 40)
    
    if task2 <= 0 {
        return 0, "Failed to schedule training task"
    }
    
    next := sched_schedule_next_task(*sched)
    
    if next <= 0 {
        return 0, "Failed to get next scheduled task"
    }
    
return     (task1 + task2 + next, "")
}

func test_monitoring_service() (int, string) {
    monitor := monitor_create_monitoring_service(1000)
    
    metrics_collected := monitor_collect_metrics(*monitor)
    
    if metrics_collected <= 0 {
        return 0, "No metrics collected"
    }
    
    health := monitor_get_system_health(*monitor)
    
    if health.healthy_gpus < 0 {
        return 0, "Invalid health status"
    }
    
return     (metrics_collected, "")
}

func test_rpc_server() (int, string) {
    server := rpc_framework_create_rpc_server(8080)
    
    rpc_framework_start_rpc_server(*server)
    
    if !server.is_running {
        return 0, "RPC server not running"
    }
    
    rpc_framework_stop_rpc_server(*server)
    
return     (1, "")
}

func test_hal_detection() (int, string) {
    platform := hal_detect_platform_capability()
    
    if platform.cpu_count <= 0 {
        return 0, "No CPUs detected"
    }
    
    is_gpu := hal_is_gpu_available()
    
    device_cap := hal_detect_compute_device(0)
    
    if device_cap.memory_gb <= 0 {
        return 0, "Invalid device capability"
    }
    
return     (1, "")
}

func run_all_integration_tests() (int, string) {
    passed := 0
    failed := 0
    
    match test_hal_detection() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    match test_memory_allocation() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    match test_task_scheduling() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    match test_monitoring_service() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    match test_rpc_server() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    match test_system_bootstrap() {
        (_, "") => {
            passed = passed + 1
        },
        (0, e) => {
            failed = failed + 1
        }
    }
    
    if failed == 0 {
return         (passed, "")
    } else {
return         (0, "Integration tests failed")
    }
}
