package main

use neurx.distributed.cluster.parallel_plan.{cluster_parallel_request, cluster_parallel_plan_for, cluster_parallel_plan_ready, cluster_parallel_plan_summary}

func expect(bool condition, string name) int {
    if condition {
        print("PASS ")
        print(name)
        return 0
    }
    print("FAIL ")
    print(name)
    return 1
}

func main() int {
    request := cluster_parallel_request{
        model_id: "qwen2.5",
        num_layers: 80,
        min_device_count: 8,
        min_memory_gb: 80,
        require_graph_capture: true,
        require_speculative_decode: true,
        require_fp8: true,
        require_distributed: true,
    }
    plan := cluster_parallel_plan_for(request, 8, 10, 1, 80, "nccl")
    failures := 0
    failures = failures + expect(cluster_parallel_plan_ready(plan), "plan ready")
    failures = failures + expect(len(plan.stages) == 10, "pp stages")
    failures = failures + expect(len(plan.ranks) == 80, "rank count")
    failures = failures + expect(len(cluster_parallel_plan_summary(plan)) > 0, "summary generated")
    if failures == 0 {
        println("PASS cluster parallel plan")
        return 0
    }
    println("FAIL cluster parallel plan")
    1
}
