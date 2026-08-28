package neurx.distributed.cluster
struct cluster_node_capability {
    string platform
    string device_type
    int device_count
    int memory_gb
    bool supports_graph_capture
    bool supports_speculative_decode
    bool supports_fp8
    bool supports_int4
    bool supports_distributed
    string distributed_backend
}
struct cluster_node_record {
    int node_id
    string node_name
    string host
    int port
    int rank
    int local_rank
    bool healthy
    int load
    cluster_node_capability capability
}
struct cluster_workload_request {
    string workload_id
    string model_id
    int min_device_count
    int min_memory_gb
    bool require_graph_capture
    bool require_speculative_decode
    bool require_fp8
    bool require_distributed
}
struct cluster_placement_result {
    bool scheduled
    int node_id
    string node_name
    string host
    int port
    string backend
    string reason
}
struct cluster_runtime_state {
    cluster_node_record[] nodes
    int node_count
    int next_node_id
    int controller_rank
    int world_size
    string cluster_name
}
func cluster_empty_capability() cluster_node_capability {
    cluster_node_capability {
        platform: "unknown",
        device_type: "unknown",
        device_count: 0,
        memory_gb: 0,
        supports_graph_capture: false,
        supports_speculative_decode: false,
        supports_fp8: false,
        supports_int4: false,
        supports_distributed: false,
        distributed_backend: ""
    }
}
func cluster_zero_nodes(int capacity) cluster_node_record[] {
    cluster_node_record[] items = cluster_node_record[]{cap: capacity}
    int i = 0
    for i < capacity {
        items[i] = cluster_node_record {
            node_id: 0,
            node_name: "",
            host: "",
            port: 0,
            rank: 0,
            local_rank: 0,
            healthy: false,
            load: 0,
            capability: cluster_empty_capability()
        }
        i = i + 1
    }
    items
}
func create_cluster_runtime(string cluster_name, int world_size) cluster_runtime_state {
    if world_size <= 0 { world_size = 1 }
    cluster_runtime_state {
        nodes: cluster_zero_nodes(1024),
        node_count: 0,
        next_node_id: 1,
        controller_rank: 0,
        world_size: world_size,
        cluster_name: cluster_name
    }
}
func cluster_find_node(cluster_runtime_state state, int node_id) int {
    int i = 0
    for i < state.node_count {
        if state.nodes[i].node_id == node_id { return i }
        i = i + 1
    }
    0 - 1
}
func cluster_register_node(
    cluster_runtime_state state,
    string node_name,
    string host,
    int port,
    int rank,
    int local_rank,
    cluster_node_capability capability,
) cluster_runtime_state {
    if node_name == "" || host == "" || port <= 0 || state.node_count >= 1024 {
        return state
    }
    int index = cluster_find_node(state, state.next_node_id)
    if index >= 0 {
        return state
    }
    int slot = state.node_count
    state.nodes[slot] = cluster_node_record {
        node_id: state.next_node_id,
        node_name: node_name,
        host: host,
        port: port,
        rank: rank,
        local_rank: local_rank,
        healthy: true,
        load: 0,
        capability: capability
    }
    state.node_count = state.node_count + 1
    state.next_node_id = state.next_node_id + 1
    state
}
func cluster_mark_node_health(cluster_runtime_state state, int node_id, bool healthy, int load) cluster_runtime_state {
    int index = cluster_find_node(state, node_id)
    if index < 0 { return state }
    state.nodes[index].healthy = healthy
    if load < 0 { load = 0 }
    state.nodes[index].load = load
    state
}
func cluster_mark_node_failed(cluster_runtime_state state, int node_id) cluster_runtime_state {
    cluster_mark_node_health(state, node_id, false, 0)
}
func cluster_node_supports(cluster_node_record node, cluster_workload_request request) bool {
    if !node.healthy { return false }
    if node.capability.device_count < request.min_device_count { return false }
    if node.capability.memory_gb < request.min_memory_gb { return false }
    if request.require_graph_capture && !node.capability.supports_graph_capture { return false }
    if request.require_speculative_decode && !node.capability.supports_speculative_decode { return false }
    if request.require_fp8 && !node.capability.supports_fp8 { return false }
    if request.require_distributed && !node.capability.supports_distributed { return false }
    true
}
func cluster_select_node(cluster_runtime_state state, cluster_workload_request request) cluster_placement_result {
    int best_index = 0 - 1
    int best_load = 2147483647
    int i = 0
    for i < state.node_count {
        if cluster_node_supports(state.nodes[i], request) {
            if state.nodes[i].load < best_load {
                best_load = state.nodes[i].load
                best_index = i
            }
        }
        i = i + 1
    }
    if best_index < 0 {
        return cluster_placement_result {
            scheduled: false,
            node_id: 0,
            node_name: "",
            host: "",
            port: 0,
            backend: "",
            reason: "no healthy node satisfies workload requirements"
        }
    }
    cluster_placement_result {
        scheduled: true,
        node_id: state.nodes[best_index].node_id,
        node_name: state.nodes[best_index].node_name,
        host: state.nodes[best_index].host,
        port: state.nodes[best_index].port,
        backend: state.nodes[best_index].capability.distributed_backend,
        reason: ""
    }
}
func cluster_assign_request(
    cluster_runtime_state state,
    cluster_workload_request request,
) cluster_runtime_state {
    cluster_placement_result result = cluster_select_node(state, request)
    if !result.scheduled { return state }
    int index = cluster_find_node(state, result.node_id)
    if index >= 0 {
        state.nodes[index].load = state.nodes[index].load + 1
    }
    state
}
func cluster_release_request(cluster_runtime_state state, int node_id) cluster_runtime_state {
    int index = cluster_find_node(state, node_id)
    if index >= 0 && state.nodes[index].load > 0 {
        state.nodes[index].load = state.nodes[index].load - 1
    }
    state
}
func cluster_healthy_node_count(cluster_runtime_state state) int {
    int healthy = 0
    int i = 0
    for i < state.node_count {
        if state.nodes[i].healthy { healthy = healthy + 1 }
        i = i + 1
    }
    healthy
}
func cluster_total_device_count(cluster_runtime_state state) int {
    int total = 0
    int i = 0
    for i < state.node_count {
        total = total + state.nodes[i].capability.device_count
        i = i + 1
    }
    total
}
func cluster_failed_node_count(cluster_runtime_state state) int {
    int failed = 0
    int i = 0
    for i < state.node_count {
        if !state.nodes[i].healthy { failed = failed + 1 }
        i = i + 1
    }
    failed
}
func cluster_summary(cluster_runtime_state state) string {
    string out = "cluster=" + state.cluster_name + "\n"
    out = out + "world_size=" + itoa(state.world_size) + "\n"
    out = out + "nodes=" + itoa(state.node_count) + "\n"
    out = out + "healthy_nodes=" + itoa(cluster_healthy_node_count(state)) + "\n"
    out = out + "failed_nodes=" + itoa(cluster_failed_node_count(state)) + "\n"
    out = out + "total_devices=" + itoa(cluster_total_device_count(state)) + "\n"
    out
}
func cluster_default_cuda_capability(int device_count, int memory_gb) cluster_node_capability {
    cluster_node_capability {
        platform: "cuda",
        device_type: "gpu",
        device_count: device_count,
        memory_gb: memory_gb,
        supports_graph_capture: true,
        supports_speculative_decode: true,
        supports_fp8: true,
        supports_int4: true,
        supports_distributed: true,
        distributed_backend: "nccl"
    }
}
func cluster_default_rocm_capability(int device_count, int memory_gb) cluster_node_capability {
    cluster_node_capability {
        platform: "rocm",
        device_type: "gpu",
        device_count: device_count,
        memory_gb: memory_gb,
        supports_graph_capture: true,
        supports_speculative_decode: true,
        supports_fp8: true,
        supports_int4: true,
        supports_distributed: true,
        distributed_backend: "rccl"
    }
}
func cluster_default_npu_capability(int device_count, int memory_gb) cluster_node_capability {
    cluster_node_capability {
        platform: "ascend",
        device_type: "npu",
        device_count: device_count,
        memory_gb: memory_gb,
        supports_graph_capture: true,
        supports_speculative_decode: false,
        supports_fp8: true,
        supports_int4: true,
        supports_distributed: true,
        distributed_backend: "hccl"
    }
}
func cluster_default_cpu_capability(int memory_gb) cluster_node_capability {
    cluster_node_capability {
        platform: "cpu",
        device_type: "cpu",
        device_count: 1,
        memory_gb: memory_gb,
        supports_graph_capture: false,
        supports_speculative_decode: false,
        supports_fp8: false,
        supports_int4: true,
        supports_distributed: true,
        distributed_backend: "gloo"
    }
}
