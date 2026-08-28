package neurx.deployment.hetero_runtime_bridge

use neurx.runtime.distributed.topology.{hetero_topology, hetero_placement_result, hetero_topology_place_workload, hetero_build_launch_plan, hetero_build_multi_launch_plan, hetero_launch_summary, hetero_multi_launch_summary, hetero_multi_launch_script, hetero_placement_summary, hetero_topology_summary}

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
