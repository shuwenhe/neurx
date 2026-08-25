package neurx.test.integration

use neurx.init
use neurx.mm.allocator
use neurx.kernel.sched
use neurx.sys.monitor
use neurx.sys.rpc_framework
use neurx.hal

func test_system_bootstrap() result[int, string] {
    let core = init::kernel_main()?
    
    if !core.state*.is_running {
        return (0, "System not running after bootstrap")
    }
    
    (1, "")
}

func test_memory_allocation() result[int, string] {
    let pool = allocator::create_memory_pool(16384)?
    
    let allocator_inst = allocator::create_tensor_allocator(&pool)?
    
    let alloc1 = allocator_inst::allocate_tensor(&allocator_inst, &pool, 100)?
    
    if alloc1.size_bytes != 100 * 1024 * 1024 {
        return (0, "Allocation size mismatch")
    }
    
    let alloc2 = allocator_inst::allocate_tensor(&allocator_inst, &pool, 200)?
    
    if alloc1.ptr == alloc2.ptr {
        return (0, "Allocations overlapping")
    }
    
    allocator_inst::deallocate_tensor(&allocator_inst, &pool, alloc1.ptr)?
    
    let freed_size = pool.allocated_size_mb
    
    (1, "")
}

func test_task_scheduling() result[int, string] {
    let sched = sched::create_scheduler()?
    
    let task1 = sched::schedule_inference_task(&sched, 50)?
    
    if task1 <= 0 {
        return (0, "Failed to schedule inference task")
    }
    
    let task2 = sched::schedule_training_task(&sched, 40)?
    
    if task2 <= 0 {
        return (0, "Failed to schedule training task")
    }
    
    let next = sched::schedule_next_task(&sched)?
    
    if next <= 0 {
        return (0, "Failed to get next scheduled task")
    }
    
    (task1 + task2 + next, "")
}

func test_monitoring_service() result[int, string] {
    let monitor = monitor::create_monitoring_service(1000)?
    
    let metrics_collected = monitor::collect_metrics(&monitor)?
    
    if metrics_collected <= 0 {
        return (0, "No metrics collected")
    }
    
    let health = monitor::get_system_health(&monitor)
    
    if health.healthy_gpus < 0 {
        return (0, "Invalid health status")
    }
    
    (metrics_collected, "")
}

func test_rpc_server() result[int, string] {
    let server = rpc_framework::create_rpc_server(8080)?
    
    rpc_framework::start_rpc_server(&server)?
    
    if !server.is_running {
        return (0, "RPC server not running")
    }
    
    rpc_framework::stop_rpc_server(&server)?
    
    (1, "")
}

func test_hal_detection() result[int, string] {
    let platform = hal::detect_platform_capability()?
    
    if platform.cpu_count <= 0 {
        return (0, "No CPUs detected")
    }
    
    let is_gpu = hal::is_gpu_available()?
    
    let device_cap = hal::detect_compute_device(0)?
    
    if device_cap.memory_gb <= 0 {
        return (0, "Invalid device capability")
    }
    
    (1, "")
}

func run_all_integration_tests() result[int, string] {
    let passed = 0
    let failed = 0
    
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
        (passed, "")
    } else {
        (0, "Integration tests failed")
    }
}
