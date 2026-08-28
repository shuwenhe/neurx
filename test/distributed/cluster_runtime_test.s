package main

use neurx.distributed.cluster.{cluster_default_cuda_capability, create_cluster_runtime, cluster_register_node, cluster_select_node, cluster_assign_request, cluster_release_request, cluster_workload_request, cluster_healthy_node_count, cluster_total_device_count}

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
    failures := 0
    cluster := create_cluster_runtime("neurx-test-cluster", 4096)
    cluster = cluster_register_node(cluster, "node-a", "10.0.0.1", 9000, 0, 0, cluster_default_cuda_capability(8, 80))
    cluster = cluster_register_node(cluster, "node-b", "10.0.0.2", 9001, 1, 0, cluster_default_cuda_capability(4, 40))

    failures = failures + expect(cluster_healthy_node_count(cluster) == 2, "healthy node count")
    failures = failures + expect(cluster_total_device_count(cluster) == 12, "total device count")

    request := cluster_workload_request{
        workload_id: "req-1",
        model_id: "qwen2.5",
        min_device_count: 4,
        min_memory_gb: 32,
        require_graph_capture: true,
        require_speculative_decode: false,
        require_fp8: true,
        require_distributed: true,
    }

    placement := cluster_select_node(cluster, request)
    failures = failures + expect(placement.scheduled, "placement scheduled")
    failures = failures + expect(placement.node_name == "node-a", "best node selected")
    failures = failures + expect(placement.backend == "nccl", "backend selected")

    cluster = cluster_assign_request(cluster, request)
    failures = failures + expect(cluster_select_node(cluster, request).scheduled, "assignment preserves schedulability")

    cluster = cluster_release_request(cluster, 1)
    failures = failures + expect(cluster_select_node(cluster, request).scheduled, "release preserves schedulability")

    if failures == 0 {
        println("PASS cluster runtime")
        return 0
    }
    println("FAIL cluster runtime")
    1
}
