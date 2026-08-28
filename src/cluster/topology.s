package neurx.cluster.topology

use std.vec.vec

struct node_distance {
    int from_node
    int to_node
    int distance_hops
    float bandwidth_gbps
}

struct topology_config {
    int topology_type
    int num_nodes
    int max_hops
}

struct node_ring {
    vec[int] node_sequence
    int ring_size
}

struct node_tree {
    int root_node
    vec[int] children
    vec[int] parent
}

struct topology_state {
    topology_config config
    vec[node_distance] distances
    node_ring ring
    node_tree tree
    int calculated
}

topology_state g_topology

func topology_init(
    num_nodes: int,
    topology_type: int
) (bool, string) {
    if num_nodes <= 0 {
        return false, "Invalid num_nodes"
    }

    if topology_type < 0 || topology_type > 2 {
        return false, "Invalid topology_type (0=ring, 1=tree, 2=mesh)"
    }

    g_topology = topology_state {
        config: topology_config {
            topology_type: topology_type,
            num_nodes: num_nodes,
            max_hops: num_nodes - 1,
        },
        distances: vec[node_distance](),
        ring: node_ring {
            node_sequence: vec[int](),
            ring_size: 0,
        },
        tree: node_tree {
            root_node: 0,
            children: vec[int](),
            parent: vec[int](),
        },
        calculated: 0,
    }

    if topology_type == 0 {
        for i := 0; i < num_nodes; i = i + 1 {
            g_topology.ring.node_sequence.push(i)
        }
        g_topology.ring.ring_size = num_nodes
    }

    return true, ""
}

func set_node_distance(
    from_node: int,
    to_node: int,
    hops: int,
    bandwidth_gbps: float
) (bool, string) {
    if from_node < 0 || to_node < 0 {
        return false, "Invalid nodes"
    }

    if hops < 0 {
        return false, "Invalid hops"
    }

    if bandwidth_gbps <= 0.0 {
        return false, "Invalid bandwidth"
    }

    distance := node_distance {
        from_node: from_node,
        to_node: to_node,
        distance_hops: hops,
        bandwidth_gbps: bandwidth_gbps,
    }

    g_topology.distances.push(distance)

    return true, ""
}

func get_node_distance(
    from_node: int,
    to_node: int
) (int, float, bool, string) {
    if from_node < 0 || to_node < 0 {
        return -1, 0.0, false, "Invalid nodes"
    }

    for i := 0; i < g_topology.distances.len(); i = i + 1 {
        d := g_topology.distances[i]
        if d.from_node == from_node && d.to_node == to_node {
            return d.distance_hops, d.bandwidth_gbps, true, ""
        }
    }

    return -1, 0.0, false, "Distance not found"
}

func find_shortest_path(
    src_node: int,
    dest_node: int
) (vec[int], bool, string) {
    if src_node < 0 || dest_node < 0 {
        return vec[int](), false, "Invalid nodes"
    }

    if src_node == dest_node {
        path := vec[int]()
        path.push(src_node)
        return path, true, ""
    }

    path := vec[int]()
    if g_topology.config.topology_type == 0 {
        ring_size := g_topology.ring.ring_size
        current := src_node
        path.push(current)

        for current != dest_node && path.len() <= ring_size {
            current = (current + 1) % ring_size
            path.push(current)
        }

        if current == dest_node {
            return path, true, ""
        }
    }

    return path, false, "Path not found"
}

func optimize_collective_order(
    num_nodes: int
) (vec[int], bool, string) {
    if num_nodes <= 0 {
        return vec[int](), false, "Invalid num_nodes"
    }

    order := vec[int]()
    if g_topology.config.topology_type == 0 {
        for i := 0; i < num_nodes; i = i + 1 {
            order.push(i)
        }
    }

    return order, true, ""
}

func get_bottleneck_link(
    src_node: int,
    dest_node: int
) (float, bool, string) {
    if src_node < 0 || dest_node < 0 {
        return 0.0, false, "Invalid nodes"
    }

    hops, bandwidth, found, _ := get_node_distance(src_node, dest_node)
    if !found {
        return 0.0, false, "Distance not found"
    }

    if hops <= 0 {
        return 0.0, false, "Invalid hops"
    }

    bottleneck := bandwidth / float(hops)

    return bottleneck, true, ""
}

func estimate_collective_time(
    data_size: int64,
    num_nodes: int
) (int64, bool, string) {
    if data_size <= 0 || num_nodes <= 0 {
        return 0, false, "Invalid parameters"
    }

    base_latency_us := int64(1000)
    data_transfer_time := data_size * int64(num_nodes) / int64(1000)
    total_time := base_latency_us + data_transfer_time

    return total_time, true, ""
}

func get_topology_config() (topology_config, bool, string) {
    return g_topology.config, true, ""
}

func get_ring_order() (vec[int], bool, string) {
    return g_topology.ring.node_sequence, true, ""
}

func get_all_distances() (vec[node_distance], bool, string) {
    return g_topology.distances, true, ""
}

func reset_topology() (bool, string) {
    g_topology.distances = vec[node_distance]()
    g_topology.ring.node_sequence = vec[int]()
    g_topology.calculated = 0

    return true, ""
}
