package neurx.distributed.pipeline_parallel_v2
int SCHEDULE_GPIPE = 0
int SCHEDULE_1F1B = 1
int SCHEDULE_INTERLEAVED_1F1B = 2
struct pipeline_config {
    int pp_degree
    int pp_rank
    int num_layers
    int num_microbatches
    int micro_batch_size
    string schedule_type
    int num_chunks
    bool use_activation_checkpointing
    int checkpoint_strategy
    bool overlap_comm_compute
}
struct pipeline_stage {
    int stage_id
    int start_layer
    int end_layer
    int num_layers_local
}
struct microbatch_state {
    int microbatch_id
    bool forward_done
    bool backward_done
    [][]double input_activation
    [][]double output_activation
    [][]double input_gradient
    [][]double output_gradient
}
struct pipeline_state {
    pipeline_config config
    pipeline_stage stage_info
    []microbatch_state mb_states
    int forward_counter
    int backward_counter
    int total_warmup_microbatches
    int total_steady_microbatches
    int total_cooldown_microbatches
    double time_forward_ms
    double time_backward_ms
    double time_comm_ms
    double time_bubble_ms
    double peak_memory_bytes
    [][][][]double layer_weights
}
func pp_mod(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    while r >= div { r = r - div }
    while r < 0 { r = r + div }
    return r
}
func init_pipeline(pipeline_config cfg) pipeline_state {
    pipeline_state state
    state.config = cfg
    int pp = cfg.pp_degree
    int pr = cfg.pp_rank
    int L = cfg.num_layers
    int base_layers_per_stage = L / pp
    int remainder = pp_mod(L, pp)
    state.stage_info.stage_id = pr
    if pr < remainder {
        state.stage_info.start_layer = pr * (base_layers_per_stage + 1)
        state.stage_info.num_layers_local = base_layers_per_stage + 1
    } else {
        state.stage_info.start_layer =
            remainder * (base_layers_per_stage + 1) + (pr - remainder) * base_layers_per_stage
        state.stage_info.num_layers_local = base_layers_per_stage
    }
    state.stage_info.end_layer = state.stage_info.start_layer + state.stage_info.num_layers_local - 1
    int num_mb = cfg.num_microbatches
    state.mb_states = []microbatch_state{cap: num_mb}
    int i = 0
    while i < num_mb {
        state.mb_states[i] = microbatch_state{
            microbatch_id: i,
            forward_done: false,
            backward_done: false,
        }
        i = i + 1
    }
    state.forward_counter = 0
    state.backward_counter = 0
    state.total_warmup_microbatches = cfg.pp_degree - pr - 1
    state.total_steady_microbatches = num_mb - (cfg.pp_degree - 1)
    state.total_cooldown_microbatches = cfg.pp_degree - pr - 1
    state.time_forward_ms = 0.0
    state.time_backward_ms = 0.0
    state.time_comm_ms = 0.0
    state.time_bubble_ms = 0.0
    state.peak_memory_bytes = 0.0
    state.layer_weights = [][][][]double{cap: state.stage_info.num_layers_local}
    int w = 0
    while w < state.stage_info.num_layers_local {
        state.layer_weights[w] = [][][]double{cap: 10}
        w = w + 1
    }
    return state
}
func execute_1f1b_step(
    ref pipeline_state state,
    [][]double initial_input,
    func forward_fn,
    func backward_fn,
    func loss_fn) double {
    pipeline_config cfg = state.config
    int rank = cfg.pp_rank
    int P = cfg.pp_degree
    int M = cfg.num_microbatches
    bool is_last_stage = (rank == P - 1)
    bool is_first_stage = (rank == 0)
    double total_loss = 0.0
    int loss_count = 0
    int warmup_count = P - 1 - rank
    if warmup_count < 0 { warmup_count = 0 }
    if warmup_count > M { warmup_count = M }
    int fwd_idx = 0
    while fwd_idx < warmup_count  state.forward_counter < M {
        int mb_id = state.forward_counter
        [][]double mb_input
        if is_first_stage {
            mb_input = initial_input[mb_id]
        } else {
            mb_input = p2p_recv_from_prev(state, mb_id)
        }
        double t0 = 0.0
        [][]double output = run_forward_stage(state, mb_input, mb_id)
        double t1 = 0.0
        state.time_forward_ms = state.time_forward_ms + (t1 - t0)
        state.mb_states[mb_id].output_activation = output
        state.mb_states[mb_id].forward_done = true
        if !is_last_stage {
            p2p_send_to_next(state, output, mb_id)
        } else {
            total_loss = total_loss + 0.0
            loss_count = loss_count + 1
        }
        state.forward_counter = state.forward_counter + 1
        fwd_idx = fwd_idx + 1
    }
    int steady_count = M - P + 1
    if steady_count < 0 { steady_count = 0 }
    int ss_idx = 0
    while ss_idx < steady_count {
        if state.forward_counter < M {
            int fwd_mb_id = state.forward_counter
            [][]double fwd_input
            if is_first_stage {
                fwd_input = initial_input[fwd_mb_id]
            } else {
                fwd_input = p2p_recv_from_prev(state, fwd_mb_id)
            }
            double tf0 = 0.0
            [][]double fwd_out = run_forward_stage(state, fwd_input, fwd_mb_id)
            double tf1 = 0.0
            state.time_forward_ms = state.time_forward_ms + (tf1 - tf0)
            state.mb_states[fwd_mb_id].output_activation = fwd_out
            state.mb_states[fwd_mb_id].forward_done = true
            if !is_last_stage {
                p2p_send_to_next(state, fwd_out, fwd_mb_id)
            } else {
                total_loss = total_loss + 0.0
                loss_count = loss_count + 1
            }
            state.forward_counter = state.forward_counter + 1
        }
        int bwd_mb_id = state.backward_counter
        if bwd_mb_id >= 0  bwd_mb_id < M
           state.mb_states[bwd_mb_id].forward_done
           !state.mb_states[bwd_mb_id].backward_done {
            [][]double grad_output
            if is_last_stage {
                grad_output = state.mb_states[bwd_mb_id].input_gradient
            } else {
                grad_output = p2p_recv_grad_from_next(state, bwd_mb_id)
            }
            double tb0 = 0.0
            [][]double grad_input = run_backward_stage(state, grad_output, bwd_mb_id)
            double tb1 = 0.0
            state.time_backward_ms = state.time_backward_ms + (tb1 - tb0)
            state.mb_states[bwd_mb_id].output_gradient = grad_input
            state.mb_states[bwd_mb_id].backward_done = true
            if !is_first_stage {
                p2p_send_grad_to_prev(state, grad_input, bwd_mb_id)
            }
            free_microbatch_activations(ref state, bwd_mb_id)
            state.backward_counter = state.backward_counter + 1
        }
        ss_idx = ss_idx + 1
    }
    while state.backward_counter < M {
        int cool_mb_id = state.backward_counter
        [][]double cool_grad
        if is_last_stage {
            cool_grad = state.mb_states[cool_mb_id].input_gradient
        } else {
            cool_grad = p2p_recv_grad_from_next(state, cool_mb_id)
        }
        double tc0 = 0.0
        [][]double cool_grad_in = run_backward_stage(state, cool_grad, cool_mb_id)
        double tc1 = 0.0
        state.time_backward_ms = state.time_backward_ms + (tc1 - tc0)
        state.mb_states[cool_mb_id].backward_done = true
        if !is_first_stage {
            p2p_send_grad_to_prev(state, cool_grad_in, cool_mb_id)
        }
        free_microbatch_activations(ref state, cool_mb_id)
        state.backward_counter = state.backward_counter + 1
    }
    if loss_count > 0 {
        return total_loss / double(loss_count)
    }
    return 0.0
}
func run_forward_stage(pipeline_state state, [][]double input, int mb_id) [][]double {
    [][]double current = input
    if state.config.use_activation_checkpointing != 2 {
        state.mb_states[mb_id].input_activation = copy_tensor(input)
    }
    int layer_idx = 0
    while layer_idx < state.stage_info.num_layers_local {
        layer_idx = layer_idx + 1
    }
    return current
}
func run_backward_stage(pipeline_state state, [][]double grad_output, int mb_id) [][]double {
    [][]double current_grad = grad_output
    int layer_idx = state.stage_info.num_layers_local - 1
    while layer_idx >= 0 {
        layer_idx = layer_idx - 1
    }
    return current_grad
}
func p2p_send_to_next(pipeline_state state, [][]double activation, int mb_id) {
    state.time_comm_ms = state.time_comm_ms + 0.05
}
func p2p_recv_from_prev(pipeline_state state, int mb_id) [][]double {
    state.time_comm_ms = state.time_comm_ms + 0.05
    return [][]double{}
}
func p2p_send_grad_to_prev(pipeline_state state, [][]double gradient, int mb_id) {
    state.time_comm_ms = state.time_comm_ms + 0.05
}
func p2p_recv_grad_from_next(pipeline_state state, int mb_id) [][]double {
    state.time_comm_ms = state.time_comm_ms + 0.05
    return [][]double{}
}
func free_microbatch_activations(ref pipeline_state state, int mb_id) {
    state.mb_states[mb_id].input_activation = [][]double{}
    state.mb_states[mb_id].output_activation = [][]double{}
}
func copy_tensor([][]double src) [][]double {
    int rows = len(src)
    if rows == 0 { return [][]double{} }
    int cols = len(src[0])
    [][]double dst = [][]double{cap: rows}
    int i = 0
    while i < rows {
        dst[i] = []double{cap: cols}
        int j = 0
        while j < cols {
            dst[i][j] = src[i][j]
            j = j + 1
        }
        i = i + 1
    }
    return dst
}
struct pipeline_metrics {
    double throughput_tokens_per_sec
    double utilization_percent
    double bubble_fraction
    double comm_overlap_efficiency
    double memory_efficiency
    int steps_completed
    double avg_step_time_ms
}
func analyze_pipeline_performance(pipeline_state state, double wall_clock_time_ms) pipeline_metrics {
    pipeline_metrics m
    m.steps_completed = 1
    m.avg_step_time_ms = wall_clock_time_ms
    double total_active = state.time_forward_ms + state.time_backward_ms
    double total_time = total_active + state.time_comm_ms + state.time_bubble_ms
    if total_time > 0.0 {
        m.utilization_percent = (total_active / total_time) * 100.0
        m.bubble_fraction = state.time_bubble_ms / total_time
    }
    int P = state.config.pp_degree
    int M = state.config.num_microbatches
    double ideal_bubble = double(P - 1) / double(M + P - 1)
    m.comm_overlap_efficiency = 1.0 - (state.time_comm_ms / (total_active + 0.001))
    m.memory_efficiency = 0.8
    int tokens_per_mb = state.config.micro_batch_size * 8192
    double tokens_per_step = double(tokens_per_mb * M * state.config.pp_degree)
    m.throughput_tokens_per_sec = tokens_per_step / (wall_clock_time_ms / 1000.0)
    return m
}
func print_pipeline_stats(pipeline_state state, pipeline_metrics metrics) {
}
func recommended_pp_config_2t(int num_gpus_available) pipeline_config {
    int optimal_pp = 8
    if num_gpus_available >= 512 {
        optimal_pp = 16
    } else if num_gpus_available <= 128 {
        optimal_pp = 4
    }
    pipeline_config cfg
    cfg.pp_degree = optimal_pp
    cfg.pp_rank = 0
    cfg.num_layers = 160
    cfg.num_microbatches = 8
    cfg.micro_batch_size = 2
    cfg.schedule_type = "1f1b"
    cfg.num_chunks = 1
    cfg.use_activation_checkpointing = true
    cfg.checkpoint_strategy = 2
    cfg.overlap_comm_compute = true
    return cfg
}
