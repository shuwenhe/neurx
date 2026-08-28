package main

use neurx.runtime.distributed.topology.{hetero_topology_new, hetero_topology_add_node, hetero_topology_mark_failed, hetero_topology_select_node, hetero_topology_place_workload, hetero_build_launch_plan, hetero_build_multi_launch_plan, hetero_multi_launch_script, hetero_default_capability, hetero_topology_summary, hetero_placement_summary, hetero_launch_summary, hetero_multi_launch_summary}

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
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(3, "npu-01", "10.0.0.3", 9002, hetero_default_capability("huawei", "ascend", 8, 32), true))
    failures := 0
    failures = failures + expect(topo.valid, "topology valid")
    failures = failures + expect(topo.world_size == 20, "world size")
    failures = failures + expect(hetero_topology_select_node(topo, "amd", "", 1, 1) == 2, "select rocm node")
    placement := hetero_topology_place_workload(topo, "nvidia", "h100", 1, 1)
    failures = failures + expect(placement.launchable, "placement launchable")
    failures = failures + expect(placement.node_id == 1, "placement node id")
    launch := hetero_build_launch_plan(placement, "neurx-worker", "127.0.0.1", 29500, topo.world_size)
    failures = failures + expect(launch.valid, "launch plan valid")
    failures = failures + expect(len(launch.command) > 0, "launch command generated")
    multi_launch := hetero_build_multi_launch_plan(topo, "nvidia", "h100", "neurx-worker", "127.0.0.1", 29500, 1, 1)
    failures = failures + expect(multi_launch.valid, "multi launch valid")
    failures = failures + expect(multi_launch.world_size == 8, "filtered world size")
    failures = failures + expect(len(multi_launch.commands) == 8, "one command per device")
    failures = failures + expect(multi_launch.commands[0].global_rank == 0, "first global rank")
    failures = failures + expect(multi_launch.commands[7].global_rank == 7, "last global rank")
    failures = failures + expect(multi_launch.commands[7].local_rank == 7, "local rank per device")
    failures = failures + expect(multi_launch.commands[7].device_id == 7, "device id per rank")
    failures = failures + expect(len(hetero_multi_launch_script(multi_launch)) > 0, "multi launch script")
    topo = hetero_topology_mark_failed(topo, 2)
    failures = failures + expect(hetero_topology_select_node(topo, "amd", "", 1, 1) == 0 - 1, "failed node skipped")
    failures = failures + expect(len(hetero_topology_summary(topo)) > 0, "summary generated")
    failures = failures + expect(len(hetero_placement_summary(placement)) > 0, "placement summary generated")
    failures = failures + expect(len(hetero_launch_summary(launch)) > 0, "launch summary generated")
    failures = failures + expect(len(hetero_multi_launch_summary(multi_launch)) > 0, "multi launch summary generated")
    if failures == 0 {
        println("PASS hetero topology")
        return 0
    }
    println("FAIL hetero topology")
    1
}
