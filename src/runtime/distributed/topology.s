package neurx.runtime.distributed.topology

struct hetero_chip_capability {
    string vendor
    string chip_type
    int device_count
    int memory_gb
    bool supports_tensor_parallel
    bool supports_pipeline_parallel
    bool supports_data_parallel
    bool supports_allreduce
}

struct hetero_topology_node {
    int node_id
    string node_name
    string host
    int port
    hetero_chip_capability capability
    bool healthy
}

struct hetero_topology {
    string cluster_name
    hetero_topology_node[] nodes
    int world_size
    int healthy_nodes
    int total_devices
    bool valid
    string reason
}

struct hetero_placement_result {
    bool launchable
    int node_id
    string node_name
    string host
    int port
    string vendor
    string chip_type
    string reason
}

struct hetero_launch_plan {
    hetero_placement_result placement
    string worker_bin
    string master_addr
    int master_port
    int world_size
    string command
    bool valid
    string reason
}

struct hetero_launch_command {
    int node_id
    string node_name
    string host
    int port
    int global_rank
    string command
}

struct hetero_multi_launch_plan {
    hetero_placement_result[] placements
    hetero_launch_command[] commands
    bool valid
    string reason
}

func hetero_default_capability(string vendor, string chip_type, int device_count, int memory_gb) hetero_chip_capability {
    hetero_chip_capability {
        vendor: vendor,
        chip_type: chip_type,
        device_count: device_count,
        memory_gb: memory_gb,
        supports_tensor_parallel: true,
        supports_pipeline_parallel: true,
        supports_data_parallel: true,
        supports_allreduce: true,
    }
}

func hetero_topology_node_new(int node_id, string node_name, string host, int port, hetero_chip_capability capability, bool healthy) hetero_topology_node {
    hetero_topology_node {
        node_id: node_id,
        node_name: node_name,
        host: host,
        port: port,
        capability: capability,
        healthy: healthy,
    }
}

func hetero_topology_new(string cluster_name) hetero_topology {
    hetero_topology {
        cluster_name: cluster_name,
        nodes: hetero_topology_node[]{cap: 0},
        world_size: 0,
        healthy_nodes: 0,
        total_devices: 0,
        valid: false,
        reason: "empty topology",
    }
}

func hetero_topology_add_node(hetero_topology topo, hetero_topology_node node) hetero_topology {
    topo.nodes = append(topo.nodes, node)
    if node.healthy {
        topo.healthy_nodes = topo.healthy_nodes + 1
    }
    topo.total_devices = topo.total_devices + node.capability.device_count
    topo.world_size = topo.total_devices
    topo.valid = len(topo.nodes) > 0 && topo.total_devices > 0
    topo.reason = ""
    topo
}

func hetero_topology_mark_failed(hetero_topology topo, int node_id) hetero_topology {
    int i = 0
    for i < len(topo.nodes) {
        if topo.nodes[i].node_id == node_id && topo.nodes[i].healthy {
            topo.nodes[i].healthy = false
            topo.healthy_nodes = topo.healthy_nodes - 1
        }
        i = i + 1
    }
    topo.valid = topo.healthy_nodes > 0
    if !topo.valid {
        topo.reason = "no healthy nodes"
    }
    topo
}

func hetero_topology_select_node(hetero_topology topo, string vendor, string chip_type, int min_devices, int min_memory_gb) int {
    if min_devices <= 0 { min_devices = 1 }
    if min_memory_gb <= 0 { min_memory_gb = 1 }
    int i = 0
    for i < len(topo.nodes) {
        hetero_topology_node node = topo.nodes[i]
        if node.healthy && node.capability.device_count >= min_devices && node.capability.memory_gb >= min_memory_gb {
            bool vendor_ok = vendor == "" || node.capability.vendor == vendor
            bool chip_ok = chip_type == "" || node.capability.chip_type == chip_type
            if vendor_ok && chip_ok {
                return node.node_id
            }
        }
        i = i + 1
    }
    0 - 1
}

func hetero_topology_place_workload(hetero_topology topo, string vendor, string chip_type, int min_devices, int min_memory_gb) hetero_placement_result {
    int node_id = hetero_topology_select_node(topo, vendor, chip_type, min_devices, min_memory_gb)
    hetero_placement_result result
    result.launchable = false
    result.node_id = 0 - 1
    result.node_name = ""
    result.host = ""
    result.port = 0
    result.vendor = ""
    result.chip_type = ""
    result.reason = "no matching node"
    int i = 0
    for i < len(topo.nodes) {
        if topo.nodes[i].node_id == node_id {
            result.launchable = true
            result.node_id = topo.nodes[i].node_id
            result.node_name = topo.nodes[i].node_name
            result.host = topo.nodes[i].host
            result.port = topo.nodes[i].port
            result.vendor = topo.nodes[i].capability.vendor
            result.chip_type = topo.nodes[i].capability.chip_type
            result.reason = ""
            return result
        }
        i = i + 1
    }
    result
}

func hetero_topology_summary(hetero_topology topo) string {
    string out = ""
    out = out + "cluster=" + topo.cluster_name + "\n"
    out = out + "nodes=" + itoa(len(topo.nodes)) + "\n"
    out = out + "healthy_nodes=" + itoa(topo.healthy_nodes) + "\n"
    out = out + "total_devices=" + itoa(topo.total_devices) + "\n"
    out = out + "world_size=" + itoa(topo.world_size) + "\n"
    out = out + "valid=" + itoa(topo.valid ? 1 : 0) + "\n"
    out = out + "reason=" + topo.reason + "\n"
    out
}

func hetero_placement_summary(hetero_placement_result placement) string {
    string out = ""
    out = out + "launchable=" + itoa(placement.launchable ? 1 : 0) + "\n"
    out = out + "node_id=" + itoa(placement.node_id) + "\n"
    out = out + "node_name=" + placement.node_name + "\n"
    out = out + "host=" + placement.host + "\n"
    out = out + "port=" + itoa(placement.port) + "\n"
    out = out + "vendor=" + placement.vendor + "\n"
    out = out + "chip_type=" + placement.chip_type + "\n"
    out = out + "reason=" + placement.reason + "\n"
    out
}

func hetero_build_launch_plan(hetero_placement_result placement, string worker_bin, string master_addr, int master_port, int world_size) hetero_launch_plan {
    hetero_launch_plan plan
    plan.placement = placement
    plan.worker_bin = worker_bin
    plan.master_addr = master_addr
    plan.master_port = master_port
    plan.world_size = world_size
    plan.command = ""
    plan.valid = false
    plan.reason = ""
    if !placement.launchable || worker_bin == "" || master_addr == "" || master_port <= 0 || world_size <= 0 {
        plan.reason = "invalid launch inputs"
        return plan
    }
    string cmd = ""
    cmd = cmd + "WORLD_SIZE=" + itoa(world_size)
    cmd = cmd + " RANK=0"
    cmd = cmd + " LOCAL_RANK=0"
    cmd = cmd + " MASTER_ADDR=" + master_addr
    cmd = cmd + " MASTER_PORT=" + itoa(master_port)
    cmd = cmd + " exec " + worker_bin
    plan.command = cmd
    plan.valid = true
    plan.reason = ""
    plan
}

func hetero_build_multi_launch_plan(hetero_topology topo, string vendor, string chip_type, string worker_bin, string master_addr, int master_port, int min_devices, int min_memory_gb) hetero_multi_launch_plan {
    hetero_multi_launch_plan plan
    plan.placements = hetero_placement_result[]{cap: len(topo.nodes)}
    plan.commands = hetero_launch_command[]{cap: len(topo.nodes)}
    plan.valid = false
    plan.reason = ""
    if !topo.valid || worker_bin == "" || master_addr == "" || master_port <= 0 {
        plan.reason = "invalid multi launch inputs"
        return plan
    }
    int i = 0
    int world_rank = 0
    for i < len(topo.nodes) {
        hetero_topology_node node = topo.nodes[i]
        if node.healthy && node.capability.device_count >= min_devices && node.capability.memory_gb >= min_memory_gb {
            bool vendor_ok = vendor == "" || node.capability.vendor == vendor
            bool chip_ok = chip_type == "" || node.capability.chip_type == chip_type
            if vendor_ok && chip_ok {
                hetero_placement_result placement
                placement.launchable = true
                placement.node_id = node.node_id
                placement.node_name = node.node_name
                placement.host = node.host
                placement.port = node.port
                placement.vendor = node.capability.vendor
                placement.chip_type = node.capability.chip_type
                placement.reason = ""
                plan.placements = append(plan.placements, placement)
                hetero_launch_command command
                command.node_id = node.node_id
                command.node_name = node.node_name
                command.host = node.host
                command.port = node.port
                command.global_rank = world_rank
                command.command = ""
                command.command = command.command + "WORLD_SIZE=" + itoa(topo.world_size)
                command.command = command.command + " RANK=" + itoa(world_rank)
                command.command = command.command + " LOCAL_RANK=0"
                command.command = command.command + " MASTER_ADDR=" + master_addr
                command.command = command.command + " MASTER_PORT=" + itoa(master_port)
                command.command = command.command + " exec " + worker_bin
                plan.commands = append(plan.commands, command)
                world_rank = world_rank + 1
            }
        }
        i = i + 1
    }
    plan.valid = len(plan.commands) > 0
    if !plan.valid {
        plan.reason = "no launchable nodes"
    }
    plan
}

func hetero_launch_summary(hetero_launch_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "world_size=" + itoa(plan.world_size) + "\n"
    out = out + "master=" + plan.master_addr + ":" + itoa(plan.master_port) + "\n"
    out = out + "worker_bin=" + plan.worker_bin + "\n"
    out = out + "command=" + plan.command + "\n"
    out = out + "reason=" + plan.reason + "\n"
    out
}

func hetero_multi_launch_summary(hetero_multi_launch_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "placements=" + itoa(len(plan.placements)) + "\n"
    out = out + "commands=" + itoa(len(plan.commands)) + "\n"
    out = out + "reason=" + plan.reason + "\n"
    out
}

func hetero_multi_launch_script(hetero_multi_launch_plan plan) string {
    string out = "#!/bin/sh\nset -e\n"
    if !plan.valid {
        return out + "# invalid multi launch plan\n"
    }
    int i = 0
    for i < len(plan.commands) {
        out = out + "ssh " + plan.commands[i].host + " '" + plan.commands[i].command + "'\n"
        i = i + 1
    }
    out
}
