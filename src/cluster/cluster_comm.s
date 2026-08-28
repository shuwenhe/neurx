package neurx.cluster.cluster_comm

use std.vec.vec

struct node_info {
    int node_id
    int rank
    string hostname
    vec[int] gpu_ids
    int num_gpus
    int gpu_per_node
    bool is_active
}

struct cluster_config {
    int num_nodes
    int total_gpus
    int world_size
    int local_rank
    int node_rank
}

struct cluster_peer {
    int peer_rank
    int peer_node_id
    string peer_address
    int peer_port
    bool is_connected
}

struct cluster_stream {
    int stream_id
    int src_rank
    int dest_rank
    bool is_active
    int64 bytes_transferred
}

struct cluster_state {
    vec[node_info] nodes
    vec[cluster_peer] peers
    vec[cluster_stream] streams
    cluster_config config
    int initialized_nodes
    int64 total_bytes_transferred
}

cluster_state g_cluster

func cluster_init(
    num_nodes: int,
    gpus_per_node: int,
    node_id: int,
    hostname: string
) (bool, string) {
    if num_nodes <= 0 || gpus_per_node <= 0 {
        return false, "Invalid cluster config"
    }

    if node_id < 0 || node_id >= num_nodes {
        return false, "Invalid node_id"
    }

    total_gpus := num_nodes * gpus_per_node
    world_size := total_gpus
    local_rank := 0
    node_rank := node_id

    g_cluster = cluster_state {
        nodes: vec[node_info](),
        peers: vec[cluster_peer](),
        streams: vec[cluster_stream](),
        config: cluster_config {
            num_nodes: num_nodes,
            total_gpus: total_gpus,
            world_size: world_size,
            local_rank: local_rank,
            node_rank: node_rank,
        },
        initialized_nodes: 0,
        total_bytes_transferred: 0,
    }

    for i := 0; i < num_nodes; i = i + 1 {
        node := node_info {
            node_id: i,
            rank: i,
            hostname: hostname,
            gpu_ids: vec[int](),
            num_gpus: gpus_per_node,
            gpu_per_node: gpus_per_node,
            is_active: false,
        }

        for j := 0; j < gpus_per_node; j = j + 1 {
            gpu_id := i * gpus_per_node + j
            node.gpu_ids.push(gpu_id)
        }

        g_cluster.nodes.push(node)
    }

    return true, ""
}

func register_node(
    node_id: int,
    hostname: string,
    num_gpus: int
) (bool, string) {
    if node_id < 0 || node_id >= g_cluster.nodes.len() {
        return false, "Invalid node_id"
    }

    if num_gpus <= 0 {
        return false, "Invalid num_gpus"
    }

    g_cluster.nodes[node_id].hostname = hostname
    g_cluster.nodes[node_id].num_gpus = num_gpus
    g_cluster.nodes[node_id].is_active = true
    g_cluster.initialized_nodes = g_cluster.initialized_nodes + 1

    return true, ""
}

func connect_peer(
    peer_rank: int,
    peer_node_id: int,
    peer_address: string,
    peer_port: int
) (bool, string) {
    if peer_rank < 0 {
        return false, "Invalid peer_rank"
    }

    if peer_node_id < 0 || peer_node_id >= g_cluster.nodes.len() {
        return false, "Invalid peer_node_id"
    }

    peer := cluster_peer {
        peer_rank: peer_rank,
        peer_node_id: peer_node_id,
        peer_address: peer_address,
        peer_port: peer_port,
        is_connected: true,
    }

    g_cluster.peers.push(peer)

    return true, ""
}

func create_cluster_stream(
    src_rank: int,
    dest_rank: int
) (int, bool, string) {
    if src_rank < 0 || dest_rank < 0 {
        return -1, false, "Invalid ranks"
    }

    if src_rank == dest_rank {
        return -1, false, "Source and destination cannot be the same"
    }

    stream_id := g_cluster.streams.len()

    stream := cluster_stream {
        stream_id: stream_id,
        src_rank: src_rank,
        dest_rank: dest_rank,
        is_active: true,
        bytes_transferred: 0,
    }

    g_cluster.streams.push(stream)

    return stream_id, true, ""
}

func send_across_nodes(
    src_rank: int,
    dest_rank: int,
    bytes_to_send: int64
) (bool, string) {
    if src_rank < 0 || dest_rank < 0 {
        return false, "Invalid ranks"
    }

    if bytes_to_send <= 0 {
        return false, "Invalid bytes_to_send"
    }

    src_node := src_rank / g_cluster.config.total_gpus
    dest_node := dest_rank / g_cluster.config.total_gpus

    if src_node < 0 || src_node >= g_cluster.nodes.len() {
        return false, "Invalid source node"
    }

    if dest_node < 0 || dest_node >= g_cluster.nodes.len() {
        return false, "Invalid destination node"
    }

    g_cluster.total_bytes_transferred = g_cluster.total_bytes_transferred + bytes_to_send

    return true, ""
}

func recv_across_nodes(
    src_rank: int,
    dest_rank: int,
    max_bytes: int64
) (int64, bool, string) {
    if src_rank < 0 || dest_rank < 0 {
        return 0, false, "Invalid ranks"
    }

    if max_bytes <= 0 {
        return 0, false, "Invalid max_bytes"
    }

    return max_bytes, true, ""
}

func all_reduce_across_cluster(
    reduce_count: int64,
    root_rank: int
) (bool, string) {
    if reduce_count <= 0 {
        return false, "Invalid reduce_count"
    }

    if root_rank < 0 || root_rank >= g_cluster.config.world_size {
        return false, "Invalid root_rank"
    }

    total_ops := g_cluster.config.world_size

    g_cluster.total_bytes_transferred =
        g_cluster.total_bytes_transferred + (reduce_count * int64(total_ops))

    return true, ""
}

func broadcast_across_cluster(
    data_size: int64,
    root_rank: int
) (bool, string) {
    if data_size <= 0 {
        return false, "Invalid data_size"
    }

    if root_rank < 0 || root_rank >= g_cluster.config.world_size {
        return false, "Invalid root_rank"
    }

    return true, ""
}

func synchronize_cluster() (bool, string) {
    for i := 0; i < g_cluster.nodes.len(); i = i + 1 {
        if !g_cluster.nodes[i].is_active {
            return false, "Not all nodes active"
        }
    }

    return true, ""
}

func get_node_info(node_id: int) (node_info, bool, string) {
    if node_id < 0 || node_id >= g_cluster.nodes.len() {
        return node_info{}, false, "Invalid node_id"
    }

    return g_cluster.nodes[node_id], true, ""
}

func get_cluster_config() (cluster_config, bool, string) {
    return g_cluster.config, true, ""
}

func get_cluster_stats() (int, int, int64, bool, string) {
    num_active := g_cluster.initialized_nodes
    num_streams := g_cluster.streams.len()
    bytes_transferred := g_cluster.total_bytes_transferred

    return num_active, num_streams, bytes_transferred, true, ""
}

func close_cluster() (bool, string) {
    g_cluster.peers = vec[cluster_peer]()
    g_cluster.streams = vec[cluster_stream]()

    return true, ""
}
