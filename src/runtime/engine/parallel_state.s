package engine.distributed
import "core"
import "tensor"
type parallel_mode int32
const (
    parallel_mode_tensor      parallel_mode = iota
    parallel_mode_pipeline
    parallel_mode_data
    parallel_mode_expert
    parallel_mode_context
)
struct parallel_config {
    int32 world_size
    int32 rank
    int32 local_rank
    int32 tensor_parallel_size
    int32 pipeline_parallel_size
    int32 data_parallel_size
    int32 expert_parallel_size
    int32 context_parallel_size
    string backend
    int32 timeout_seconds
}
struct group_info {
    string name
    int32 group_id
    int[]32 ranks
    int32 world_size
    int32 rank_in_group
    string backend
}
struct parallel_coordinates {
    int32 data_parallel_rank
    int32 pipeline_parallel_rank
    int32 tensor_parallel_rank
    int32 expert_parallel_rank
    int32 context_parallel_rank
}
struct parallel_state {
    parallel_config config
    parallel_coordinates coordinates
    map[string]group_info* groups
    bool initialized
    string error_message
}
func create_parallel_config(int32 world_size, int32 rank, int32 tp_size, int32 pp_size, int32 dp_size) parallel_config* {
    return *parallel_config{
        world_size: world_size,
        rank: rank,
        local_rank: rank % 8,
        tensor_parallel_size: tp_size,
        pipeline_parallel_size: pp_size,
        data_parallel_size: dp_size,
        expert_parallel_size: 1,
        context_parallel_size: 1,
        backend: "nccl",
        timeout_seconds: 300,
    }
}
func (parallel_state* ps) initialize() error {
    ps.initialized = true
    return nil
}
func (parallel_state* ps) get_tensor_parallel_group() group_info* {
    group, ok := ps.groups["tensor_parallel"]
    if ok {
        return group
    }
    return nil
}
func (parallel_state* ps) get_pipeline_parallel_group() group_info* {
    group, ok := ps.groups["pipeline_parallel"]
    if ok {
        return group
    }
    return nil
}
func (parallel_state* ps) get_data_parallel_group() group_info* {
    group, ok := ps.groups["data_parallel"]
    if ok {
        return group
    }
    return nil
}
func (parallel_state* ps) get_world_rank() int32 {
    return ps.config.rank
}
func (parallel_state* ps) get_local_rank() int32 {
    return ps.config.local_rank
}
func (parallel_state* ps) get_world_size() int32 {
    return ps.config.world_size
}
func (parallel_state* ps) get_tensor_parallel_rank() int32 {
    return ps.coordinates.tensor_parallel_rank
}
func (parallel_state* ps) get_tensor_parallel_size() int32 {
    return ps.config.tensor_parallel_size
}
func (parallel_state* ps) get_pipeline_parallel_rank() int32 {
    return ps.coordinates.pipeline_parallel_rank
}
func (parallel_state* ps) get_pipeline_parallel_size() int32 {
    return ps.config.pipeline_parallel_size
}
func (parallel_state* ps) get_data_parallel_rank() int32 {
    return ps.coordinates.data_parallel_rank
}
func (parallel_state* ps) get_data_parallel_size() int32 {
    return ps.config.data_parallel_size
}
func (parallel_state* ps) is_main_process() bool {
    return ps.config.rank == 0
}
func (parallel_state* ps) is_last_stage() bool {
    return ps.coordinates.pipeline_parallel_rank == ps.config.pipeline_parallel_size - 1
}
func (parallel_state* ps) is_first_stage() bool {
    return ps.coordinates.pipeline_parallel_rank == 0
}
