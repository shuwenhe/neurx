package neurx.distributed.topology.fabric_planner

struct fabric_topology {
    []int node_ids
    []string zones
    []string racks
    []string hosts
    []string vendors
    []string chip_types
    []string collective_backends
    []int device_counts
    []int device_memory_gb
    []int fabric_bandwidth_gbps
    []bool healthy
    int total_devices
    int healthy_devices
}

struct fabric_request {
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    int min_device_memory_gb
    int min_fabric_bandwidth_gbps
    string vendor
    string chip_type
    string collective_backend
}

struct fabric_placement_plan {
    []int global_ranks
    []int tensor_ranks
    []int pipeline_ranks
    []int data_ranks
    []int node_ids
    []int local_devices
    []string zones
    []string racks
    []string hosts
    []string collective_backends
    int world_size
    int selected_nodes
    int selected_zones
    bool valid
    string reason
}

func fabric_topology_new() fabric_topology {
    []int empty_ints = []int{}
    []string empty_strings = []string{}
    []bool empty_bools = []bool{}
    fabric_topology {
        node_ids: empty_ints, zones: empty_strings, racks: empty_strings,
        hosts: empty_strings, vendors: empty_strings, chip_types: empty_strings,
        collective_backends: empty_strings, device_counts: empty_ints,
        device_memory_gb: empty_ints, fabric_bandwidth_gbps: empty_ints,
        healthy: empty_bools, total_devices: 0, healthy_devices: 0,
    }
}

func fabric_topology_add_node(fabric_topology topology, int node_id, string zone, string rack,
    string host, string vendor, string chip_type, string collective_backend, int device_count,
    int device_memory_gb, int fabric_bandwidth_gbps, bool healthy) fabric_topology {
    if node_id <= 0 || host == "" || device_count <= 0 { return topology }
    topology.node_ids = append(topology.node_ids, node_id)
    topology.zones = append(topology.zones, zone)
    topology.racks = append(topology.racks, rack)
    topology.hosts = append(topology.hosts, host)
    topology.vendors = append(topology.vendors, vendor)
    topology.chip_types = append(topology.chip_types, chip_type)
    topology.collective_backends = append(topology.collective_backends, collective_backend)
    topology.device_counts = append(topology.device_counts, device_count)
    topology.device_memory_gb = append(topology.device_memory_gb, device_memory_gb)
    topology.fabric_bandwidth_gbps = append(topology.fabric_bandwidth_gbps, fabric_bandwidth_gbps)
    topology.healthy = append(topology.healthy, healthy)
    topology.total_devices = topology.total_devices + device_count
    if healthy { topology.healthy_devices = topology.healthy_devices + device_count }
    topology
}

func fabric_node_matches(fabric_topology topology, int index, fabric_request request) bool {
    if !topology.healthy[index] { return false }
    if topology.device_memory_gb[index] < request.min_device_memory_gb { return false }
    if topology.fabric_bandwidth_gbps[index] < request.min_fabric_bandwidth_gbps { return false }
    if request.vendor != "" && topology.vendors[index] != request.vendor { return false }
    if request.chip_type != "" && topology.chip_types[index] != request.chip_type { return false }
    if request.collective_backend != "" && topology.collective_backends[index] != request.collective_backend { return false }
    true
}

func fabric_count_eligible_devices(fabric_topology topology, fabric_request request) int {
    int count = 0
    int i = 0
    for i < len(topology.node_ids) {
        if fabric_node_matches(topology, i, request) { count = count + topology.device_counts[i] }
        i = i + 1
    }
    count
}

func fabric_zone_seen([]string zones, string zone) bool {
    int i = 0
    for i < len(zones) {
        if zones[i] == zone { return true }
        i = i + 1
    }
    false
}

func fabric_empty_plan(int world_size, string reason) fabric_placement_plan {
    []int empty_ints = []int{}
    []string empty_strings = []string{}
    fabric_placement_plan {
        global_ranks: empty_ints, tensor_ranks: empty_ints,
        pipeline_ranks: empty_ints, data_ranks: empty_ints,
        node_ids: empty_ints, local_devices: empty_ints,
        zones: empty_strings, racks: empty_strings, hosts: empty_strings,
        collective_backends: empty_strings, world_size: world_size,
        selected_nodes: 0, selected_zones: 0, valid: false, reason: reason,
    }
}

func fabric_plan(fabric_topology topology, fabric_request request) fabric_placement_plan {
    int world_size = request.tensor_parallel_size * request.pipeline_parallel_size * request.data_parallel_size
    if request.tensor_parallel_size <= 0 || request.pipeline_parallel_size <= 0 || request.data_parallel_size <= 0 {
        return fabric_empty_plan(world_size, "parallel sizes must be positive")
    }
    if request.collective_backend == "" {
        return fabric_empty_plan(world_size, "collective backend must be explicit for heterogeneous placement")
    }
    if fabric_count_eligible_devices(topology, request) < world_size {
        return fabric_empty_plan(world_size, "insufficient compatible healthy devices")
    }
    plan := fabric_empty_plan(world_size, "")
    []string selected_zones = []string{}
    int global_rank = 0
    int node_cursor = 0
    int local_device = 0
    int last_node_id = 0 - 1
    for global_rank < world_size {
        int searched = 0
        for searched < len(topology.node_ids) && !fabric_node_matches(topology, node_cursor, request) {
            node_cursor = (node_cursor + 1) % len(topology.node_ids)
            local_device = 0
            searched = searched + 1
        }
        if local_device >= topology.device_counts[node_cursor] {
            node_cursor = (node_cursor + 1) % len(topology.node_ids)
            local_device = 0
            continue
        }
        int per_data = request.tensor_parallel_size * request.pipeline_parallel_size
        int data_rank = global_rank / per_data
        int within_replica = global_rank - data_rank * per_data
        int pipeline_rank = within_replica / request.tensor_parallel_size
        int tensor_rank = within_replica - pipeline_rank * request.tensor_parallel_size
        plan.global_ranks = append(plan.global_ranks, global_rank)
        plan.tensor_ranks = append(plan.tensor_ranks, tensor_rank)
        plan.pipeline_ranks = append(plan.pipeline_ranks, pipeline_rank)
        plan.data_ranks = append(plan.data_ranks, data_rank)
        plan.node_ids = append(plan.node_ids, topology.node_ids[node_cursor])
        plan.local_devices = append(plan.local_devices, local_device)
        plan.zones = append(plan.zones, topology.zones[node_cursor])
        plan.racks = append(plan.racks, topology.racks[node_cursor])
        plan.hosts = append(plan.hosts, topology.hosts[node_cursor])
        plan.collective_backends = append(plan.collective_backends, topology.collective_backends[node_cursor])
        if topology.node_ids[node_cursor] != last_node_id {
            plan.selected_nodes = plan.selected_nodes + 1
            last_node_id = topology.node_ids[node_cursor]
        }
        if !fabric_zone_seen(selected_zones, topology.zones[node_cursor]) {
            selected_zones = append(selected_zones, topology.zones[node_cursor])
        }
        global_rank = global_rank + 1
        local_device = local_device + 1
    }
    plan.selected_zones = len(selected_zones)
    plan.valid = len(plan.global_ranks) == world_size
    if !plan.valid { plan.reason = "incomplete rank placement" }
    plan
}

func fabric_plan_summary(fabric_placement_plan plan) string {
    int valid_value = 0
    if plan.valid { valid_value = 1 }
    string out = "valid=" + itoa(valid_value) + "\n"
    out = out + "world_size=" + itoa(plan.world_size) + "\n"
    out = out + "ranks=" + itoa(len(plan.global_ranks)) + "\n"
    out = out + "selected_nodes=" + itoa(plan.selected_nodes) + "\n"
    out = out + "selected_zones=" + itoa(plan.selected_zones) + "\n"
    out = out + "reason=" + plan.reason + "\n"
    out
}
