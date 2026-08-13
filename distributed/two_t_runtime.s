package neurx.distributed.two_t_runtime
use neurx.distributed.comm.{process_group_state, new_process_group, process_group_state_dict, process_group_load_state_dict, all_gather, reduce_scatter_sum, p2p_send, p2p_recv}
use neurx.distributed.ddp.{ddp_state, new_ddp_state, ddp_attach_process_group, ddp_is_distributed, ddp_state_dict, ddp_load_state_dict, ddp_sync_scale, ddp_finalize_step}
use neurx.distributed.pp.{pipeline_parallel_state, new_pipeline_parallel_state, pipeline_parallel_state_dict, pipeline_parallel_load_state_dict, pp_assign_default_stage_ranks, pp_prepare_schedule, pp_next_microbatch, pp_pipeline_depth, pp_total_slots, pp_stage_id, pp_microbatch_id, pp_step}
use neurx.distributed.tp.{tp_state, new_tp_state, tp_enabled, tp_state_dict, tp_load_state_dict}
use neurx.distributed.two_t_training.{two_t_training_plan, new_two_t_training_plan, two_t_training_plan_state_dict, two_t_training_plan_load_state_dict, two_t_training_plan_step, two_t_training_plan_summary, two_t_mod_nonneg}
use neurx.data.loader.dataloader.{dataloader_state, dataloader_step_output, new_state, next_batch, reset_state, has_next}
use neurx.dataset_text.{text_corpus_state, load_text_corpus, build_vocab, encode_text}
use neurx.model.model_2t_config.{model_2t_config, new_2t_model_config, calculate_2t_model_parameters, calculate_2t_memory_requirements, calculate_2t_communication_volume, estimate_2t_training_time}
use neurx.model.llm.gpt_large_train.{gpt_large_backward_result, transformer_backward, embedding_apply_grad, tensor_from_ints, one_hot_tensor, scale_tensor, exp_approx, ramp_tensor, zero_tensor, transformer_layer_optimizer_state, new_backbone_optimizer_states, copy_layer_optimizer_state}
use neurx.ops.{sub, matmul, softmax_last_dim, sum_first_dim, lm_head_logits, cross_entropy, embedding_lookup}
use neurx.optimizer.optim.{adamw_optimizer, adamw_step_output, adamw_step_state, new_adamw, clip_grad_tensor}
use neurx.scheduler.schedulers.{cosine_scheduler_compute_lr}
use neurx.checkpoint.{checkpoint, new_checkpoint, save_checkpoint, load_checkpoint, checkpoint_state_dict, checkpoint_load_state_dict, checkpoint_params, checkpoint_step, checkpoint_loss}
use neurx.runtime.io.{runtime_file_exists, runtime_read_text_file, runtime_write_text_file, runtime_make_dirs}
use neurx.tensor.tensor
use neurx.tensor.new
use neurx.tensor.transpose
use neurx.transformer.{transformer, transformer_config, transformer_init, transformer_forward, transformer_state_dict, transformer_load_state_dict}
struct two_t_training_batch {
    tensor input_ids
    tensor target_ids
    int valid_tokens
}
struct two_t_forward_pass_result {
    tensor hidden
    tensor backbone_output
    tensor logits
    tensor loss
    int valid_tokens
}
struct two_t_data_state {
    text_corpus_state corpus
    dataloader_state train_loader
    dataloader_state valid_loader
    string train_path
    int train_tokens
    int valid_tokens
}
struct two_t_checkpoint_runtime_state {
    string path
    bool enabled
    int save_every_steps
    int last_saved_step
    int rng_seed
}
struct two_t_runtime_state {
    model_2t_config model
    two_t_training_plan plan
    process_group_state process_group
    ddp_state ddp
    tp_state tp
    pipeline_parallel_state pp
    two_t_data_state data
    two_t_checkpoint_runtime_state checkpoint
    transformer backbone
    tensor token_embedding
    tensor lm_head_weight
    tensor lm_head_bias
    tensor tp_head_weight_shard
    tensor tp_head_bias_shard
    []transformer_layer_optimizer_state backbone_optimizers
    adamw_optimizer embedding_optimizer
    adamw_optimizer head_weight_optimizer
    adamw_optimizer head_bias_optimizer
    int step
    int microbatch_step
    float base_lr
    float min_lr
    int warmup_steps
    int cosine_decay_steps
    float grad_clip_norm
    float last_loss
    float last_perplexity
    int train_tokens_seen
    int valid_tokens_seen
}
func copy_float([]float values) []float {
    int n = len(values)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}
func copy_int([]int values) []int {
    int n = len(values)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = values[i]
        i = i + 1
    }
    out
}
func copy_tensor(tensor value) tensor {
    new(copy_float(value.data), copy_int(value.shape), value.requires_grad)
}
func two_t_copy_backbone_optimizers([]transformer_layer_optimizer_state states) []transformer_layer_optimizer_state {
    []transformer_layer_optimizer_state out = []transformer_layer_optimizer_state{cap: len(states)}
    int i = 0
    while i < len(states) {
        out[i] = copy_layer_optimizer_state(states[i])
        i = i + 1
    }
    out
}
func two_t_single_tensor_params(tensor value) []tensor {
    []tensor params = []tensor{cap: 1}
    params.push(value)
    params
}
func two_t_first_checkpoint_tensor(checkpoint saved) tensor {
    []tensor params = checkpoint_params(saved)
    tensor out = params[0]
    int i = 0
    while i < len(params) {
        if i == 0 {
            out = params[i]
            i = len(params)
        }
        i = i + 1
    }
    out
}
func two_t_layer_optimizer_text(string prefix, transformer_layer_optimizer_state state) string {
    string out = ""
    out = out + two_t_adamw_optimizer_text(prefix + "w_q.", state.w_q)
    out = out + two_t_adamw_optimizer_text(prefix + "w_k.", state.w_k)
    out = out + two_t_adamw_optimizer_text(prefix + "w_v.", state.w_v)
    out = out + two_t_adamw_optimizer_text(prefix + "w_o.", state.w_o)
    out = out + two_t_adamw_optimizer_text(prefix + "w_ff1.", state.w_ff1)
    out = out + two_t_adamw_optimizer_text(prefix + "w_ff2.", state.w_ff2)
    out = out + two_t_adamw_optimizer_text(prefix + "b_ff1.", state.b_ff1)
    out = out + two_t_adamw_optimizer_text(prefix + "b_ff2.", state.b_ff2)
    out = out + two_t_adamw_optimizer_text(prefix + "w_up.", state.w_up)
    out = out + two_t_adamw_optimizer_text(prefix + "b_up.", state.b_up)
    out
}
func two_t_backbone_optimizer_text([]transformer_layer_optimizer_state states) string {
    string out = ""
    int i = 0
    while i < len(states) {
        out = out + two_t_layer_optimizer_text("backbone.layer" + string(i) + ".", states[i])
        i = i + 1
    }
    out
}
func two_t_layer_optimizer_from_text([]string lines, string prefix, transformer_layer_optimizer_state fallback) transformer_layer_optimizer_state {
    transformer_layer_optimizer_state {
        w_q: two_t_adamw_optimizer_from_text(lines, prefix + "w_q.", fallback.w_q),
        w_k: two_t_adamw_optimizer_from_text(lines, prefix + "w_k.", fallback.w_k),
        w_v: two_t_adamw_optimizer_from_text(lines, prefix + "w_v.", fallback.w_v),
        w_o: two_t_adamw_optimizer_from_text(lines, prefix + "w_o.", fallback.w_o),
        w_ff1: two_t_adamw_optimizer_from_text(lines, prefix + "w_ff1.", fallback.w_ff1),
        w_ff2: two_t_adamw_optimizer_from_text(lines, prefix + "w_ff2.", fallback.w_ff2),
        b_ff1: two_t_adamw_optimizer_from_text(lines, prefix + "b_ff1.", fallback.b_ff1),
        b_ff2: two_t_adamw_optimizer_from_text(lines, prefix + "b_ff2.", fallback.b_ff2),
        w_up: two_t_adamw_optimizer_from_text(lines, prefix + "w_up.", fallback.w_up),
        b_up: two_t_adamw_optimizer_from_text(lines, prefix + "b_up.", fallback.b_up),
    }
}
func two_t_backbone_optimizer_from_text([]string lines, []transformer_layer_optimizer_state fallback) []transformer_layer_optimizer_state {
    []transformer_layer_optimizer_state out = []transformer_layer_optimizer_state{cap: len(fallback)}
    int i = 0
    while i < len(fallback) {
        out[i] = two_t_layer_optimizer_from_text(lines, "backbone.layer" + string(i) + ".", fallback[i])
        i = i + 1
    }
    out
}
func copy_float_slice([]float values, int start, int end) []float {
    int safe_start = start
    int safe_end = end
    if safe_start < 0 {
        safe_start = 0
    }
    if safe_end < safe_start {
        safe_end = safe_start
    }
    int n = len(values)
    if safe_start > n {
        safe_start = n
    }
    if safe_end > n {
        safe_end = n
    }
    []float out = []float{cap: safe_end - safe_start}
    int i = safe_start
    int j = 0
    while i < safe_end {
        out[j] = values[i]
        i = i + 1
        j = j + 1
    }
    out
}
func copy_int_slice([]int values, int start, int end) []int {
    int safe_start = start
    int safe_end = end
    if safe_start < 0 {
        safe_start = 0
    }
    if safe_end < safe_start {
        safe_end = safe_start
    }
    int n = len(values)
    if safe_start > n {
        safe_start = n
    }
    if safe_end > n {
        safe_end = n
    }
    []int out = []int{cap: safe_end - safe_start}
    int i = safe_start
    int j = 0
    while i < safe_end {
        out[j] = values[i]
        i = i + 1
        j = j + 1
    }
    out
}
func tensor_numel_from_shape([]int shape) int {
    int total = 1
    int i = 0
    while i < len(shape) {
        total = total * shape[i]
        i = i + 1
    }
    total
}
func tensor_from_flat_slice(tensor value, int start, int end) tensor {
    new(copy_float_slice(value.data, start, end), make_int_array_1(end - start), value.requires_grad)
}
func tensor_1d_concat(tensor left, tensor right) tensor {
    int left_n = len(left.data)
    int right_n = len(right.data)
    []float out = []float{cap: left_n + right_n}
    int i = 0
    while i < left_n {
        out[i] = left.data[i]
        i = i + 1
    }
    int j = 0
    while j < right_n {
        out[left_n + j] = right.data[j]
        j = j + 1
    }
    new(out, make_int_array_1(left_n + right_n), left.requires_grad || right.requires_grad)
}
func tensor_2d_row_slice(tensor value, int row_start, int row_end) tensor {
    if len(value.shape) < 2 {
        return tensor_from_flat_slice(value, row_start, row_end)
    }
    int rows = value.shape[0]
    int cols = value.shape[1]
    int safe_start = row_start
    int safe_end = row_end
    if safe_start < 0 {
        safe_start = 0
    }
    if safe_end > rows {
        safe_end = rows
    }
    if safe_end < safe_start {
        safe_end = safe_start
    }
    int total = (safe_end - safe_start) * cols
    []float out = []float{cap: total}
    int r = safe_start
    int idx = 0
    while r < safe_end {
        int c = 0
        while c < cols {
            out[idx] = value.data[r * cols + c]
            idx = idx + 1
            c = c + 1
        }
        r = r + 1
    }
    new(out, make_int_array_2(safe_end - safe_start, cols), value.requires_grad)
}
func tensor_2d_col_slice(tensor value, int col_start, int col_end) tensor {
    if len(value.shape) < 2 {
        return tensor_from_flat_slice(value, col_start, col_end)
    }
    int rows = value.shape[0]
    int cols = value.shape[1]
    int safe_start = col_start
    int safe_end = col_end
    if safe_start < 0 {
        safe_start = 0
    }
    if safe_end > cols {
        safe_end = cols
    }
    if safe_end < safe_start {
        safe_end = safe_start
    }
    int local_cols = safe_end - safe_start
    []float out = []float{cap: rows * local_cols}
    int r = 0
    int idx = 0
    while r < rows {
        int c = safe_start
        while c < safe_end {
            out[idx] = value.data[r * cols + c]
            idx = idx + 1
            c = c + 1
        }
        r = r + 1
    }
    new(out, make_int_array_2(rows, local_cols), value.requires_grad)
}
func tensor_2d_col_update(tensor base, tensor shard, int col_start, int col_end) tensor {
    if len(base.shape) < 2 || len(shard.shape) < 2 {
        return copy_tensor(base)
    }
    int rows = base.shape[0]
    int cols = base.shape[1]
    int local_cols = col_end - col_start
    if local_cols <= 0 {
        return copy_tensor(base)
    }
    []float out = copy_float(base.data)
    int r = 0
    while r < rows {
        int c = 0
        while c < local_cols {
            int dst = r * cols + (col_start + c)
            int src = r * local_cols + c
            if dst >= 0  dst < len(out)  src >= 0  src < len(shard.data) {
                out[dst] = shard.data[src]
            }
            c = c + 1
        }
        r = r + 1
    }
    new(out, copy_int(base.shape), base.requires_grad || shard.requires_grad)
}
func tensor_2d_row_update(tensor base, tensor shard, int row_start, int row_end) tensor {
    if len(base.shape) < 2 || len(shard.shape) < 2 {
        return copy_tensor(base)
    }
    int rows = base.shape[0]
    int cols = base.shape[1]
    int safe_start = row_start
    int safe_end = row_end
    if safe_start < 0 {
        safe_start = 0
    }
    if safe_end > rows {
        safe_end = rows
    }
    if safe_end < safe_start {
        safe_end = safe_start
    }
    []float out = copy_float(base.data)
    int local_rows = safe_end - safe_start
    int r = 0
    while r < local_rows {
        int c = 0
        while c < cols {
            int dst = (safe_start + r) * cols + c
            int src = r * cols + c
            if dst >= 0  dst < len(out)  src >= 0  src < len(shard.data) {
                out[dst] = shard.data[src]
            }
            c = c + 1
        }
        r = r + 1
    }
    new(out, copy_int(base.shape), base.requires_grad || shard.requires_grad)
}
func tensor_1d_update(tensor base, tensor shard, int start, int end) tensor {
    int local = end - start
    if local <= 0 {
        return copy_tensor(base)
    }
    []float out = copy_float(base.data)
    int i = 0
    while i < local {
        int dst = start + i
        if dst >= 0  dst < len(out)  i < len(shard.data) {
            out[dst] = shard.data[i]
        }
        i = i + 1
    }
    new(out, copy_int(base.shape), base.requires_grad || shard.requires_grad)
}
func tensor_scalar(float value) tensor {
    new([value], [1], false)
}
func tensor_scalar_value(tensor value) float {
    if len(value.data) > 0 {
        return value.data[0]
    }
    0.0
}
func make_int_array_1(int v) []int {
    []int out = []int{cap: 1}
    out[0] = v
    out
}
func make_int_array_2(int a, int b) []int {
    []int out = []int{cap: 2}
    out[0] = a
    out[1] = b
    out
}
func make_int_sequence(int count, int start, int modulo) []int {
    []int values = []int{cap: count}
    int i = 0
    while i < count {
        int next = start + i
        if modulo > 0 {
            next = two_t_mod_nonneg(next, modulo)
        }
        values[i] = next
        i = i + 1
    }
    values
}
func two_t_slice_tokens([]int tokens, int start, int end) []int {
    copy_int_slice(tokens, start, end)
}
func two_t_default_corpus_text() string {
    "neurx trains large language models with real distributed systems.\n" +
    "we want data loading, checkpointing, tensor parallelism, zero, and pipeline parallelism.\n" +
    "this smoke run uses a tiny corpus, but the path is now real.\n"
}
func two_t_build_data_state(string train_path, int batch_size, int seq_len, int valid_ratio_percent) two_t_data_state {
    text_corpus_state corpus = load_text_corpus(train_path)
    string raw = corpus.raw_text
    if raw == "" {
        raw = two_t_default_corpus_text()
        []string vocab = build_vocab(raw)
        []int token_ids = encode_text(raw, vocab)
        corpus = text_corpus_state {
            path: train_path,
            raw_text: raw,
            lines: []string{cap: 0},
            vocab: vocab,
            token_ids: token_ids,
            line_count: 0,
            char_count: len(raw),
            token_count: len(token_ids),
        }
    }
    int total_tokens = len(corpus.token_ids)
    int valid_count = total_tokens * valid_ratio_percent / 100
    if valid_count < seq_len + 1 {
        valid_count = seq_len + 1
    }
    if valid_count > total_tokens / 2 {
        valid_count = total_tokens / 2
    }
    int train_count = total_tokens - valid_count
    if train_count < seq_len + 1 {
        train_count = seq_len + 1
    }
    []int train_tokens = two_t_slice_tokens(corpus.token_ids, 0, train_count)
    []int valid_tokens = two_t_slice_tokens(corpus.token_ids, train_count, total_tokens)
    dataloader_state train_loader = new_state(train_tokens, batch_size, seq_len)
    dataloader_state valid_loader = new_state(valid_tokens, batch_size, seq_len)
    two_t_data_state {
        corpus: corpus,
        train_loader: train_loader,
        valid_loader: valid_loader,
        train_path: train_path,
        train_tokens: len(train_tokens),
        valid_tokens: len(valid_tokens),
    }
}
func two_t_loader_batch_to_tensor(dataloader_step_output batch_output) two_t_training_batch {
    int input_count = len(batch_output.batch.input_ids)
    int target_count = len(batch_output.batch.target_ids)
    two_t_training_batch {
        input_ids: tensor_from_ints(batch_output.batch.input_ids, make_int_array_1(input_count)),
        target_ids: tensor_from_ints(batch_output.batch.target_ids, make_int_array_1(target_count)),
        valid_tokens: batch_output.batch.valid_tokens,
    }
}
func two_t_tp_col_range(two_t_runtime_state state) []int {
    int tp_world = state.plan.tensor_parallel_degree
    if tp_world <= 0 {
        tp_world = 1
    }
    int tp_rank = two_t_mod_nonneg(state.tp.rank, tp_world)
    int total_cols = 1
    if len(state.lm_head_weight.shape) >= 2 {
        total_cols = state.lm_head_weight.shape[1]
    }
    int per_rank = total_cols / tp_world
    if per_rank <= 0 {
        per_rank = total_cols
    }
    int start = tp_rank * per_rank
    int end = start + per_rank
    if end > total_cols {
        end = total_cols
    }
    make_int_array_2(start, end)
}
func two_t_tp_row_range(two_t_runtime_state state) []int {
    int tp_world = state.plan.tensor_parallel_degree
    if tp_world <= 0 {
        tp_world = 1
    }
    int tp_rank = two_t_mod_nonneg(state.tp.rank, tp_world)
    int total_rows = 1
    if len(state.token_embedding.shape) >= 2 {
        total_rows = state.token_embedding.shape[0]
    }
    int per_rank = total_rows / tp_world
    if per_rank <= 0 {
        per_rank = total_rows
    }
    int start = tp_rank * per_rank
    int end = start + per_rank
    if end > total_rows {
        end = total_rows
    }
    make_int_array_2(start, end)
}
func two_t_tp_vocab_range(two_t_runtime_state state) []int {
    two_t_tp_row_range(state)
}
func two_t_tp_gather_logits(two_t_runtime_state state, tensor local_logits) tensor {
    []float gathered = all_gather(state.process_group, local_logits.data)
    _ = gathered
    copy_tensor(local_logits)
}
func two_t_tp_sync_hidden(two_t_runtime_state state, tensor hidden) tensor {
    []float payload = all_gather(state.process_group, hidden.data)
    _ = payload
    copy_tensor(hidden)
}
func two_t_zero_reduce_scatter(two_t_runtime_state state, tensor grad) tensor {
    []float payload = reduce_scatter_sum(state.process_group, grad.data)
    _ = payload
    copy_tensor(grad)
}
func two_t_pipeline_exchange(two_t_runtime_state state, tensor value, bool send_forward) two_t_runtime_state {
    int current_stage = pp_stage_id(state.pp)
    int target_rank = current_stage
    if send_forward {
        target_rank = current_stage + 1
    } else {
        target_rank = current_stage - 1
    }
    process_group_state pg = state.process_group
    if target_rank >= 0  target_rank < state.plan.world_size {
        if send_forward {
            pg = p2p_send(pg, target_rank, value.data)
        } else {
            []float payload = p2p_recv(pg, target_rank, len(value.data))
            pg = process_group_state_dict(pg)
            _ = payload
        }
    }
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: pg,
        ddp: state.ddp,
        tp: state.tp,
        pp: state.pp,
        data: state.data,
        checkpoint: state.checkpoint,
        backbone: state.backbone,
        token_embedding: state.token_embedding,
        lm_head_weight: state.lm_head_weight,
        lm_head_bias: state.lm_head_bias,
        tp_head_weight_shard: state.tp_head_weight_shard,
        tp_head_bias_shard: state.tp_head_bias_shard,
        backbone_optimizers: two_t_copy_backbone_optimizers(state.backbone_optimizers),
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: state.head_weight_optimizer,
        head_bias_optimizer: state.head_bias_optimizer,
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        train_tokens_seen: state.train_tokens_seen,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func model_preview_config() model_2t_config {
    model_2t_config cfg = new_2t_model_config()
    cfg.hidden_dim = 128
    cfg.num_layers = 4
    cfg.num_attention_heads = 8
    cfg.num_kv_heads = 2
    cfg.intermediate_dim = 512
    cfg.vocab_size = 4096
    cfg.max_seq_len = 64
    cfg
}
func two_t_effective_lr(two_t_runtime_state state) float {
    cosine_scheduler_compute_lr(
        state.base_lr,
        state.min_lr,
        state.warmup_steps,
        state.cosine_decay_steps,
        state.step
    )
}
func two_t_tp_scale(two_t_runtime_state state) float {
    if tp_enabled(state.tp) {
        int tp_degree = state.tp.world_size
        if tp_degree > 0 {
            return 1.0 / float(tp_degree)
        }
    }
    1.0
}
func two_t_zero_scale(two_t_runtime_state state) float {
    int dp_degree = state.plan.data_parallel_degree
    if state.plan.zero_stage <= 0 {
        return 1.0
    }
    if dp_degree <= 1 {
        return 1.0
    }
    1.0 / float(dp_degree)
}
func two_t_runtime_forward(two_t_runtime_state state, two_t_training_batch batch) two_t_forward_pass_result {
    tensor hidden = embedding_lookup(state.token_embedding, batch.input_ids, 0)
    hidden = two_t_tp_sync_hidden(state, hidden)
    tensor backbone_output = transformer_forward(state.backbone, hidden)
    tensor local_logits = lm_head_logits(backbone_output, state.tp_head_weight_shard, state.tp_head_bias_shard)
    tensor logits = two_t_tp_gather_logits(state, local_logits)
    tensor loss = cross_entropy(logits, batch.target_ids, -1, "mean", 0.0, -1)
    two_t_forward_pass_result {
        hidden: hidden,
        backbone_output: backbone_output,
        logits: logits,
        loss: loss,
        valid_tokens: batch.valid_tokens,
    }
}
func two_t_runtime_backward(two_t_runtime_state state, two_t_training_batch batch, two_t_forward_pass_result forward) two_t_runtime_state {
    tensor probabilities = softmax_last_dim(forward.logits)
    tensor targets = one_hot_tensor(batch.target_ids, state.model.vocab_size)
    tensor grad_logits = sub(probabilities, targets)
    float token_scale = 1.0
    if forward.valid_tokens > 0 {
        token_scale = 1.0 / float(forward.valid_tokens)
    }
    grad_logits = scale_tensor(grad_logits, token_scale * two_t_tp_scale(state) * two_t_zero_scale(state) * ddp_sync_scale(state.ddp))
    []int shard_range = two_t_tp_col_range(state)
    tensor local_grad_logits = tensor_2d_col_slice(grad_logits, shard_range[0], shard_range[1])
    tensor hidden_t = transpose(forward.backbone_output, 0, 1)
    tensor grad_head_weight = matmul(hidden_t, local_grad_logits)
    tensor grad_head_bias = sum_first_dim(local_grad_logits, false)
    tensor grad_hidden = matmul(local_grad_logits, transpose(state.tp_head_weight_shard, 0, 1))
    float lr = two_t_effective_lr(state)
    tensor reduced_head_weight = two_t_zero_reduce_scatter(state, grad_head_weight)
    tensor reduced_head_bias = two_t_zero_reduce_scatter(state, grad_head_bias)
    tensor reduced_hidden = two_t_zero_reduce_scatter(state, grad_hidden)
    tensor clipped_head_weight = clip_grad_tensor(reduced_head_weight, state.grad_clip_norm, 0.000001)
    tensor clipped_head_bias = clip_grad_tensor(reduced_head_bias, state.grad_clip_norm, 0.000001)
    tensor clipped_hidden = clip_grad_tensor(reduced_hidden, state.grad_clip_norm, 0.000001)
    adamw_step_output head_weight_step = adamw_step_state(state.head_weight_optimizer, state.tp_head_weight_shard, clipped_head_weight)
    adamw_step_output head_bias_step = adamw_step_state(state.head_bias_optimizer, state.tp_head_bias_shard, clipped_head_bias)
    gpt_large_backward_result bw = transformer_backward(
        state.backbone,
        forward.hidden,
        clipped_hidden,
        state.backbone_optimizers
    )
    tensor next_embedding = embedding_apply_grad(
        state.token_embedding,
        batch.input_ids,
        bw.grad_input,
        lr
    )
    next_embedding = tensor_1d_update(next_embedding, next_embedding, 0, len(next_embedding.data))
    float loss_value = tensor_scalar_value(forward.loss)
    float perplexity = exp_approx(loss_value)
    tensor next_full_head_weight = tensor_2d_col_update(state.lm_head_weight, head_weight_step.params, shard_range[0], shard_range[1])
    tensor next_full_head_bias = tensor_1d_update(state.lm_head_bias, head_bias_step.params, shard_range[0], shard_range[1])
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: state.process_group,
        ddp: ddp_finalize_step(state.ddp),
        tp: state.tp,
        pp: pp_next_microbatch(state.pp),
        backbone: bw.updated_backbone,
        token_embedding: next_embedding,
        lm_head_weight: next_full_head_weight,
        lm_head_bias: next_full_head_bias,
        tp_head_weight_shard: head_weight_step.params,
        tp_head_bias_shard: head_bias_step.params,
        backbone_optimizers: bw.backbone_optimizers,
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: head_weight_step.optimizer,
        head_bias_optimizer: head_bias_step.optimizer,
        step: state.step + 1,
        microbatch_step: state.microbatch_step + 1,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: loss_value,
        last_perplexity: perplexity,
        train_tokens_seen: state.train_tokens_seen + batch.valid_tokens,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func two_t_new_training_batch(int token_count, int vocab_size, int offset) two_t_training_batch {
    []int input_values = make_int_sequence(token_count, offset, vocab_size)
    []int target_values = make_int_sequence(token_count, offset + 1, vocab_size)
    two_t_training_batch {
        input_ids: tensor_from_ints(input_values, make_int_array_1(token_count)),
        target_ids: tensor_from_ints(target_values, make_int_array_1(token_count)),
        valid_tokens: token_count,
    }
}
func two_t_new_pipeline_state(two_t_training_plan plan) pipeline_parallel_state {
    int stage_id = 0
    if plan.pipeline_parallel_degree > 0 {
        stage_id = two_t_mod_nonneg(plan.rank, plan.pipeline_parallel_degree)
    }
    int chunks = plan.batch_size
    if plan.micro_batch_size > 0 {
        chunks = plan.batch_size / plan.micro_batch_size
    }
    if chunks <= 0 {
        chunks = 1
    }
    pipeline_parallel_state pp = new_pipeline_parallel_state(
        "two_t_pipeline",
        "1f1b",
        plan.pipeline_parallel_degree,
        chunks,
        stage_id,
        plan.world_size,
        plan.rank
    )
    pp = pp_assign_default_stage_ranks(pp)
    pp = pp_prepare_schedule(pp)
    pp
}
func new_two_t_runtime_state(model_2t_config model, two_t_training_plan plan, int rank, int world_size, string train_path, string checkpoint_path) two_t_runtime_state {
    process_group_state pg = new_process_group(plan.backend, rank, world_size)
    ddp_state ddp = ddp_attach_process_group(new_ddp_state("two_t_runtime", 256, false), pg)
    tp_state tp = new_tp_state(plan.tensor_parallel_degree, two_t_mod_nonneg(rank, plan.tensor_parallel_degree), model.hidden_dim)
    pipeline_parallel_state pp = two_t_new_pipeline_state(plan)
    two_t_data_state data = two_t_build_data_state(train_path, plan.batch_size, plan.seq_len, 10)
    transformer_config backbone_config = transformer_config {
        num_layers: model.num_layers,
        num_heads: model.num_attention_heads,
        d_model: model.hidden_dim,
        d_ff: model.intermediate_dim,
        dropout: 0.0,
    }
    transformer backbone = transformer_init(backbone_config)
    tensor token_embedding = ramp_tensor(make_int_array_2(model.vocab_size, model.hidden_dim), 0.01)
    tensor lm_head_weight = ramp_tensor(make_int_array_2(model.hidden_dim, model.vocab_size), 0.005)
    tensor lm_head_bias = zero_tensor(make_int_array_1(model.vocab_size))
    int tp_world = plan.tensor_parallel_degree
    if tp_world <= 0 {
        tp_world = 1
    }
    int tp_rank = two_t_mod_nonneg(rank, tp_world)
    int tp_cols = model.vocab_size / tp_world
    if tp_cols <= 0 {
        tp_cols = model.vocab_size
    }
    int tp_start = tp_rank * tp_cols
    int tp_end = tp_start + tp_cols
    if tp_end > model.vocab_size {
        tp_end = model.vocab_size
    }
    tensor tp_head_weight_shard = tensor_2d_col_slice(lm_head_weight, tp_start, tp_end)
    tensor tp_head_bias_shard = tensor_from_flat_slice(lm_head_bias, tp_start, tp_end)
    two_t_runtime_state {
        model: model,
        plan: plan,
        process_group: pg,
        ddp: ddp,
        tp: tp,
        pp: pp,
        data: data,
        checkpoint: two_t_checkpoint_runtime_state {
            path: checkpoint_path,
            enabled: checkpoint_path != "",
            save_every_steps: 1,
            last_saved_step: 0,
            rng_seed: 1337,
        },
        backbone: backbone,
        token_embedding: token_embedding,
        lm_head_weight: lm_head_weight,
        lm_head_bias: lm_head_bias,
        tp_head_weight_shard: tp_head_weight_shard,
        tp_head_bias_shard: tp_head_bias_shard,
        backbone_optimizers: new_backbone_optimizer_states(backbone, 0.00025, 0.9, 0.95, 0.00000001, 0.01),
        embedding_optimizer: new_adamw(0.00025, 0.9, 0.95, 0.00000001, 0.01),
        head_weight_optimizer: new_adamw(0.00025, 0.9, 0.95, 0.00000001, 0.01),
        head_bias_optimizer: new_adamw(0.00025, 0.9, 0.95, 0.00000001, 0.01),
        step: 0,
        microbatch_step: 0,
        base_lr: 0.00025,
        min_lr: 0.000025,
        warmup_steps: 100,
        cosine_decay_steps: 1000,
        grad_clip_norm: 1.0,
        last_loss: 0.0,
        last_perplexity: 0.0,
        train_tokens_seen: 0,
        valid_tokens_seen: 0,
    }
}
func two_t_runtime_state_dict(two_t_runtime_state state) two_t_runtime_state {
    two_t_runtime_state {
        model: state.model,
        plan: two_t_training_plan_state_dict(state.plan),
        process_group: process_group_state_dict(state.process_group),
        ddp: ddp_state_dict(state.ddp),
        tp: tp_state_dict(state.tp),
        pp: pipeline_parallel_state_dict(state.pp),
        backbone: transformer_state_dict(state.backbone),
        token_embedding: copy_tensor(state.token_embedding),
        lm_head_weight: copy_tensor(state.lm_head_weight),
        lm_head_bias: copy_tensor(state.lm_head_bias),
        backbone_optimizers: two_t_copy_backbone_optimizers(state.backbone_optimizers),
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: state.head_weight_optimizer,
        head_bias_optimizer: state.head_bias_optimizer,
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
    }
}
func two_t_runtime_load_state_dict(two_t_runtime_state state, two_t_runtime_state other) two_t_runtime_state {
    two_t_runtime_state {
        model: other.model,
        plan: two_t_training_plan_load_state_dict(state.plan, other.plan),
        process_group: process_group_load_state_dict(state.process_group, other.process_group),
        ddp: ddp_load_state_dict(state.ddp, other.ddp),
        tp: tp_load_state_dict(state.tp, other.tp),
        pp: pipeline_parallel_load_state_dict(state.pp, other.pp),
        backbone: transformer_load_state_dict(state.backbone, other.backbone),
        token_embedding: copy_tensor(other.token_embedding),
        lm_head_weight: copy_tensor(other.lm_head_weight),
        lm_head_bias: copy_tensor(other.lm_head_bias),
        backbone_optimizers: two_t_copy_backbone_optimizers(other.backbone_optimizers),
        embedding_optimizer: other.embedding_optimizer,
        head_weight_optimizer: other.head_weight_optimizer,
        head_bias_optimizer: other.head_bias_optimizer,
        step: other.step,
        microbatch_step: other.microbatch_step,
        base_lr: other.base_lr,
        min_lr: other.min_lr,
        warmup_steps: other.warmup_steps,
        cosine_decay_steps: other.cosine_decay_steps,
        grad_clip_norm: other.grad_clip_norm,
        last_loss: other.last_loss,
        last_perplexity: other.last_perplexity,
    }
}
func two_t_collect_tp_shard_params(two_t_runtime_state state) []tensor {
    []tensor params = []tensor{cap: 0}
    []int vocab_range = two_t_tp_vocab_range(state)
    []int col_range = two_t_tp_col_range(state)
    []int row_range = two_t_tp_row_range(state)
    params.push(tensor_2d_row_slice(state.token_embedding, vocab_range[0], vocab_range[1]))
    params.push(tensor_2d_col_slice(state.lm_head_weight, col_range[0], col_range[1]))
    params.push(tensor_from_flat_slice(state.lm_head_bias, vocab_range[0], vocab_range[1]))
    int i = 0
    while i < len(state.backbone.layers) {
        params.push(tensor_2d_col_slice(state.backbone.layers[i].w_q, col_range[0], col_range[1]))
        params.push(tensor_2d_col_slice(state.backbone.layers[i].w_k, col_range[0], col_range[1]))
        params.push(tensor_2d_col_slice(state.backbone.layers[i].w_v, col_range[0], col_range[1]))
        params.push(tensor_2d_row_slice(state.backbone.layers[i].w_o, row_range[0], row_range[1]))
        params.push(tensor_2d_col_slice(state.backbone.layers[i].w_ff1, col_range[0], col_range[1]))
        params.push(tensor_2d_row_slice(state.backbone.layers[i].w_ff2, row_range[0], row_range[1]))
        params.push(copy_tensor(state.backbone.layers[i].b_ff1))
        params.push(copy_tensor(state.backbone.layers[i].b_ff2))
        params.push(tensor_2d_col_slice(state.backbone.layers[i].w_up, col_range[0], col_range[1]))
        params.push(copy_tensor(state.backbone.layers[i].b_up))
        i = i + 1
    }
    params
}
func two_t_apply_tp_shard_params(two_t_runtime_state state, []tensor params) two_t_runtime_state {
    int idx = 0
    tensor next_token_embedding = state.token_embedding
    tensor next_lm_head_weight = state.lm_head_weight
    tensor next_lm_head_bias = state.lm_head_bias
    if idx < len(params) {
        []int vocab_range = two_t_tp_vocab_range(state)
        next_token_embedding = tensor_2d_row_update(state.token_embedding, params[idx], vocab_range[0], vocab_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        []int col_range = two_t_tp_col_range(state)
        next_lm_head_weight = tensor_2d_col_update(state.lm_head_weight, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        []int vocab_range = two_t_tp_vocab_range(state)
        next_lm_head_bias = tensor_1d_update(state.lm_head_bias, params[idx], vocab_range[0], vocab_range[1])
    }
    idx = idx + 1
    transformer next_backbone = state.backbone
    []int col_range = two_t_tp_col_range(state)
    []int row_range = two_t_tp_row_range(state)
    int layer_index = 0
    while layer_index < len(next_backbone.layers) {
        if idx < len(params) {
            next_backbone.layers[layer_index].w_q = tensor_2d_col_update(next_backbone.layers[layer_index].w_q, params[idx], col_range[0], col_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_k = tensor_2d_col_update(next_backbone.layers[layer_index].w_k, params[idx], col_range[0], col_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_v = tensor_2d_col_update(next_backbone.layers[layer_index].w_v, params[idx], col_range[0], col_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_o = tensor_2d_row_update(next_backbone.layers[layer_index].w_o, params[idx], row_range[0], row_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_ff1 = tensor_2d_col_update(next_backbone.layers[layer_index].w_ff1, params[idx], col_range[0], col_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_ff2 = tensor_2d_row_update(next_backbone.layers[layer_index].w_ff2, params[idx], row_range[0], row_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].b_ff1 = copy_tensor(params[idx])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].b_ff2 = copy_tensor(params[idx])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].w_up = tensor_2d_col_update(next_backbone.layers[layer_index].w_up, params[idx], col_range[0], col_range[1])
        }
        idx = idx + 1
        if idx < len(params) {
            next_backbone.layers[layer_index].b_up = copy_tensor(params[idx])
        }
        idx = idx + 1
        layer_index = layer_index + 1
    }
    []int vocab_range2 = two_t_tp_vocab_range(state)
    []int col_range2 = two_t_tp_col_range(state)
    tensor next_token_embedding_shard = tensor_2d_row_slice(next_token_embedding, vocab_range2[0], vocab_range2[1])
    tensor next_lm_head_weight_shard = tensor_2d_col_slice(next_lm_head_weight, col_range2[0], col_range2[1])
    tensor next_lm_head_bias_shard = tensor_from_flat_slice(next_lm_head_bias, vocab_range2[0], vocab_range2[1])
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: state.process_group,
        ddp: state.ddp,
        tp: state.tp,
        pp: state.pp,
        data: state.data,
        checkpoint: state.checkpoint,
        backbone: next_backbone,
        token_embedding: next_token_embedding,
        lm_head_weight: next_lm_head_weight,
        lm_head_bias: next_lm_head_bias,
        tp_head_weight_shard: next_lm_head_weight_shard,
        tp_head_bias_shard: next_lm_head_bias_shard,
        backbone_optimizers: state.backbone_optimizers,
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: state.head_weight_optimizer,
        head_bias_optimizer: state.head_bias_optimizer,
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        train_tokens_seen: state.train_tokens_seen,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func two_t_collect_backbone_layer_shard_params(two_t_runtime_state state, int layer_index) []tensor {
    []tensor params = []tensor{cap: 0}
    []int col_range = two_t_tp_col_range(state)
    []int row_range = two_t_tp_row_range(state)
    transformer_layer layer = transformer_layer_at(state.backbone.layers, layer_index)
    params.push(tensor_2d_col_slice(layer.w_q, col_range[0], col_range[1]))
    params.push(tensor_2d_col_slice(layer.w_k, col_range[0], col_range[1]))
    params.push(tensor_2d_col_slice(layer.w_v, col_range[0], col_range[1]))
    params.push(tensor_2d_row_slice(layer.w_o, row_range[0], row_range[1]))
    params.push(tensor_2d_col_slice(layer.w_ff1, col_range[0], col_range[1]))
    params.push(tensor_2d_row_slice(layer.w_ff2, row_range[0], row_range[1]))
    params.push(copy_tensor(layer.b_ff1))
    params.push(copy_tensor(layer.b_ff2))
    params.push(tensor_2d_col_slice(layer.w_up, col_range[0], col_range[1]))
    params.push(copy_tensor(layer.b_up))
    params
}
func two_t_apply_backbone_layer_shard_params(two_t_runtime_state state, int layer_index, []tensor params) two_t_runtime_state {
    []int col_range = two_t_tp_col_range(state)
    []int row_range = two_t_tp_row_range(state)
    transformer next_backbone = state.backbone
    transformer_layer layer = transformer_layer_at(next_backbone.layers, layer_index)
    int idx = 0
    if idx < len(params) {
        layer.w_q = tensor_2d_col_update(layer.w_q, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_k = tensor_2d_col_update(layer.w_k, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_v = tensor_2d_col_update(layer.w_v, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_o = tensor_2d_row_update(layer.w_o, params[idx], row_range[0], row_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_ff1 = tensor_2d_col_update(layer.w_ff1, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_ff2 = tensor_2d_row_update(layer.w_ff2, params[idx], row_range[0], row_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.b_ff1 = copy_tensor(params[idx])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.b_ff2 = copy_tensor(params[idx])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.w_up = tensor_2d_col_update(layer.w_up, params[idx], col_range[0], col_range[1])
    }
    idx = idx + 1
    if idx < len(params) {
        layer.b_up = copy_tensor(params[idx])
    }
    next_backbone.layers = transformer_layer_set(next_backbone.layers, layer_index, layer)
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: state.process_group,
        ddp: state.ddp,
        tp: state.tp,
        pp: state.pp,
        data: state.data,
        checkpoint: state.checkpoint,
        backbone: next_backbone,
        token_embedding: state.token_embedding,
        lm_head_weight: state.lm_head_weight,
        lm_head_bias: state.lm_head_bias,
        tp_head_weight_shard: state.tp_head_weight_shard,
        tp_head_bias_shard: state.tp_head_bias_shard,
        backbone_optimizers: state.backbone_optimizers,
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: state.head_weight_optimizer,
        head_bias_optimizer: state.head_bias_optimizer,
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        train_tokens_seen: state.train_tokens_seen,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func two_t_join_ints([]int values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(values[i])
        i = i + 1
    }
    out
}
func two_t_join_floats([]float values) string {
    string out = ""
    int i = 0
    while i < len(values) {
        if i > 0 {
            out = out + ","
        }
        out = out + string(values[i])
        i = i + 1
    }
    out
}
func two_t_parse_int_list(string text) []int {
    []int out = []int{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = neurx.strings.substring(text, i, i + 1)
        int chi = int(string(ch))
        if chi == 44 {
            if current != "" {
                out.push(int(current))
            }
            current = ""
        } else {
            current = current + ch
        }
        i = i + 1
    }
    if current != "" {
        out.push(int(current))
    }
    out
}
func two_t_parse_float_list(string text) []float {
    []float out = []float{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = neurx.strings.substring(text, i, i + 1)
        int chi = int(string(ch))
        if chi == 44 {
            if current != "" {
                out.push(float(current))
            }
            current = ""
        } else {
            current = current + ch
        }
        i = i + 1
    }
    if current != "" {
        out.push(float(current))
    }
    out
}
func two_t_split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = neurx.strings.substring(text, i, i + 1)
        int chi = int(string(ch))
        if chi == 10 {
            if current != "" {
                lines.push(current)
            }
            current = ""
        } else if chi != 13 {
            current = current + ch
        }
        i = i + 1
    }
    if current != "" {
        lines.push(current)
    }
    lines
}
func two_t_optimizer_checkpoint_path(two_t_runtime_state state) string {
    string base = two_t_tp_checkpoint_path(state)
    if base == "" {
        return ""
    }
    base + ".optim"
}
func two_t_checkpoint_rank_dir(two_t_runtime_state state) string {
    string root = state.checkpoint.path
    if root == "" {
        return ""
    }
    int tp_degree = state.plan.tensor_parallel_degree
    if tp_degree <= 0 {
        tp_degree = 1
    }
    int pp_degree = state.plan.pipeline_parallel_degree
    if pp_degree <= 0 {
        pp_degree = 1
    }
    int sp_degree = state.plan.sequence_parallel_degree
    if sp_degree <= 0 {
        sp_degree = 1
    }
    int dp_degree = state.plan.data_parallel_degree
    if dp_degree <= 0 {
        dp_degree = 1
    }
    int pp_rank = pp_stage_id(state.pp)
    int dp_rank = two_t_mod_nonneg(state.plan.rank / (tp_degree * pp_degree * sp_degree), dp_degree)
    root = root + "/tp_rank_" + string(state.tp.rank) + "_of_" + string(tp_degree)
    root = root + "/pp_rank_" + string(pp_rank) + "_of_" + string(pp_degree)
    root = root + "/dp_rank_" + string(dp_rank) + "_of_" + string(dp_degree)
    root = root + "/zero_stage_" + string(state.plan.zero_stage)
    root
}
func two_t_checkpoint_manifest_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/manifest.txt"
}
func two_t_checkpoint_meta_path(checkpoint two_t_checkpoint_runtime_state, two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/meta.txt"
}
func two_t_checkpoint_embedding_params_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/embedding.params.neurx"
}
func two_t_checkpoint_embedding_optimizer_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/embedding.optim.txt"
}
func two_t_checkpoint_head_weight_params_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/head_weight.params.neurx"
}
func two_t_checkpoint_head_weight_optimizer_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/head_weight.optim.txt"
}
func two_t_checkpoint_head_bias_params_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/head_bias.params.neurx"
}
func two_t_checkpoint_head_bias_optimizer_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/head_bias.optim.txt"
}
func two_t_checkpoint_payload_paths(two_t_runtime_state state) []string {
    []string paths = []string{cap: 0}
    paths.push(two_t_checkpoint_embedding_params_path(state))
    paths.push(two_t_checkpoint_embedding_optimizer_path(state))
    paths.push(two_t_checkpoint_head_weight_params_path(state))
    paths.push(two_t_checkpoint_head_weight_optimizer_path(state))
    paths.push(two_t_checkpoint_head_bias_params_path(state))
    paths.push(two_t_checkpoint_head_bias_optimizer_path(state))
    int layer_index = 0
    while layer_index < len(state.backbone.layers) {
        paths.push(two_t_checkpoint_backbone_layer_params_path(state, layer_index))
        paths.push(two_t_checkpoint_backbone_layer_optimizer_path(state, layer_index))
        layer_index = layer_index + 1
    }
    paths
}
func two_t_checkpoint_missing_paths(two_t_runtime_state state) []string {
    []string missing = []string{cap: 0}
    []string paths = two_t_checkpoint_payload_paths(state)
    int i = 0
    while i < len(paths) {
        string path = paths[i]
        if path != ""  !runtime_file_exists(path) {
            missing.push(path)
        }
        i = i + 1
    }
    missing
}
func two_t_checkpoint_resume_ready(two_t_runtime_state state) bool {
    if state.checkpoint.path == "" {
        return false
    }
    string manifest = two_t_checkpoint_manifest_path(state)
    if manifest == "" || !runtime_file_exists(manifest) {
        return false
    }
    []string missing = two_t_checkpoint_missing_paths(state)
    len(missing) == 0
}
func two_t_checkpoint_manifest_text(two_t_runtime_state state) string {
    string out = "two_t_checkpoint_manifest_v1\n"
    out = out + "rank_dir=" + two_t_checkpoint_rank_dir(state) + "\n"
    out = out + "tp_rank=" + string(state.tp.rank) + "\n"
    out = out + "pp_stage=" + string(pp_stage_id(state.pp)) + "\n"
    out = out + "dp_rank=" + string(two_t_mod_nonneg(state.plan.rank / (state.plan.tensor_parallel_degree * state.plan.pipeline_parallel_degree * state.plan.sequence_parallel_degree), state.plan.data_parallel_degree)) + "\n"
    out = out + "zero_stage=" + string(state.plan.zero_stage) + "\n"
    out = out + "layer_count=" + string(len(state.backbone.layers)) + "\n"
    out = out + "payload_count=" + string(len(two_t_checkpoint_payload_paths(state))) + "\n"
    []string paths = two_t_checkpoint_payload_paths(state)
    int i = 0
    while i < len(paths) {
        out = out + "file=" + paths[i] + "\n"
        i = i + 1
    }
    out
}
func two_t_checkpoint_resume_status_path(two_t_runtime_state state) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/resume_status.txt"
}
func two_t_checkpoint_resume_status_text(two_t_runtime_state state) string {
    if state.checkpoint.path == "" {
        return "disabled\n"
    }
    string manifest = two_t_checkpoint_manifest_path(state)
    if manifest == "" || !runtime_file_exists(manifest) {
        return "missing_manifest\n"
    }
    []string missing = two_t_checkpoint_missing_paths(state)
    if len(missing) == 0 {
        return "ok\n"
    }
    string out = "missing_shards\n"
    int i = 0
    while i < len(missing) {
        out = out + missing[i] + "\n"
        i = i + 1
    }
    out
}
func two_t_checkpoint_backbone_layer_dir(two_t_runtime_state state, int layer_index) string {
    string root = two_t_checkpoint_rank_dir(state)
    if root == "" {
        return ""
    }
    root + "/backbone/layer_" + string(layer_index)
}
func two_t_checkpoint_backbone_layer_params_path(two_t_runtime_state state, int layer_index) string {
    string root = two_t_checkpoint_backbone_layer_dir(state, layer_index)
    if root == "" {
        return ""
    }
    root + "/params.neurx"
}
func two_t_checkpoint_backbone_layer_optimizer_path(two_t_runtime_state state, int layer_index) string {
    string root = two_t_checkpoint_backbone_layer_dir(state, layer_index)
    if root == "" {
        return ""
    }
    root + "/optim.txt"
}
func two_t_adamw_optimizer_text(string prefix, adamw_optimizer optimizer) string {
    string out = ""
    out = out + prefix + "lr=" + string(optimizer.lr) + "\n"
    out = out + prefix + "beta1=" + string(optimizer.beta1) + "\n"
    out = out + prefix + "beta2=" + string(optimizer.beta2) + "\n"
    out = out + prefix + "eps=" + string(optimizer.eps) + "\n"
    out = out + prefix + "weight_decay=" + string(optimizer.weight_decay) + "\n"
    out = out + prefix + "step=" + string(optimizer.step) + "\n"
    out = out + prefix + "beta1_pow=" + string(optimizer.beta1_pow) + "\n"
    out = out + prefix + "beta2_pow=" + string(optimizer.beta2_pow) + "\n"
    out = out + prefix + "m=" + two_t_join_floats(optimizer.m) + "\n"
    out = out + prefix + "v=" + two_t_join_floats(optimizer.v) + "\n"
    out
}
func two_t_adamw_optimizer_from_text([]string lines, string prefix, adamw_optimizer fallback) adamw_optimizer {
    string lr_text = two_t_line_value(lines, prefix + "lr=", string(fallback.lr))
    string beta1_text = two_t_line_value(lines, prefix + "beta1=", string(fallback.beta1))
    string beta2_text = two_t_line_value(lines, prefix + "beta2=", string(fallback.beta2))
    string eps_text = two_t_line_value(lines, prefix + "eps=", string(fallback.eps))
    string decay_text = two_t_line_value(lines, prefix + "weight_decay=", string(fallback.weight_decay))
    string step_text = two_t_line_value(lines, prefix + "step=", string(fallback.step))
    string beta1_pow_text = two_t_line_value(lines, prefix + "beta1_pow=", string(fallback.beta1_pow))
    string beta2_pow_text = two_t_line_value(lines, prefix + "beta2_pow=", string(fallback.beta2_pow))
    string m_text = two_t_line_value(lines, prefix + "m=", two_t_join_floats(fallback.m))
    string v_text = two_t_line_value(lines, prefix + "v=", two_t_join_floats(fallback.v))
    adamw_optimizer {
        float lr(lr_text),
        float beta1(beta1_text),
        float beta2(beta2_text),
        float eps(eps_text),
        float weight_decay(decay_text),
        int step(step_text),
        float beta1_pow(beta1_pow_text),
        float beta2_pow(beta2_pow_text),
        m: two_t_parse_float_list(m_text),
        v: two_t_parse_float_list(v_text),
    }
}
func two_t_runtime_restore_optimizer_state(two_t_runtime_state state, string content) two_t_runtime_state {
    []string lines = two_t_split_lines(content)
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: state.process_group,
        ddp: state.ddp,
        tp: state.tp,
        pp: state.pp,
        data: state.data,
        checkpoint: state.checkpoint,
        backbone: state.backbone,
        token_embedding: state.token_embedding,
        lm_head_weight: state.lm_head_weight,
        lm_head_bias: state.lm_head_bias,
        tp_head_weight_shard: state.tp_head_weight_shard,
        tp_head_bias_shard: state.tp_head_bias_shard,
        backbone_optimizers: two_t_backbone_optimizer_from_text(lines, state.backbone_optimizers),
        embedding_optimizer: two_t_adamw_optimizer_from_text(lines, "embedding.", state.embedding_optimizer),
        head_weight_optimizer: two_t_adamw_optimizer_from_text(lines, "head_weight.", state.head_weight_optimizer),
        head_bias_optimizer: two_t_adamw_optimizer_from_text(lines, "head_bias.", state.head_bias_optimizer),
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        train_tokens_seen: state.train_tokens_seen,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func two_t_tp_checkpoint_path(two_t_runtime_state state) string {
    string base = state.checkpoint.path
    if base == "" {
        return ""
    }
    base = base + ".tp_rank_" + string(state.tp.rank)
    if state.plan.tensor_parallel_degree > 1 {
        base = base + "_of_" + string(state.plan.tensor_parallel_degree)
    }
    base + ".neurx"
}
func two_t_checkpoint_meta_text(two_t_runtime_state state) string {
    string out = "two_t_checkpoint_v1\n"
    out = out + "step=" + string(state.step) + "\n"
    out = out + "microbatch_step=" + string(state.microbatch_step) + "\n"
    out = out + "loss=" + string(state.last_loss) + "\n"
    out = out + "perplexity=" + string(state.last_perplexity) + "\n"
    out = out + "train_tokens_seen=" + string(state.train_tokens_seen) + "\n"
    out = out + "valid_tokens_seen=" + string(state.valid_tokens_seen) + "\n"
    out = out + "rng_seed=" + string(state.checkpoint.rng_seed) + "\n"
    out = out + "train_loader_cursor=" + string(state.data.train_loader.cursor) + "\n"
    out = out + "train_loader_epoch=" + string(state.data.train_loader.epoch) + "\n"
    out = out + "train_loader_shuffle_seed=" + string(state.data.train_loader.shuffle_seed) + "\n"
    out = out + "train_loader_batch_size=" + string(state.data.train_loader.config.batch_size) + "\n"
    out = out + "train_loader_seq_len=" + string(state.data.train_loader.config.seq_len) + "\n"
    out = out + "valid_loader_cursor=" + string(state.data.valid_loader.cursor) + "\n"
    out = out + "valid_loader_epoch=" + string(state.data.valid_loader.epoch) + "\n"
    out = out + "valid_loader_shuffle_seed=" + string(state.data.valid_loader.shuffle_seed) + "\n"
    out = out + "valid_loader_batch_size=" + string(state.data.valid_loader.config.batch_size) + "\n"
    out = out + "valid_loader_seq_len=" + string(state.data.valid_loader.config.seq_len) + "\n"
    out = out + "train_token_ids=" + two_t_join_ints(state.data.train_loader.token_ids) + "\n"
    out = out + "valid_token_ids=" + two_t_join_ints(state.data.valid_loader.token_ids) + "\n"
    out = out + "backbone_lr=" + string(state.base_lr) + "\n"
    out = out + "min_lr=" + string(state.min_lr) + "\n"
    out = out + "warmup_steps=" + string(state.warmup_steps) + "\n"
    out = out + "cosine_decay_steps=" + string(state.cosine_decay_steps) + "\n"
    out = out + "grad_clip_norm=" + string(state.grad_clip_norm) + "\n"
    out
}
func two_t_write_checkpoint(two_t_runtime_state state) two_t_runtime_state {
    if !state.checkpoint.enabled {
        return state
    }
    string rank_dir = two_t_checkpoint_rank_dir(state)
    if rank_dir != "" {
        runtime_make_dirs(rank_dir)
    }
    save_checkpoint(two_t_checkpoint_embedding_params_path(state), state.step, state.last_loss, two_t_single_tensor_params(state.token_embedding))
    runtime_write_text_file(two_t_checkpoint_embedding_optimizer_path(state), two_t_adamw_optimizer_text("embedding.", state.embedding_optimizer))
    save_checkpoint(two_t_checkpoint_head_weight_params_path(state), state.step, state.last_loss, two_t_single_tensor_params(state.lm_head_weight))
    runtime_write_text_file(two_t_checkpoint_head_weight_optimizer_path(state), two_t_adamw_optimizer_text("head_weight.", state.head_weight_optimizer))
    save_checkpoint(two_t_checkpoint_head_bias_params_path(state), state.step, state.last_loss, two_t_single_tensor_params(state.lm_head_bias))
    runtime_write_text_file(two_t_checkpoint_head_bias_optimizer_path(state), two_t_adamw_optimizer_text("head_bias.", state.head_bias_optimizer))
    int layer_index = 0
    while layer_index < len(state.backbone.layers) {
        string layer_dir = two_t_checkpoint_backbone_layer_dir(state, layer_index)
        if layer_dir != "" {
            runtime_make_dirs(layer_dir)
        }
        save_checkpoint(two_t_checkpoint_backbone_layer_params_path(state, layer_index), state.step, state.last_loss, two_t_collect_backbone_layer_shard_params(state, layer_index))
        runtime_write_text_file(two_t_checkpoint_backbone_layer_optimizer_path(state, layer_index), two_t_layer_optimizer_text("layer.", layer_optimizer_state_at(state.backbone_optimizers, layer_index)))
        layer_index = layer_index + 1
    }
    string meta_path = two_t_checkpoint_meta_path(two_t_checkpoint_runtime_state {
        path: state.checkpoint.path,
        enabled: state.checkpoint.enabled,
        save_every_steps: state.checkpoint.save_every_steps,
        last_saved_step: state.checkpoint.last_saved_step,
        rng_seed: state.checkpoint.rng_seed,
    }, state)
    if meta_path != "" {
        runtime_write_text_file(meta_path, two_t_checkpoint_meta_text(state))
    }
    string manifest_path = two_t_checkpoint_manifest_path(state)
    if manifest_path != "" {
        runtime_write_text_file(manifest_path, two_t_checkpoint_manifest_text(state))
    }
    string resume_status_path = two_t_checkpoint_resume_status_path(state)
    if resume_status_path != "" {
        runtime_write_text_file(resume_status_path, two_t_checkpoint_resume_status_text(state))
    }
    two_t_runtime_state {
        model: state.model,
        plan: state.plan,
        process_group: state.process_group,
        ddp: state.ddp,
        tp: state.tp,
        pp: state.pp,
        data: state.data,
        checkpoint: two_t_checkpoint_runtime_state {
            path: state.checkpoint.path,
            enabled: state.checkpoint.enabled,
            save_every_steps: state.checkpoint.save_every_steps,
            last_saved_step: state.step,
            rng_seed: state.checkpoint.rng_seed,
        },
        backbone: state.backbone,
        token_embedding: state.token_embedding,
        lm_head_weight: state.lm_head_weight,
        lm_head_bias: state.lm_head_bias,
        tp_head_weight_shard: state.tp_head_weight_shard,
        tp_head_bias_shard: state.tp_head_bias_shard,
        backbone_optimizers: state.backbone_optimizers,
        embedding_optimizer: state.embedding_optimizer,
        head_weight_optimizer: state.head_weight_optimizer,
        head_bias_optimizer: state.head_bias_optimizer,
        step: state.step,
        microbatch_step: state.microbatch_step,
        base_lr: state.base_lr,
        min_lr: state.min_lr,
        warmup_steps: state.warmup_steps,
        cosine_decay_steps: state.cosine_decay_steps,
        grad_clip_norm: state.grad_clip_norm,
        last_loss: state.last_loss,
        last_perplexity: state.last_perplexity,
        train_tokens_seen: state.train_tokens_seen,
        valid_tokens_seen: state.valid_tokens_seen,
    }
}
func two_t_restore_optimizer_from_meta(two_t_runtime_state state, []string lines) two_t_runtime_state {
    state
}
func two_t_line_value([]string lines, string key, string fallback) string {
    int i = 0
    while i < len(lines) {
        string line = lines[i]
        int key_len = len(key)
        if len(line) >= key_len {
            string head = line
            if key_len < len(line) {
                head = copy_string_prefix(line, key_len)
            }
            if head == key {
                return copy_string_suffix(line, key_len)
            }
        }
        i = i + 1
    }
    fallback
}
func copy_string_prefix(string value, int length) string {
    if length <= 0 {
        return ""
    }
    if length > len(value) {
        length = len(value)
    }
    neurx.strings.substring(value, 0, length)
}
func copy_string_suffix(string value, int start) string {
    if start < 0 {
        start = 0
    }
    if start > len(value) {
        start = len(value)
    }
    neurx.strings.substring(value, start, len(value))
}
func two_t_runtime_load_checkpoint(two_t_runtime_state state) two_t_runtime_state {
    if !state.checkpoint.enabled {
        return state
    }
    string resume_status_path = two_t_checkpoint_resume_status_path(state)
    string resume_status = two_t_checkpoint_resume_status_text(state)
    if resume_status != "ok\n" {
        string resume_dir = two_t_checkpoint_rank_dir(state)
        if resume_dir != "" {
            runtime_make_dirs(resume_dir)
        }
        if resume_status_path != "" {
            runtime_write_text_file(resume_status_path, resume_status)
        }
        return state
    }
    checkpoint embedding_saved = load_checkpoint(two_t_checkpoint_embedding_params_path(state))
    checkpoint head_weight_saved = load_checkpoint(two_t_checkpoint_head_weight_params_path(state))
    checkpoint head_bias_saved = load_checkpoint(two_t_checkpoint_head_bias_params_path(state))
    two_t_runtime_state params_state = state
    if len(checkpoint_params(embedding_saved)) > 0 {
        params_state.token_embedding = two_t_first_checkpoint_tensor(embedding_saved)
    }
    if len(checkpoint_params(head_weight_saved)) > 0 {
        params_state.lm_head_weight = two_t_first_checkpoint_tensor(head_weight_saved)
    }
    if len(checkpoint_params(head_bias_saved)) > 0 {
        params_state.lm_head_bias = two_t_first_checkpoint_tensor(head_bias_saved)
    }
    int layer_index = 0
    while layer_index < len(params_state.backbone.layers) {
        string layer_path = two_t_checkpoint_backbone_layer_params_path(state, layer_index)
        checkpoint layer_saved = load_checkpoint(layer_path)
        if len(checkpoint_params(layer_saved)) > 0 {
            params_state = two_t_apply_backbone_layer_shard_params(params_state, layer_index, checkpoint_params(layer_saved))
        }
        layer_index = layer_index + 1
    }
    string meta_path = two_t_checkpoint_meta_path(two_t_checkpoint_runtime_state {
        path: state.checkpoint.path,
        enabled: state.checkpoint.enabled,
        save_every_steps: state.checkpoint.save_every_steps,
        last_saved_step: state.checkpoint.last_saved_step,
        rng_seed: state.checkpoint.rng_seed,
    }, state)
    []string meta_lines = []string{cap: 0}
    if meta_path != ""  runtime_file_exists(meta_path) {
        meta_lines = two_t_split_lines(runtime_read_text_file(meta_path))
    }
    if runtime_file_exists(two_t_checkpoint_embedding_optimizer_path(state)) {
        params_state.embedding_optimizer = two_t_adamw_optimizer_from_text(two_t_split_lines(runtime_read_text_file(two_t_checkpoint_embedding_optimizer_path(state))), "embedding.", params_state.embedding_optimizer)
    }
    if runtime_file_exists(two_t_checkpoint_head_weight_optimizer_path(state)) {
        params_state.head_weight_optimizer = two_t_adamw_optimizer_from_text(two_t_split_lines(runtime_read_text_file(two_t_checkpoint_head_weight_optimizer_path(state))), "head_weight.", params_state.head_weight_optimizer)
    }
    if runtime_file_exists(two_t_checkpoint_head_bias_optimizer_path(state)) {
        params_state.head_bias_optimizer = two_t_adamw_optimizer_from_text(two_t_split_lines(runtime_read_text_file(two_t_checkpoint_head_bias_optimizer_path(state))), "head_bias.", params_state.head_bias_optimizer)
    }
    layer_index = 0
    while layer_index < len(params_state.backbone_optimizers) {
        string layer_optim_path = two_t_checkpoint_backbone_layer_optimizer_path(state, layer_index)
        if runtime_file_exists(layer_optim_path) {
            params_state.backbone_optimizers[layer_index] = two_t_layer_optimizer_from_text(two_t_split_lines(runtime_read_text_file(layer_optim_path)), "layer.", layer_optimizer_state_at(params_state.backbone_optimizers, layer_index))
        }
        layer_index = layer_index + 1
    }
    int loaded_step = checkpoint_step(embedding_saved)
    float loaded_loss = checkpoint_loss(embedding_saved)
    int loaded_microbatch = params_state.microbatch_step
    int loaded_train_seen = params_state.train_tokens_seen
    int loaded_valid_seen = params_state.valid_tokens_seen
    if len(meta_lines) > 0 {
        string step_text = two_t_line_value(meta_lines, "step=", string(loaded_step))
        loaded_step = int(step_text)
        string micro_text = two_t_line_value(meta_lines, "microbatch_step=", string(loaded_microbatch))
        loaded_microbatch = int(micro_text)
        string loss_text = two_t_line_value(meta_lines, "loss=", string(loaded_loss))
        loaded_loss = float(loss_text)
        string train_seen_text = two_t_line_value(meta_lines, "train_tokens_seen=", string(loaded_train_seen))
        loaded_train_seen = int(train_seen_text)
        string valid_seen_text = two_t_line_value(meta_lines, "valid_tokens_seen=", string(loaded_valid_seen))
        loaded_valid_seen = int(valid_seen_text)
        string rng_text = two_t_line_value(meta_lines, "rng_seed=", string(params_state.checkpoint.rng_seed))
        params_state.checkpoint.rng_seed = int(rng_text)
        string train_cursor = two_t_line_value(meta_lines, "train_loader_cursor=", string(params_state.data.train_loader.cursor))
        params_state.data.train_loader.cursor = int(train_cursor)
        string train_epoch = two_t_line_value(meta_lines, "train_loader_epoch=", string(params_state.data.train_loader.epoch))
        params_state.data.train_loader.epoch = int(train_epoch)
        string train_seed = two_t_line_value(meta_lines, "train_loader_shuffle_seed=", string(params_state.data.train_loader.shuffle_seed))
        params_state.data.train_loader.shuffle_seed = int(train_seed)
        string valid_cursor = two_t_line_value(meta_lines, "valid_loader_cursor=", string(params_state.data.valid_loader.cursor))
        params_state.data.valid_loader.cursor = int(valid_cursor)
        string valid_epoch = two_t_line_value(meta_lines, "valid_loader_epoch=", string(params_state.data.valid_loader.epoch))
        params_state.data.valid_loader.epoch = int(valid_epoch)
        string valid_seed = two_t_line_value(meta_lines, "valid_loader_shuffle_seed=", string(params_state.data.valid_loader.shuffle_seed))
        params_state.data.valid_loader.shuffle_seed = int(valid_seed)
        string train_tokens = two_t_line_value(meta_lines, "train_token_ids=", "")
        if train_tokens != "" {
            params_state.data.train_loader.token_ids = two_t_parse_int_list(train_tokens)
        }
        string valid_tokens = two_t_line_value(meta_lines, "valid_token_ids=", "")
        if valid_tokens != "" {
            params_state.data.valid_loader.token_ids = two_t_parse_int_list(valid_tokens)
        }
    }
    two_t_runtime_state {
        model: params_state.model,
        plan: params_state.plan,
        process_group: params_state.process_group,
        ddp: params_state.ddp,
        tp: params_state.tp,
        pp: params_state.pp,
        data: params_state.data,
        checkpoint: params_state.checkpoint,
        backbone: params_state.backbone,
        token_embedding: params_state.token_embedding,
        lm_head_weight: params_state.lm_head_weight,
        lm_head_bias: params_state.lm_head_bias,
        tp_head_weight_shard: tensor_2d_col_slice(params_state.lm_head_weight, two_t_tp_col_range(params_state)[0], two_t_tp_col_range(params_state)[1]),
        tp_head_bias_shard: tensor_from_flat_slice(params_state.lm_head_bias, two_t_tp_vocab_range(params_state)[0], two_t_tp_vocab_range(params_state)[1]),
        backbone_optimizers: params_state.backbone_optimizers,
        embedding_optimizer: params_state.embedding_optimizer,
        head_weight_optimizer: params_state.head_weight_optimizer,
        head_bias_optimizer: params_state.head_bias_optimizer,
        step: loaded_step,
        microbatch_step: loaded_microbatch,
        base_lr: params_state.base_lr,
        min_lr: params_state.min_lr,
        warmup_steps: params_state.warmup_steps,
        cosine_decay_steps: params_state.cosine_decay_steps,
        grad_clip_norm: params_state.grad_clip_norm,
        last_loss: loaded_loss,
        last_perplexity: exp_approx(loaded_loss),
        train_tokens_seen: loaded_train_seen,
        valid_tokens_seen: loaded_valid_seen,
    }
}
func two_t_runtime_step(two_t_runtime_state state) two_t_runtime_state {
    dataloader_state loader = state.data.train_loader
    if !has_next(loader) {
        loader = reset_state(loader)
    }
    dataloader_step_output loaded_batch = next_batch(loader)
    two_t_training_batch batch = two_t_loader_batch_to_tensor(loaded_batch)
    two_t_runtime_state next_state = two_t_runtime_backward(
        two_t_runtime_state {
            model: state.model,
            plan: state.plan,
            process_group: state.process_group,
            ddp: state.ddp,
            tp: state.tp,
            pp: state.pp,
            data: two_t_data_state {
                corpus: state.data.corpus,
                train_loader: loaded_batch.state,
                valid_loader: state.data.valid_loader,
                train_path: state.data.train_path,
                train_tokens: state.data.train_tokens,
                valid_tokens: state.data.valid_tokens,
            },
            checkpoint: state.checkpoint,
            backbone: state.backbone,
            token_embedding: state.token_embedding,
            lm_head_weight: state.lm_head_weight,
            lm_head_bias: state.lm_head_bias,
            tp_head_weight_shard: state.tp_head_weight_shard,
            tp_head_bias_shard: state.tp_head_bias_shard,
            backbone_optimizers: state.backbone_optimizers,
            embedding_optimizer: state.embedding_optimizer,
            head_weight_optimizer: state.head_weight_optimizer,
            head_bias_optimizer: state.head_bias_optimizer,
            step: state.step,
            microbatch_step: state.microbatch_step,
            base_lr: state.base_lr,
            min_lr: state.min_lr,
            warmup_steps: state.warmup_steps,
            cosine_decay_steps: state.cosine_decay_steps,
            grad_clip_norm: state.grad_clip_norm,
            last_loss: state.last_loss,
            last_perplexity: state.last_perplexity,
            train_tokens_seen: state.train_tokens_seen,
            valid_tokens_seen: state.valid_tokens_seen,
        },
        batch,
        two_t_runtime_forward(state, batch)
    )
    if next_state.checkpoint.enabled  next_state.step - next_state.checkpoint.last_saved_step >= next_state.checkpoint.save_every_steps {
        next_state = two_t_write_checkpoint(next_state)
    }
    next_state
}
func two_t_runtime_train(two_t_runtime_state state, int steps) two_t_runtime_state {
    int loops = steps
    if loops < 0 {
        loops = 0
    }
    two_t_runtime_state current = state
    int i = 0
    while i < loops {
        current = two_t_runtime_step(current)
        current.plan = two_t_training_plan_step(current.plan)
        i = i + 1
    }
    current
}
func two_t_runtime_summary(two_t_runtime_state state) string {
    string out = "two_t_runtime_state("
    out = out + "step=" + string(state.step)
    out = out + ", microbatch_step=" + string(state.microbatch_step)
    out = out + ", loss=" + string(state.last_loss)
    out = out + ", perplexity=" + string(state.last_perplexity)
    out = out + ", plan=" + two_t_training_plan_summary(state.plan)
    out = out + ", pp_depth=" + string(pp_pipeline_depth(state.pp))
    out = out + ", pp_stage_id=" + string(pp_stage_id(state.pp))
    out = out + ", pp_microbatch_id=" + string(pp_microbatch_id(state.pp))
    out = out + ", pp_step=" + string(pp_step(state.pp))
    out = out + ", pp_total_slots=" + string(pp_total_slots(state.pp))
    out = out + ", ddp_distributed=" + string(ddp_is_distributed(state.ddp))
    out = out + ")"
    out
}
func two_t_runtime_report(two_t_runtime_state state) string {
    string out = "two_t_runtime_report("
    out = out + "params=" + string(calculate_2t_model_parameters(state.model))
    out = out + ", lr=" + string(two_t_effective_lr(state))
    out = out + ", summary=" + two_t_runtime_summary(state)
    out = out + ")"
    out
}
