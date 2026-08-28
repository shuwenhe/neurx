struct remote_cache_node {
    string node_id
    string host
    int port
    int64 last_heartbeat
    int is_healthy
    int64 total_blocks
    int64 available_blocks
    string status
}

struct distributed_cache {
    []remote_cache_node peers
    int num_peers
    int max_peers
    string local_node_id
    int64 replication_factor
    int64 consistency_level
    int64 current_time
    int64 partition_id
}

func create_distributed_cache(string node_id, int64 replication, int64 consistency) distributed_cache {
    distributed_cache dc = distributed_cache{}
    dc.local_node_id = node_id
    dc.replication_factor = replication
    dc.consistency_level = consistency
    dc.num_peers = 0
    dc.max_peers = 16
    dc.peers = []remote_cache_node{cap: 16}
    dc.current_time = 0
    dc.partition_id = 0
    print("[DistributedCache] Initialized node: " + node_id + ", replication=" + int_to_string(replication) + "\n")
    return dc
}

func distributed_cache_add_peer(distributed_cache dc, string peer_id, string host, int port) int {
    if dc.num_peers >= dc.max_peers {
        print("[DistributedCache] Max peers reached\n")
        return 0
    }
    remote_cache_node peer = remote_cache_node{}
    peer.node_id = peer_id
    peer.host = host
    peer.port = port
    peer.last_heartbeat = dc.current_time
    peer.is_healthy = 1
    peer.total_blocks = 0
    peer.available_blocks = 0
    peer.status = "connected"
    dc.peers[dc.num_peers] = peer
    dc.num_peers = dc.num_peers + 1
    print("[DistributedCache] Added peer: " + peer_id + " (" + host + ":" + int_to_string(port) + ")\n")
    return 1
}

func distributed_cache_compute_replica_nodes(distributed_cache dc, string cache_key) string[] {
    string[] replicas = string[]{cap: 8}
    int hash = 0
    int i = 0
    for i < len(cache_key) {
        int byte_val = __host_slice(cache_key, i, i + 1)[0]
        hash = (hash * 31 + byte_val) % 2147483647
        i = i + 1
    }
    int start_peer = (hash % dc.num_peers)
    if start_peer < 0 { start_peer = 0 }
    int replica_count = 0
    int attempt = 0
    for replica_count < dc.replication_factor && attempt < dc.num_peers {
        int peer_idx = (start_peer + attempt) % dc.num_peers
        if dc.peers[peer_idx].is_healthy == 1 {
            replicas[replica_count] = dc.peers[peer_idx].node_id
            replica_count = replica_count + 1
        }
        attempt = attempt + 1
    }
    return replicas
}

func distributed_cache_get_responsible_node(distributed_cache dc, string cache_key) string {
    if dc.num_peers == 0 {
        return dc.local_node_id
    }
    int hash = 0
    int i = 0
    for i < len(cache_key) {
        int byte_val = __host_slice(cache_key, i, i + 1)[0]
        hash = (hash * 31 + byte_val) % 2147483647
        i = i + 1
    }
    int peer_idx = (hash % dc.num_peers)
    if peer_idx < 0 { peer_idx = 0 }
    return dc.peers[peer_idx].node_id
}

func distributed_cache_check_peer_health(distributed_cache dc) {
    int i = 0
    for i < dc.num_peers {
        remote_cache_node peer = dc.peers[i]
        int64 time_since_heartbeat = dc.current_time - peer.last_heartbeat
        if time_since_heartbeat > 30000 {
            if peer.is_healthy == 1 {
                dc.peers[i].is_healthy = 0
                dc.peers[i].status = "unhealthy"
                print("[DistributedCache] Peer " + peer.node_id + " marked unhealthy\n")
            }
        } else if peer.is_healthy == 0 {
            dc.peers[i].is_healthy = 1
            dc.peers[i].status = "healthy"
            print("[DistributedCache] Peer " + peer.node_id + " recovered\n")
        }
        i = i + 1
    }
}

func distributed_cache_record_heartbeat(distributed_cache dc, string peer_id) {
    int i = 0
    for i < dc.num_peers {
        if dc.peers[i].node_id == peer_id {
            dc.peers[i].last_heartbeat = dc.current_time
            dc.peers[i].is_healthy = 1
            dc.peers[i].status = "healthy"
            return
        }
        i = i + 1
    }
}

func distributed_cache_update_peer_capacity(distributed_cache dc, string peer_id, int64 total, int64 available) {
    int i = 0
    for i < dc.num_peers {
        if dc.peers[i].node_id == peer_id {
            dc.peers[i].total_blocks = total
            dc.peers[i].available_blocks = available
            return
        }
        i = i + 1
    }
}

func distributed_cache_find_best_replica_node(distributed_cache dc, string[] replicas) string {
    if len(replicas) == 0 {
        return dc.local_node_id
    }
    string best_node = replicas[0]
    int64 max_available = 0
    int i = 0
    for i < len(replicas) {
        int j = 0
        for j < dc.num_peers {
            if dc.peers[j].node_id == replicas[i] {
                if dc.peers[j].available_blocks > max_available {
                    max_available = dc.peers[j].available_blocks
                    best_node = replicas[i]
                }
                break
            }
            j = j + 1
        }
        i = i + 1
    }
    return best_node
}

func distributed_cache_get_stats(distributed_cache dc) string {
    int healthy_peers = 0
    int64 total_blocks = 0
    int64 available_blocks = 0
    int i = 0
    for i < dc.num_peers {
        if dc.peers[i].is_healthy == 1 {
            healthy_peers = healthy_peers + 1
        }
        total_blocks = total_blocks + dc.peers[i].total_blocks
        available_blocks = available_blocks + dc.peers[i].available_blocks
        i = i + 1
    }
    string stats = "[DistributedCache] Peers=" + int_to_string(dc.num_peers) + 
                   " (healthy=" + int_to_string(healthy_peers) + ")" +
                   ", Replication=" + int_to_string(dc.replication_factor) +
                   ", TotalCapacity=" + int_to_string(total_blocks) +
                   ", Available=" + int_to_string(available_blocks)
    return stats
}

func distributed_cache_handle_node_failure(distributed_cache dc, string failed_node_id) {
    int i = 0
    for i < dc.num_peers {
        if dc.peers[i].node_id == failed_node_id {
            dc.peers[i].is_healthy = 0
            dc.peers[i].status = "failed"
            print("[DistributedCache] Node failed: " + failed_node_id + ", rebalancing\n")
            return
        }
        i = i + 1
    }
}

func distributed_cache_get_consensus_count(distributed_cache dc) int64 {
    int64 consensus = (dc.num_peers / 2) + 1
    if consensus < 1 { consensus = 1 }
    return consensus
}

func distributed_cache_tick(distributed_cache dc, int64 time_increment) {
    dc.current_time = dc.current_time + time_increment
    if dc.current_time % 10000 == 0 {
        distributed_cache_check_peer_health(dc)
    }
}

func distributed_cache_set_partition_id(distributed_cache dc, int64 partition) {
    dc.partition_id = partition
    print("[DistributedCache] Partition ID set to " + int_to_string(partition) + "\n")
}
