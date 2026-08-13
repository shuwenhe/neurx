package neurx.distributed.stateless_coordinator
struct stateless_group_config {
    int group_id
    int global_rank
    int local_rank
    int world_size
    int base_port
    int backend
    bool use_device_communicator
}
struct stateless_group_state {
    stateless_group_config config
    int rank_in_group
    int device_port
    int cpu_port
    int store_port
    int generation
    int broadcast_count
    int object_broadcast_count
    bool device_group_initialized
    bool cpu_group_initialized
    bool store_group_initialized
    bool destroyed
    string error_message
}
struct stateless_broadcast_result {
    stateless_group_state state
    []int payload
    bool success
}
func stateless_group_config_valid(stateless_group_config config) bool {
    config.group_id > 0 && config.global_rank >= 0 && config.local_rank >= 0 && config.world_size > 0 && config.global_rank < config.world_size && config.base_port > 0 && config.backend > 0
}
func init_stateless_group(stateless_group_config config) stateless_group_state {
    bool initialized = stateless_group_config_valid(config)
    string error_message = ""
    if !initialized { error_message = "invalid stateless group configuration" }
    int port_offset = config.group_id * 3
    stateless_group_state {config: config, rank_in_group: config.global_rank, device_port: config.base_port + port_offset, cpu_port: config.base_port + port_offset + 1, store_port: config.base_port + port_offset + 2, generation: 1, broadcast_count: 0, object_broadcast_count: 0, device_group_initialized: initialized && config.use_device_communicator, cpu_group_initialized: initialized, store_group_initialized: initialized, destroyed: false, error_message: error_message}
}
func stateless_copy_payload([]int payload) []int {
    []int copied = []int{cap: len(payload)}
    int i = 0
    while i < len(payload) { copied[i] = payload[i]; i = i + 1 }
    copied
}
func stateless_broadcast(stateless_group_state state, []int payload, int source_rank) stateless_broadcast_result {
    if state.destroyed || !state.store_group_initialized || source_rank < 0 || source_rank >= state.config.world_size { return stateless_broadcast_result {state: state, payload: [], success: false} }
    state.broadcast_count = state.broadcast_count + 1
    stateless_broadcast_result {state: state, payload: stateless_copy_payload(payload), success: true}
}
func reinitialize_stateless_group(stateless_group_state state, int new_base_port) stateless_group_state {
    if new_base_port <= 0 { return state }
    state.config.base_port = new_base_port
    int port_offset = state.config.group_id * 3
    state.device_port = new_base_port + port_offset
    state.cpu_port = new_base_port + port_offset + 1
    state.store_port = new_base_port + port_offset + 2
    state.generation = state.generation + 1
    state.destroyed = false
    state.cpu_group_initialized = true
    state.store_group_initialized = true
    state.device_group_initialized = state.config.use_device_communicator
    state
}
func destroy_stateless_group(stateless_group_state state) stateless_group_state {
    state.device_group_initialized = false
    state.cpu_group_initialized = false
    state.store_group_initialized = false
    state.destroyed = true
    state
}
