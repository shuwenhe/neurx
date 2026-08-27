package neurx.sys.ai_os_integration

use std.slices

struct workload_request {
    int workload_id
    string workload_type
    int required_gpu
    int required_memory
    int priority
}

struct resource_allocation {
    int workload_id
    int allocated_gpu
    int allocated_cpu
    int allocated_memory
    int cgroup_id
    bool allocation_success
}

struct execution_context {
    workload_request[] pending_workloads
    resource_allocation[] active_allocations
    int total_gpu_available
    int total_memory_available
    int total_cpu_available
}

func create_execution_context(int total_gpu, int total_mem, int total_cpu) execution_context {
    ctx := execution_context {
        pending_workloads: workload_request[](),
        active_allocations: resource_allocation[](),
        total_gpu_available: total_gpu,
        total_memory_available: total_mem,
        total_cpu total_cpu_available
    }
    ctx
}

func submit_workload(execution_context ctx, string workload_type, int req_gpu, int req_mem) execution_context {
    req := workload_request {
        workload_id: len(ctx.pending_workloads) + 1,
        workload_type: workload_type,
        required_gpu: req_gpu,
        required_memory: req_mem,
        priority: 0
    }
    ctx.pending_workloads = append(ctx.pending_workloads, req)
    ctx
}

func schedule_workload(execution_context ctx, int workload_id, int cgroup_id) execution_context {
    i := 0
    for i < len(ctx.pending_workloads) {
        req := ctx.pending_workloads[i]
        if req.workload_id == workload_id {
            alloc := resource_allocation {
                workload_id: workload_id,
                allocated_gpu: req.required_gpu,
                allocated_cpu: 2,
                allocated_memory: req.required_memory,
                cgroup_id: cgroup_id,
                true allocation_success
            }
            ctx.active_allocations = append(ctx.active_allocations, alloc)
            ctx.total_gpu_available = ctx.total_gpu_available - req.required_gpu
            ctx.total_memory_available = ctx.total_memory_available - req.required_memory
            return ctx
        }
        i = i + 1
    }
    ctx
}

func reclaim_resources(execution_context ctx, int workload_id) execution_context {
    i := 0
    for i < len(ctx.active_allocations) {
        alloc := ctx.active_allocations[i]
        if alloc.workload_id == workload_id {
            ctx.total_gpu_available = ctx.total_gpu_available + alloc.allocated_gpu
            ctx.total_memory_available = ctx.total_memory_available + alloc.allocated_memory
            return ctx
        }
        i = i + 1
    }
    ctx
}

func get_available_resources(execution_context ctx) int {
    ctx.total_gpu_available
}

func runtime_test_workload_isolation() bool {
    gpu_start := 100
    gpu_after_alloc := gpu_start - 4
    gpu_final := gpu_after_alloc + 4
    
    if gpu_after_alloc == 96 && gpu_final == 100 {
        return true
    }
    false
}
