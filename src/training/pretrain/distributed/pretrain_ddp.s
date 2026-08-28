package neurx.pretrain.distributed
use neurx.distributed.comm.{process_group_state, new_process_group, process_group_rank, process_group_world_size, process_group_initialized, all_reduce_sum, process_group_state_dict, process_group_load_state_dict}
use neurx.distributed.ddp.{ddp_state, new_ddp_state, ddp_attach_process_group, ddp_is_distributed, ddp_state_dict, ddp_load_state_dict, ddp_sync_scale, ddp_finalize_step, ddp_step}
use neurx.runtime.io.{runtime_env_get}
use neurx.tensor.tensor
use neurx.tensor.new
struct pretrain_ddp_state {
    ddp_state ddp
    process_group_state process_group
    bool enabled
    int step
}
struct pretrain_ddp_sync_result {
    tensor first
    tensor second
    tensor third
}
func copy_float(float[] values) float[] {
    float[] out = float[]{cap: len(values)}
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}
func copy_int(int[] values) int[] {
    int[] out = int[]{cap: len(values)}
    int i = 0
    for i < len(values) {
        out[i] = values[i]
        i = i + 1
    }
    out
}
func parse_env_int(string value, int fallback) int {
    string trimmed = trim(value)
    if trimmed == "" {
        return fallback
    }
    int parsed = int(trimmed)
    if parsed <= 0 {
        return fallback
    }
    parsed
}
func env_int_with_fallbacks(string primary, string secondary, int fallback) int {
    int value = parse_env_int(runtime_env_get(primary, ""), -1)
    if value > 0 {
        return value
    }
    value = parse_env_int(runtime_env_get(secondary, ""), -1)
    if value > 0 {
        return value
    }
    fallback
}
func new_pretrain_ddp_state_from_env(string name, int bucket_cap, bool find_unused) pretrain_ddp_state {
    int rank = env_int_with_fallbacks("RANK", "NEURX_PRETRAIN_RANK", 0)
    int world_size = env_int_with_fallbacks("WORLD_SIZE", "NEURX_PRETRAIN_WORLD_SIZE", 1)
    string backend = runtime_env_get("DDP_BACKEND", "")
    if trim(backend) == "" {
        backend = runtime_env_get("NEURX_PRETRAIN_BACKEND", "gloo")
    }
    process_group_state pg = new_process_group(backend, rank, world_size)
    ddp_state ddp = ddp_attach_process_group(new_ddp_state(name, bucket_cap, find_unused), pg)
    pretrain_ddp_state {
        ddp: ddp,
        process_group: pg,
        enabled: ddp_is_distributed(ddp),
        step: 0,
    }
}
func pretrain_ddp_state_dict(pretrain_ddp_state state) pretrain_ddp_state {
    pretrain_ddp_state {
        ddp: ddp_state_dict(state.ddp),
        process_group: process_group_state_dict(state.process_group),
        enabled: state.enabled,
        step: state.step,
    }
}
func pretrain_ddp_load_state_dict(pretrain_ddp_state state, pretrain_ddp_state other) pretrain_ddp_state {
    pretrain_ddp_state {
        ddp: ddp_load_state_dict(state.ddp, other.ddp),
        process_group: process_group_load_state_dict(state.process_group, other.process_group),
        enabled: other.enabled,
        step: other.step,
    }
}
func pretrain_ddp_enabled(pretrain_ddp_state state) bool {
    state.enabled
}
func pretrain_ddp_world_size(pretrain_ddp_state state) int {
    process_group_world_size(state.process_group)
}
func pretrain_ddp_rank(pretrain_ddp_state state) int {
    process_group_rank(state.process_group)
}
func pretrain_ddp_sync_tensor(pretrain_ddp_state state, tensor value) tensor {
    if !state.enabled {
        return new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
    }
    float[] payload = copy_float(value.data)
    float[] reduced = all_reduce_sum(state.process_group, payload)
    int world_size = process_group_world_size(state.process_group)
    if world_size <= 0 {
        world_size = 1
    }
    int i = 0
    for i < len(reduced) {
        reduced[i] = reduced[i] / world_size
        i = i + 1
    }
    new(reduced, copy_int(value.shape), value.requires_grad)
}
func pretrain_ddp_sync3(pretrain_ddp_state state, tensor a, tensor b, tensor c) pretrain_ddp_sync_result {
    pretrain_ddp_sync_result {
        first: pretrain_ddp_sync_tensor(state, a),
        second: pretrain_ddp_sync_tensor(state, b),
        third: pretrain_ddp_sync_tensor(state, c),
    }
}
func pretrain_ddp_step(pretrain_ddp_state state) pretrain_ddp_state {
    pretrain_ddp_state {
        ddp: ddp_finalize_step(state.ddp),
        process_group: state.process_group,
        enabled: state.enabled,
        step: state.step + 1,
    }
}
