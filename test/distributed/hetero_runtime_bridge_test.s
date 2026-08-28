package main

use neurx.runtime.distributed.topology.{hetero_topology_new, hetero_topology_add_node, hetero_topology_node_new, hetero_default_capability}
use neurx.deployment.hetero_runtime_bridge.{bridge_hetero_launch_summary}

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
    topo := hetero_topology_new("neurx-dc")
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(1, "cuda-01", "10.0.0.1", 9000, hetero_default_capability("nvidia", "h100", 8, 80), true))
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(2, "rocm-01", "10.0.0.2", 9001, hetero_default_capability("amd", "mi300", 4, 64), true))
    summary := bridge_hetero_launch_summary(topo, "nvidia", "h100", "neurx-worker", "127.0.0.1", 29500, 1, 1)
    failures := 0
    failures = failures + expect(len(summary) > 0, "bridge summary generated")
    failures = failures + expect(summary[0] == 99, "bridge summary prefix")
    if failures == 0 {
        println("PASS hetero runtime bridge")
        return 0
    }
    println("FAIL hetero runtime bridge")
    1
}
