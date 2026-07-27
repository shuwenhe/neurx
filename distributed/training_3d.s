package neurx.distributed.training_3d
struct parallel_dims {
    int tp_degree
    int pp_degree
    int dp_degree
    int total_gpus
    int global_rank
    int tp_rank
    int pp_rank
    int dp_rank
    int tp_group_id
    int pp_group_id
    int dp_group_id
}

struct model_parallel_config {
    string name
    int hidden_dim
    int num_layers
    int num_attention_heads
    int num_kv_heads
    int ffn_dim
    int vocab_size
    int max_seq_len
    float dropout
    bool use_moe
    int moe_num_experts
    int moe_top_k
    float moe_capacity_factor
    parallel dims
}

struct training_config {
    int global_batch_size
    int micro_batch_size
    int gradient_accum_steps
    float learning_rate
    float lr_min
    float weight_decay
    int warmup_steps
    int total_training_steps
    string lr_schedule_type
    string optimizer_name
    float adam_beta1
    float adam_beta2
    float adam_epsilon
    float max_grad_norm
    bool use_bf16
    bool use_fp16
    float loss_scale
    bool dynamic_loss_scaling
    int save_interval
    string checkpoint_dir
    bool async_checkpoint
    int eval_interval
    int logging_interval
    bool use_gradient_checkpointing
    bool use_flash_attention
    bool use_rope_scaling
    int rope_target_length
}
enum training_phase {
    PHASE_IDLE,
    PHASE_FORWARD,
    PHASE_BACKWARD,
    PHASE_OPTIMIZER_STEP,
    PHASE_CHECKPOINTING,
    PHASE_EVALUATION
}

struct orchestrator_state {
    model_parallel_config model_cfg
    training_config train_cfg
    training_phase current_phase
    int current_step
    int current_epoch
    []pipeline_stage_state pp_stages
    pipeline_schedule schedule
    int micro_batch_counter
    float accumulated_loss
    performance_stats stats
    memory_stats mem_stats
    float step_start_time
    float epoch_start_time
    float total_train_time
}

struct pipeline_stage_state {
    int stage_id
    int first_layer_idx
    int last_layer_idx
    []int layer_indices
    [][]float input_buffer
    [][]float output_buffer
    []bool needs_gradient_checkpoint
    [][][]float activation_cache
    float forward_time_ms
    float backward_time_ms
    float comm_time_ms
}
enum schedule_type {
    SCHEDULE_1F1B,
    SCHEDULE_GPIPE,
    SCHEDULE_INTERLEAVED,
    SCHEDULE_PIPE_DREAM_FLUSH,
}

struct pipeline_schedule {
    schedule_type type
    int num_micro_batches
    int warmup_microbatches
    int steady_microbatches
    int cooldown_microbatches
    float bubble_ratio
    []schedule_instruction instructions
}

struct schedule_instruction {
    enum action_type {
        MICRO_FORWARD,
        MICRO_BACKWARD,
        MICRO_UPDATE,
        PIPE_SEND_ACTIVATION,
        PIPE_RECV_ACTIVATION,
        SYNC_POINT
    } action
    int micro_batch_id
    int stage_id
    int dependency_id
}

func create_parallel_config(
    int total_gpus,
    int tp, int pp, int dp,
    int global_rank
) parallel_dims {
    if tp * pp * dp != total_gpus {
    }
    int pp_size = tp * dp
    int pp_id = global_rank / pp_size
    int rank_in_pp = global_rank % pp_size
    int tp_rank_local = rank_in_pp % tp
    int dp_rank_local = rank_in_pp / tp
    parallel_dims {
        tp_degree: tp,
        pp_degree: pp,
        dp_degree: dp,
        total_gpus: total_gpus,
        global_rank: global_rank,
        tp_rank: tp_rank_local,
        pp_rank: pp_id,
        dp_rank: dp_rank_local,
        tp_group_id: pp_id * tp + tp_rank_local,
        pp_group_id: pp_id,
        dp_group_id: rank_in_pp,
    }
}

func validate_model_parallel_config(model_parallel_config cfg) bool {
    bool valid = true
    parallel dims = cfg.dims
    if cfg.num_attention_heads % dims.tp_degree != 0 {
        valid = false
    }
    if cfg.hidden_dim % dims.tp_degree != 0 {
        valid = false
    }
    if cfg.num_kv_heads < cfg.num_attention_heads {
        if cfg.num_kv_heads % dims.tp_degree != 0 &&
           dims.tp_degree % cfg.num_kv_heads != 0 {
        }
    }
    if cfg.num_layers % dims.pp_degree != 0 {
    }
    return valid
}

func init_orchestrator(
    model_parallel_config model_cfg,
    training_config train_cfg
) orchestrator_state {
    if !validate_model_parallel_config(model_cfg) {
    }
    int pp = model_cfg.dims.pp_degree
    int layers_per_stage = model_cfg.num_layers / pp
    int remaining_layers = model_cfg.num_layers % pp
    []pipeline_stage_state stages = []pipeline_stage_state{cap: pp}
    int s = 0
    while s < pp {
        int start_layer = s * layers_per_stage + min_int(s, remaining_layers)
        int end_layer = start_layer + layers_per_stage - 1
        if s < remaining_layers { end_layer = end_layer + 1 }
        []int layer_ids = []int{cap: end_layer - start_layer + 1}
        int l = start_layer
        while l <= end_layer {
            layer_ids = append(layer_ids, l)
            l = l + 1
        }
        pipeline_stage_state stage
        stage.stage_id = s
        stage.first_layer_idx = start_layer
        stage.last_layer_idx = end_layer
        stage.layer_indices = layer_ids
        stages[s] = stage
        s = s + 1
    }
    int num_micro_batches = train_cfg.gradient_accum_steps
    pipeline_schedule sched = build_1f1b_schedule(pp, num_micro_batches)
    perf_stats init_stats
    init_stats.total_flops = 0.0
    init_stats.total_comm_bytes = 0.0
    init_stats.steps_per_second = 0.0
    init_stats.tflops = 0.0
    mem_stats init_mem
    init_mem.peak_gpu_memory_gb = 0.0
    init_mem.current_gpu_memory_gb = 0.0
    init_mem.fragmentation_ratio = 0.0
    orchestrator_state {
        model_cfg: model_cfg,
        train_cfg: train_cfg,
        current_phase: PHASE_IDLE,
        current_step: 0,
        current_epoch: 0,
        pp_stages: stages,
        schedule: sched,
        micro_batch_counter: 0,
        accumulated_loss: 0.0,
        stats: init_stats,
        mem_stats: init_mem,
        step_start_time: 0.0,
        epoch_start_time: 0.0,
        total_train_time: 0.0,
    }
}

func append([]int arr, int val) []int {
    int n = len(arr)
    []float new_arr = []int{cap: n + 1}
    int i = 0
    while i < n { new_arr[i] = arr[i]; i = i + 1 }
    new_arr[n] = val
    new_arr
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func max_int(int a, int b) int {
    if a > b { return a }
    return b
}

func float_of_int(int n) float {
    float r = 0.0
    int i = 0
    while i < n { r = r + 1.0; i = i + 1 }
    return r
}

func build_1f1b_schedule(int num_stages, int num_micro_batches) pipeline_schedule {
    int num_warmup = num_stages - 1
    int num_steady = num_micro_batches - 2 * (num_stages - 1)
    if num_steady < 0 { num_steady = 0 }
    int num_cooldown = num_stages - 1
    float bubble = float_of_int(num_stages - 1) / float_of_int(num_micro_batches + num_stages - 1)
    []schedule_instruction instrs = []schedule_instruction{}
    int instruction_id = 0
    int mb = 0
    while mb < num_warmup && mb < num_micro_batches {
        int s = 0
        while s <= mb {
            schedule_instruction fwd_instr
            fwd_instr.action = MICRO_FORWARD
            fwd_instr.micro_batch_id = mb
            fwd_instr.stage_id = s
            fwd_instr.dependency_id = -1
            instrs = append(instrs, fwd_instr)
            instruction_id = instruction_id + 1
            s = s + 1
        }
        mb = mb + 1
    }
    int steady_mb = num_warmup
    while steady_mb < num_warmup + num_steady && steady_mb < num_micro_batches {
        int s = 0
        while s < num_stages {
            schedule_instruction fwd_instr
            fwd_instr.action = MICRO_FORWARD
            fwd_instr.micro_batch_id = steady_mb
            fwd_instr.stage_id = s
            fwd_instr.dependency_id = -1
            instrs = append(instrs, fwd_instr)
            if steady_mb >= num_warmup {
                int bw_mb = steady_mb - num_warmup
                if bw_mb < num_micro_batches {
                    schedule_instruction bwd_instr
                    bwd_instr.action = MICRO_BACKWARD
                    bwd_instr.micro_batch_id = bw_mb
                    bwd_instr.stage_id = s
                    bwd_instr.dependency_id = -1
                    instrs = append(instrs, bwd_instr)
                }
            }
            instruction_id = instruction_id + 1
            s = s + 1
        }
        steady_mb = steady_mb + 1
    }
    int cooldown_mb = max_int(num_warmup + num_steady, 0)
    while cooldown_mb < num_micro_batches + num_cooldown {
        int s = num_stages - 1
        while s >= 0 {
            int bw_mb = cooldown_mb - num_warmup
            if bw_mb >= 0 && bw_mb < num_micro_batches {
                schedule_instruction bwd_instr
                bwd_instr.action = MICRO_BACKWARD
                bwd_instr.micro_batch_id = bw_mb
                bwd_instr.stage_id = s
                bwd_instr.dependency_id = -1
                instrs = append(instrs, bwd_instr)
                instruction_id = instruction_id + 1
            }
            s = s - 1
        }
        cooldown_mb = cooldown_mb + 1
    }
    pipeline_schedule {
        type: SCHEDULE_1F1B,
        num_micro_batches: num_micro_batches,
        warmup_microbatches: num_warmup,
        steady_microbatches: num_steady,
        cooldown_microbatches: num_cooldown,
        bubble_ratio: bubble,
        instructions: instrs,
    }
}

func training_step(ref orchestrator_state orch, batch_data data) float {
    orch.current_phase = PHASE_FORWARD
    float step_time_start = get_current_time_ms()
    int micro_batch_id = 0
    while micro_batch_id < orch.train_cfg.gradient_accum_steps {
        micro_batch_data micro_data = get_micro_batch(data, micro_batch_id)
        execute_pipeline_forward(orch, micro_data, micro_batch_id)
        float loss = compute_loss(orch)
        orch.accumulated_loss = orch.accumulated_loss + loss
        execute_pipeline_backward(orch, micro_batch_id)
        micro_batch_id = micro_batch_id + 1
        orch.micro_batch_counter = orch.micro_batch_counter + 1
    }
    orch.current_phase = PHASE_OPTIMIZER_STEP
    synchronize_gradients_across_dp(orch)
    clip_gradients(orch, orch.train_cfg.max_grad_norm)
    optimizer_step(orch)
    zero_grads(orch)
    float step_time = get_current_time_ms() - step_time_start
    update_performance_stats(orch, step_time)
    if orch.current_step % orch.train_cfg.logging_interval == 0 {
        log_training_progress(orch)
    }
    if orch.train_cfg.save_interval > 0 &&
       orch.current_step % orch.train_cfg.save_interval == 0 {
        if orch.train_cfg.async_checkpoint {
            trigger_async_checkpoint(orch)
        } else {
            save_checkpoint_sync(orch)
        }
    }
    orch.current_step = orch.current_step + 1
    orch.micro_batch_counter = 0
    orch.accumulated_loss = 0.0
    orch.current_phase = PHASE_IDLE
    return orch.accumulated_loss / float_of_int(orch.train_cfg.gradient_accum_steps)
}

func execute_pipeline_forward(
    ref orchestrator_state orch,
    micro_batch_data data,
    int micro_batch_id
) {
    int my_stage = orch.model_cfg.dims.pp_rank
    int num_stages = orch.model_cfg.dims.pp_degree
    if my_stage > 0 {
        orch.pp_stages[my_stage].input_buffer = recv_activation_from_previous_stage(
            my_stage - 1, micro_batch_id
        )
    } else {
        orch.pp_stages[my_stage].input_buffer = data.input_tokens
    }
    [][]float output = run_stage_forward(
        orch,
        orch.pp_stages[my_stage],
        orch.pp_stages[my_stage].input_buffer,
        micro_batch_id
    )
    if my_stage < num_stages - 1 {
        send_activation_to_next_stage(my_stage, output, micro_batch_id)
    } else {
        orch.pp_stages[my_stage].output_buffer = output
    }
}

func run_stage_forward(
    ref orchestrator_state orch,
    pipeline_stage_state stage,
    [][]float input,
    int micro_batch_id
) [][]float {
    int num_layers_in_stage = len(stage.layer_indices)
    [][]float current_hidden = input
    int idx = 0
    while idx < num_layers_in_stage {
        int layer_idx = stage.layer_indices[idx]
        current_hidden = transformer_layer_forward(
            orch.model_cfg,
            layer_idx,
            current_hidden,
            micro_batch_id
        )
        idx = idx + 1
    }
    return current_hidden
}

func transformer_layer_forward(
    model_parallel_config cfg,
    int layer_idx,
    [][]float hidden_states,
    int micro_batch_id
) [][]float {
    hidden_states = apply_rmsnorm(hidden_states, layer_idx, cfg)
    hidden_states = multi_head_attention_forward(cfg, layer_idx, hidden_states)
    hidden_states = residual_add(hidden_states,  hidden_states)
    hidden_states = apply_rmsnorm(hidden_states, layer_idx + 1000, cfg)
    if cfg.use_moe {
        hidden_states = moe_ffn_forward(cfg, layer_idx, hidden_states)
    } else {
        hidden_states = swiglu_ffn_forward(cfg, layer_idx, hidden_states)
    }
    hidden_states = residual_add(hidden_states,  hidden_states)
    return hidden_states
}

func apply_rmsnorm([][]float x, int norm_idx, model_parallel_config cfg) [][]float { x }
func multi_head_attention_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func swiglu_ffn_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func moe_ffn_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func residual_add([][]float a, [][]float b) [][]float { a }
func execute_pipeline_backward(ref orchestrator_state orch, int micro_batch_id) {
}

func synchronize_gradients_across_dp(ref orchestrator_state orch) {
    parallel dims = orch.model_cfg.dims
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        if is_fsdp_enabled(orch) {
            grad = reduce_scatter_across_dp(grad, dims.dp_group_id, dims.dp_degree)
        } else {
            grad = all_reduce_sum_across_dp(grad, dims.dp_group_id, dims.dp_degree)
        }
        set_parameter_grad(orch, p, grad)
        p = p + 1
    }
}

func clip_gradients(ref orchestrator_state orch, float max_norm) {
    float total_norm = 0.0
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        float norm = vector_l2_norm(grad)
        total_norm = total_norm + norm * norm
        p = p + 1
    }
    total_norm = sqrt_approx(total_norm)
    if total_norm > max_norm {
        float scale = max_norm / total_norm
        p = 0
        while p < get_num_parameters(orch) {
            scale_vector(get_parameter_grad_ref(orch, p), scale)
            p = p + 1
        }
    }
}

func optimizer_step(ref orchestrator_state orch) {
    training_config tc = orch.train_cfg
    int t = orch.current_step + 1
    int p = 0
    while p < get_num_parameters(orch) {
        []float param = get_parameter(orch, p)
        []float grad = get_parameter_grad(orch, p)
        []float exp_avg = get_exp_avg(orch, p)
        []float exp_avg_sq = get_exp_avg_sq(orch, p)
        float bias_corr1 = 1.0 - pow_float(tc.adam_beta1, float_of_int(t))
        float bias_corr2 = 1.0 - pow_float(tc.adam_beta2, float_of_int(t))
        float step_size = tc.learning_rate / bias_corr1
        int i = 0
        while i < len(param) {
            exp_avg[i] = tc.adam_beta1 * exp_avg[i] + (1.0 - tc.adam_beta1) * grad[i]
            exp_avg_sq[i] = tc.adam_beta2 * exp_avg_sq[i] + (1.0 - tc.adam_beta2) * grad[i] * grad[i]
            float denom = sqrt_approx(exp_avg_sq[i] / bias_corr2) + tc.adam_epsilon
            float update = step_size * exp_avg[i] / denom
            param[i] = param[i] - tc.weight_decay * tc.learning_rate * param[i] - update
            i = i + 1
        }
        set_parameter(orch, p, param)
        set_exp_avg(orch, p, exp_avg)
        set_exp_avg_sq(orch, p, exp_avg_sq)
        p = p + 1
    }
}

func zero_grads(ref orchestrator_state orch) {
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        int i = 0
        while i < len(grad) {
            grad[i] = 0.0
            i = i + 1
        }
        p = p + 1
    }
}

struct performance_stats {
    float total_flops
    float total_comm_bytes
    float steps_per_second
    float tflops
    float gpu_utilization
    float memory_bandwidth_usage
    float comm_compute_overlap_pct
}

struct memory_stats {
    float peak_gpu_memory_gb
    float current_gpu_memory_gb
    float fragmentation_ratio
    float activation_memory_gb
    float parameter_memory_gb
    float optimizer_memory_gb
    float gradient_memory_gb
}

func update_performance_stats(ref orchestrator_state orch, float step_time_ms) {
    orch.stats.steps_per_second = 1000.0 / step_time_ms
    int H = orch.model_cfg.hidden_dim
    int L = orch.model_cfg.num_layers
    int S = orch.model_cfg.max_seq_len
    int B = orch.train_cfg.global_batch_size
    float flops_per_step = 72.0 * float_of_int(L) * float_of_int(H * H) * float_of_int(B * S)
    orch.stats.tflops = flops_per_step / (step_time_ms / 1000.0) / 1e12
    orch.stats.total_flops = orch.stats.total_flops + flops_per_step
}

func log_training_progress(orchestrator_state orch) {
    float avg_loss = orch.accumulated_loss / float_of_int(max_int(orch.micro_batch_counter, 1))
    string progress =
        "Step [" + string(orch.current_step) + "/" + string(orch.train_cfg.total_training_steps) + "] " +
        "Loss: " + string(avg_loss) + " " +
        "LR: " + string(current_learning_rate(orch)) + " " +
        "Throughput: " + string(orch.stats.steps_per_second, 2) + " steps/s " +
        "TFLOPS: " + string(orch.stats.tflops, 1) + " " +
        "GPU Mem: " + string(orch.mem_stats.current_gpu_memory_gb, 1) + " GB"
    print(progress)
}

func current_learning_rate(orchestrator_state orch) float {
    training_config tc = orch.train_cfg
    int step = orch.current_step
    int warmup = tc.warmup_steps
    int total = tc.total_training_steps
    float lr = tc.learning_rate
    float lr_min = tc.lr_min
    if step < warmup {
        lr = lr * float_of_int(step + 1) / float_of_int(warmup)
    } else {
        if tc.lr_schedule_type == "cosine" {
            float progress = float_of_int(step - warmup) / float_of_int(total - warmup)
            lr = lr_min + 0.5 * (lr - lr_min) * (1.0 + cos_approx(3.14159265 * progress))
        } else if tc.lr_schedule_type == "linear" {
            float progress = float_of_int(step - warmup) / float_of_int(total - warmup)
            lr = lr - (lr - lr_min) * progress
        }
    }
    lr
}

func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5
    int iter = 0
    while iter < 20 {
        float ng = (g + x / g) * 0.5
        if ng == g { break }
        g = ng
        iter = iter + 1
    }
    return g
}

func pow_float(float base, float exp) float {
    if exp == 0.0 { return 1.0 }
    if base <= 0.0 { return 0.0 }
    float result = 1.0
    bool neg = exp < 0.0
    if neg { exp = -exp }
    float e = 0.0
    while e < exp { result = result * base; e = e + 1.0 }
    if neg { result = 1.0 / result }
    return result
}

func cos_approx(float x) float {
    float term = 1.0
    float result = 1.0
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2*n-1) * (2*n))
        result = result + term
        n = n + 1
    }
    return result
}

func vector_l2_norm([]float v) float {
    float sum_sq = 0.0
    int i = 0
    while i < len(v) { sum_sq = sum_sq + v[i] * v[i]; i = i + 1 }
    return sqrt_approx(sum_sq)
}

func scale_vector(ref []float v, float s) {
    int i = 0
    while i < len(v) { v[i] = v[i] * s; i = i + 1 }
}

func recv_activation_from_previous_stage(int from_stage, int mb_id) [][]float { return allocate_2d(128, 8192) }
func send_activation_to_next_stage(int to_stage, [][]float act, int mb_id) {}
func reduce_scatter_across_dp([]float g, int group, int degree) []float { return g }
func all_reduce_sum_across_dp([]float g, int group, int degree) []float { return g }
func allocate_2d(int r, int c) [][]float {
    [][]float t = [][]float{cap: r}
    int i = 0
    while i < r { t[i] = []float{cap: c}; i = i + 1 }
    return t
}

func get_num_parameters(orchestrator_state o) int { return 1000 }
func get_parameter(orchestrator o, int idx) []float { return []float{} }
func get_parameter_grad(orchestrator o, int idx) []float { return []float{} }
func get_parameter_grad_ref(ref orchestrator o, int idx) []float { return []float{} }
func set_parameter(ref orchestrator o, int idx, []float v) {}
func set_parameter_grad(ref orchestrator o, int idx, []float v) {}
func get_exp_avg(orchestrator o, int idx) []float { return []float{} }
func get_exp_avg_sq(orchestrator o, int idx) []float { return []float{} }
func set_exp_avg(ref orchestrator o, int idx, []float v) {}
func set_exp_avg_sq(ref orchestrator o, int idx, []float v) {}
func compute_loss(orchestrator o) float { return 0.5 }
struct micro_batch_data { [][]float input_tokens }
func get_micro_batch(batch_data b, int id) micro_batch_data { return micro_batch_data{} }
struct batch_data {}
func is_fsdp_enabled(orchestrator o) bool { return true }
func get_current_time_ms() float { return 0.0 }
func save_checkpoint_sync(orchestrator o) {}
func trigger_async_checkpoint(orchestrator o) {}
func print(string s) {}
func string(int i) string { return "" }
func string(float f, int prec) string { return "" }
func create_neurx_200b_config_for_64gpus() model_parallel_config {
    parallel dims = create_parallel_config(64, 8, 4, 2, 0)
    model_parallel_config {
        name: "NEURX-5.2",
        hidden_dim: 12288,
        num_layers: 96,
        num_attention_heads: 128,
        num_kv_heads: 16,
        ffn_dim: 32768,
        vocab_size: 128000,
        max_seq_len: 32768,
        dropout: 0.0,
        use_moe: false,
        dims: dims,
    }
}

func create_128gpu_training_config() training_config {
    training_config {
        global_batch_size: 2048,
        micro_batch_size: 4,
        gradient_accum_steps: 512,
        learning_rate: 3e-4,
        lr_min: 3e-5,
        weight_decay: 0.1,
        warmup_steps: 2000,
        total_training_steps: 500000,
        lr_schedule_type: "cosine",
        optimizer_name: "adamw",
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        max_grad_norm: 1.0,
        use_bf16: true,
        use_fp16: false,
        loss_scale: 65536.0,
        dynamic_loss_scaling: true,
        save_interval: 5000,
        checkpoint_dir: "./checkpoints/neurx",
        async_checkpoint: true,
        eval_interval: 1000,
        logging_interval: 10,
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        use_rope_scaling: true,
        rope_target_length: 131072,
    }
}

func print_full_config_summary(model_parallel_config mcfg, training_config tcfg) string {
    parallel dims = mcfg.dims
    "╔══════════════════════════════════════════════════════════╗\n" +
    "║           NEURX-5.2 3D Parallel Training Configuration       ║\n" +
    "╠══════════════════════════════════════════════════════════╣\n" +
    "║ Model: " + mcfg.name + "\n" +
    "║ Parameters: ~" + string(estimate_params(mcfg)) + "B\n" +
    "║ Architecture:\n" +
    "║   Hidden Dim: " + string(mcfg.hidden_dim) + "\n" +
    "║   Layers: " + string(mcfg.num_layers) + "\n" +
    "║   Heads: " + string(mcfg.num_attention_heads) + " (KV: " + string(mcfg.num_kv_heads) + ")\n" +
    "║   FFN Dim: " + string(mcfg.ffn_dim) + "\n" +
    "║   Vocab Size: " + string(mcfg.vocab_size) + "\n" +
    "║   Max Seq Len: " + string(mcfg.max_seq_len) + " (" + string(mcfg.max_seq_len/1024) + "K)\n" +
    "║\n" +
    "║ 3D Parallelism:\n" +
    "║   Tensor Parallel (TP): " + string(dims.tp_degree) + "\n" +
    "║   Pipeline Parallel (PP): " + string(dims.pp_degree) + "\n" +
    "║   Data Parallel (DP/FSDP): " + string(dims.dp_degree) + "\n" +
    "║   Total GPUs: " + string(dims.total_gpus) + "\n" +
    "║\n" +
    "║ Training:\n" +
    "║   Global Batch Size: " + string(tcfg.global_batch_size) + "\n" +
    "║   Micro Batch Size: " + string(tcfg.micro_batch_size) + "\n" +
    "║   Learning Rate: " + string(tcfg.learning_rate) + "\n" +
    "║   Total Steps: " + string(tcfg.total_training_steps) + "\n" +
    "║   Precision: BF16" + "\n" +
    "║   Gradient Checkpointing: ON\n" +
    "║   Flash Attention: ON\n" +
    "║   RoPE Scaling (128K): ON\n" +
    "╚══════════════════════════════════════════════════════════╝"
}

func estimate_params(model_parallel_config cfg) float {
    float embed = float_of_int(cfg.vocab_size * cfg.hidden_dim)
    float attn_per_layer = 4.0 * float_of_int(cfg.hidden_dim * cfg.hidden_dim) *
                          float_of_int(cfg.num_kv_heads) / float_of_int(cfg.num_attention_heads)
    float ffn_per_layer = 3.0 * float_of_int(cfg.hidden_dim * cfg.ffn_dim)
    float norm_per_layer = 2.0 * float_of_int(cfg.hidden_dim)
    float per_layer = attn_per_layer + ffn_per_layer + norm_per_layer
    float total = embed + float_of_int(cfg.num_layers) * per_layer + float_of_int(cfg.hidden_dim)
    return total / 1e9
}
