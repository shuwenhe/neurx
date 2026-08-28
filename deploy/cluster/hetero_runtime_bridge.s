package neurx.deployment.hetero_runtime_bridge

use neurx.runtime.distributed.topology.{hetero_topology, hetero_placement_result, hetero_topology_new, hetero_topology_add_node, hetero_topology_node_new, hetero_default_capability, hetero_topology_place_workload, hetero_build_launch_plan, hetero_build_multi_launch_plan, hetero_launch_summary, hetero_multi_launch_summary, hetero_multi_launch_script, hetero_placement_summary, hetero_topology_summary}

struct hetero_runtime_bridge_result {
    hetero_placement_result placement
    string placement_summary
    string launch_summary
    string multi_launch_summary
    string multi_launch_script
    bool ready
}

func bridge_hetero_launch(hetero_topology topo, string vendor, string chip_type, string worker_bin, string master_addr, int master_port, int min_devices, int min_memory_gb) hetero_runtime_bridge_result {
    hetero_placement_result placement = hetero_topology_place_workload(topo, vendor, chip_type, min_devices, min_memory_gb)
    hetero_runtime_bridge_result result
    result.placement = placement
    result.placement_summary = hetero_placement_summary(placement)
    result.ready = placement.launchable
    result.launch_summary = hetero_launch_summary(hetero_build_launch_plan(placement, worker_bin, master_addr, master_port, topo.world_size))
    result.multi_launch_summary = hetero_multi_launch_summary(hetero_build_multi_launch_plan(topo, vendor, chip_type, worker_bin, master_addr, master_port, min_devices, min_memory_gb))
    result.multi_launch_script = hetero_multi_launch_script(hetero_build_multi_launch_plan(topo, vendor, chip_type, worker_bin, master_addr, master_port, min_devices, min_memory_gb))
    result
}

func bridge_hetero_launch_summary(hetero_topology topo, string vendor, string chip_type, string worker_bin, string master_addr, int master_port, int min_devices, int min_memory_gb) string {
    hetero_runtime_bridge_result result = bridge_hetero_launch(topo, vendor, chip_type, worker_bin, master_addr, master_port, min_devices, min_memory_gb)
    string out = ""
    out = out + hetero_topology_summary(topo)
    out = out + result.placement_summary
    out = out + result.launch_summary
    out = out + result.multi_launch_summary
    out = out + result.multi_launch_script
    out
}

func bridge_hetero_demo_script(string worker_bin, string master_addr, int master_port) string {
    hetero_topology topo = hetero_topology_new("neurx-hetero-demo")
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(1, "cuda-01", "10.0.0.1", 9000, hetero_default_capability("nvidia", "h100", 8, 80), true))
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(2, "rocm-01", "10.0.0.2", 9001, hetero_default_capability("amd", "mi300", 4, 64), true))
    topo = hetero_topology_add_node(topo, hetero_topology_node_new(3, "npu-01", "10.0.0.3", 9002, hetero_default_capability("huawei", "ascend", 8, 32), true))
    hetero_multi_launch_plan plan = hetero_build_multi_launch_plan(topo, "", "", worker_bin, master_addr, master_port, 1, 1)
    hetero_multi_launch_script(plan)
}
