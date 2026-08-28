package main

use neurx.distributed.topology.fabric_planner.{fabric_topology_new, fabric_topology_add_node, fabric_request, fabric_plan, fabric_plan_summary}

func expect(bool condition, string name) int {
    if condition {
        println("PASS " + name)
        return 0
    }
    println("FAIL " + name)
    1
}

func main() int {
    topology := fabric_topology_new()
    int node = 0
    for node < 1250 {
        string zone = "zone-a"
        if node >= 625 { zone = "zone-b" }
        topology = fabric_topology_add_node(topology,
            node + 1, zone, "rack-" + itoa(node / 32), "gpu-" + itoa(node),
            "nvidia", "h100", "nccl", 8, 80, 400, true
        )
        node = node + 1
    }
    topology = fabric_topology_add_node(topology,
        2001, "zone-c", "rack-c1", "npu-1", "huawei", "ascend-910b", "hccl", 8, 64, 200, true
    )

    request := fabric_request {
        tensor_parallel_size: 8,
        pipeline_parallel_size: 10,
        data_parallel_size: 125,
        min_device_memory_gb: 80,
        min_fabric_bandwidth_gbps: 400,
        vendor: "nvidia",
        chip_type: "h100",
        collective_backend: "nccl",
    }
    plan := fabric_plan(topology, request)
    failures := 0
    failures = failures + expect(topology.total_devices == 10008, "heterogeneous inventory counted")
    failures = failures + expect(plan.valid, "ten thousand device plan valid")
    failures = failures + expect(plan.world_size == 10000, "world size is ten thousand")
    failures = failures + expect(len(plan.global_ranks) == 10000, "all ranks assigned")
    failures = failures + expect(plan.selected_nodes == 1250, "all compatible nodes selected")
    failures = failures + expect(plan.selected_zones == 2, "failure domains recorded")
    failures = failures + expect(plan.collective_backends[9999] == "nccl", "collective backend homogeneous")
    failures = failures + expect(len(fabric_plan_summary(plan)) > 0, "summary generated")

    request.collective_backend = "hccl"
    rejected := fabric_plan(topology, request)
    failures = failures + expect(!rejected.valid, "incompatible fabric capacity rejected")
    if failures == 0 {
        println("PASS fabric planner")
        return 0
    }
    println("FAIL fabric planner")
    1
}
