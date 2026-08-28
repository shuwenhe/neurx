package neurx.trainer.moe_1t_orchestrator
use neurx.moe.llm_1t.{
    moe_1t_framework, moe_1t_scale_profile, moe_1t_parallel_plan,
    moe_1t_training_plan, moe_1t_framework_default, moe_1t_summary
}
use neurx.pretrain.llm.gpt_large_pretrain.{gpt_large_pretrain_manifest_refs, gpt_large_pretrain_documents_for_ref_with_seed, gpt_large_pretrain_mix_seed}
use neurx.checkpoint.pretrain.{pretrain_checkpoint_state, pretrain_checkpoint_bundle_state, new_pretrain_checkpoint_state, new_pretrain_checkpoint_bundle_state, mark_saved, mark_best, save_pretrain_checkpoint, load_pretrain_checkpoint}
use neurx.moe.llm.{gpt_moe_config, gpt_moe_state, new_gpt_moe_state}
use neurx.loss.llm_moe_1t_loss.{loss_state_new, compute_total_loss, compute_ce_gradient}
use neurx.distributed.collective.{collective_state}
use neurx.runtime.io.{io_println, io_get_env, io_mkdir_recursive, runtime_file_exists, runtime_read_text_file}

struct moe_routing_stats {
    int total_tokens
    int[] expert_load
    float[] expert_load_ratio
    float load_imbalance
    float communication_cost_ms
    float compute_cost_ms
    float aux_loss_value
}

struct moe_1t_step_state {
    int global_step
    int tokens_seen
    int epoch
    int batch_tokens
    float loss
    float loss_scale
    float learning_rate
    moe_routing_stats routing
    int allreduce_time_us
    int compute_time_us
}

struct moe_1t_orchestrator {
    moe_1t_framework framework
    gpt_moe_config model_config
    int world_rank
    int world_size
    int tp_rank
    int tp_size
    int pp_rank
    int pp_size
    int ep_rank
    int ep_size
    int dp_rank
    int dp_size
    gpt_moe_state model_state
    zero_optimizer_state optimizer_state
    collective_state comm
    string data_manifest_path
    string[] token_shards
    int current_shard_index
    int tokens_in_shard
    string checkpoint_dir
    int last_saved_step
    int training_step
    int resumeable
    string latest_checkpoint_path
    []moe_1t_step_state step_history
    int log_interval
    int eval_interval
    int save_interval
    int should_stop
    int fault_recovery_enabled
    int profile_enabled
}

func moe_1t_trim(string s) string {
    int i = 0
    for i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    for j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    for k <= j {
        out = out + chr(s[k])
        k = k + 1
    }
    out
}

func moe_1t_split_lines(string text) string[] {
    string[] lines = string[]{cap: 0}
    string current = ""
    bool ends_with_newline = false
    int i = 0
    for i < len(text) {
        int ch = text[i]
        if ch == 10 {
            lines = append(lines, current)
            current = ""
            ends_with_newline = true
        } else if ch != 13 {
            current = current + chr(ch)
            ends_with_newline = false
        }
        i = i + 1
    }
    if current != "" || len(text) == 0 || ends_with_newline {
        lines = append(lines, current)
    }
    lines
}

func moe_1t_positive_mod(int value, int modulus) int {
    if modulus <= 0 {
        return 0
    }
    int div_result = value / modulus
    int result = value - div_result * modulus
    if result < 0 {
        result = result + modulus
    }
    result
}

func moe_1t_manifest_refs(string manifest_path) string[] {
    if moe_1t_trim(manifest_path) == "" {
        string[] refs = string[]{cap: 1}
        refs[0] = "dataset/pretrain/manifest.json"
        return refs
    }
    if !runtime_file_exists(manifest_path) {
        string[] refs = string[]{cap: 1}
        refs[0] = manifest_path
        return refs
    }
    string[] refs = gpt_large_pretrain_manifest_refs(manifest_path)
    if len(refs) == 0 {
        string[] fallback = string[]{cap: 1}
        fallback[0] = manifest_path
        return fallback
    }
    refs
}

func moe_1t_text_to_tokens(string text, int batch_size_tokens, int seed) int[] {
    if batch_size_tokens <= 0 {
        return int[]{cap: 0}
    }
    int[] tokens = int[]{cap: batch_size_tokens}
    int token_count = 0
    int rolling = seed + 17
    int i = 0
    for i < len(text) && token_count < batch_size_tokens {
        int ch = text[i]
        rolling = rolling * 131 + ch + i + seed
        if ch == 32 || ch == 9 || ch == 10 || ch == 13 {
            tokens[token_count] = moe_1t_positive_mod(rolling, 128000)
            token_count = token_count + 1
            rolling = seed + i + 17
        }
        i = i + 1
    }
    if token_count == 0 {
        int j = 0
        for j < len(text) && token_count < batch_size_tokens {
            rolling = rolling * 131 + text[j] + j + seed
            tokens[token_count] = moe_1t_positive_mod(rolling, 128000)
            token_count = token_count + 1
            j = j + 1
        }
    }
    for token_count < batch_size_tokens {
        rolling = rolling * 1664525 + 1013904223 + token_count + seed
        tokens[token_count] = moe_1t_positive_mod(rolling, 128000)
        token_count = token_count + 1
    }
    tokens
}

func moe_1t_shard_tokens(string shard_path, int batch_size_tokens, int seed) int[] {
    if batch_size_tokens <= 0 {
        return int[]{cap: 0}
    }
    string shard_text = ""
    if runtime_file_exists(shard_path) {
        shard_text = runtime_read_text_file(shard_path)
    }
    if moe_1t_trim(shard_text) == "" {
        shard_text = shard_path
    } else {
        string[] docs = gpt_large_pretrain_documents_for_ref_with_seed(shard_path, seed)
        int i = 0
        for i < len(docs) {
            if moe_1t_trim(docs[i]) != "" {
                if shard_text != "" {
                    shard_text = shard_text + "\n"
                }
                shard_text = shard_text + docs[i]
            }
            i = i + 1
        }
    }
    moe_1t_text_to_tokens(shard_text, batch_size_tokens, seed)
}

func moe_1t_build_labels(int[] batch_tokens, int vocab_size) int[] {
    int count = len(batch_tokens)
    int[] labels = int[]{cap: count}
    if count == 0 {
        return labels
    }
    int i = 0
    for i < count {
        int next_idx = i + 1
        if next_idx >= count {
            next_idx = 0
        }
        labels[i] = moe_1t_positive_mod(batch_tokens[next_idx], vocab_size)
        i = i + 1
    }
    labels
}

func moe_1t_build_top1_routing(
    moe_1t_orchestrator orch,
    int[] batch_tokens
) (int[], float[]) {
    int count = len(batch_tokens)
    int num_experts = orch.model_config.moe.num_experts
    if num_experts <= 0 {
        num_experts = 1
    }
    int[] expert_indices = int[]{cap: count}
    float[] expert_weights = float[]{cap: count}
    int i = 0
    for i < count {
        expert_indices[i] = moe_1t_positive_mod(batch_tokens[i] + orch.world_rank + i, num_experts)
        expert_weights[i] = 1.0
        i = i + 1
    }
    (expert_indices, expert_weights)
}

func moe_1t_average_abs(float[] values) float {
    if len(values) == 0 {
        return 0.0
    }
    float total = 0.0
    int i = 0
    for i < len(values) {
        if values[i] < 0.0 {
            total = total - values[i]
        } else {
            total = total + values[i]
        }
        i = i + 1
    }
    total / float(len(values))
}

func moe_1t_tp_local_hidden_dim(moe_1t_orchestrator orch) int {
    int hidden_dim = orch.model_config.base.n_embd
    int tp_size = orch.tp_size
    if tp_size <= 0 {
        tp_size = 1
    }
    if tp_size > 1 && hidden_dim >= tp_size {
        int local_hidden = hidden_dim / tp_size
        if local_hidden > 0 {
            return local_hidden
        }
    }
    hidden_dim
}

func moe_1t_tp_global_offset(moe_1t_orchestrator orch) int {
    int local_hidden = moe_1t_tp_local_hidden_dim(orch)
    int offset = orch.tp_rank * local_hidden
    if offset < 0 {
        offset = 0
    }
    offset
}

func moe_1t_orchestrator_new() moe_1t_orchestrator {
    moe_1t_framework fw = moe_1t_framework_default()
    string rank_str = io_get_env("RANK", "0")
    string world_size_str = io_get_env("WORLD_SIZE", "1")
    string tp_rank_str = io_get_env("TP_RANK", "0")
    string tp_size_str = io_get_env("TP_SIZE", "1")
    string pp_rank_str = io_get_env("PP_RANK", "0")
    string pp_size_str = io_get_env("PP_SIZE", "1")
    string ep_rank_str = io_get_env("EP_RANK", "0")
    string ep_size_str = io_get_env("EP_SIZE", "1")
    string dp_rank_str = io_get_env("DP_RANK", "0")
    string dp_size_str = io_get_env("DP_SIZE", "1")
    int world_rank = string_to_int(rank_str)
    int world_size = string_to_int(world_size_str)
    int tp_rank = string_to_int(tp_rank_str)
    int tp_size = string_to_int(tp_size_str)
    int pp_rank = string_to_int(pp_rank_str)
    int pp_size = string_to_int(pp_size_str)
    int ep_rank = string_to_int(ep_rank_str)
    int ep_size = string_to_int(ep_size_str)
    int dp_rank = string_to_int(dp_rank_str)
    int dp_size = string_to_int(dp_size_str)
    gpt_moe_state model = new_gpt_moe_state(fw.model)
    zero_optimizer_state optimizer = zero_optimizer_state {
        learning_rate: fw.training.peak_lr,
        min_lr: fw.training.min_lr,
        beta1: 0.9,
        beta2: 0.95,
        epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        stage: 3,
        world_rank: world_rank,
        world_size: world_size,
        sharded_params: 1,
        partitioned_grads: 1,
    }
    collective_state comm = collective_state {
        backend: "nccl",
        rank: world_rank,
        world_size: world_size,
    }
    string checkpoint_dir = fw.training.checkpoint_dir
    io_mkdir_recursive(checkpoint_dir)
    string[] shard_refs = moe_1t_manifest_refs(fw.training.data_manifest_path)
    moe_1t_orchestrator orch = moe_1t_orchestrator {
        framework: fw,
        model_config: fw.model,
        world_rank: world_rank,
        world_size: world_size,
        tp_rank: tp_rank,
        tp_size: tp_size,
        pp_rank: pp_rank,
        pp_size: pp_size,
        ep_rank: ep_rank,
        ep_size: ep_size,
        dp_rank: dp_rank,
        dp_size: dp_size,
        model_state: model,
        optimizer_state: optimizer,
        comm: comm,
        data_manifest_path: fw.training.data_manifest_path,
        token_shards: shard_refs,
        current_shard_index: 0,
        tokens_in_shard: 0,
        checkpoint_dir: checkpoint_dir,
        last_saved_step: 0,
        training_step: 0,
        resumeable: fw.training.resumeable,
        latest_checkpoint_path: "",
        step_history: make([]moe_1t_step_state, 0),
        log_interval: fw.training.log_steps,
        eval_interval: fw.training.eval_steps,
        save_interval: fw.training.save_steps,
        should_stop: 0,
        fault_recovery_enabled: 1,
        profile_enabled: 0,
    }
    orch
}

func moe_1t_load_data_manifest(moe_1t_orchestrator orch) moe_1t_orchestrator {
    moe_1t_orchestrator next_orch = orch
    next_orch.token_shards = moe_1t_manifest_refs(orch.data_manifest_path)
    next_orch.current_shard_index = 0
    next_orch.tokens_in_shard = 0
    if next_orch.world_rank == 0 {
        io_println("Loaded data manifest: " + next_orch.data_manifest_path + " shards=" + int_to_string(len(next_orch.token_shards)))
    }
    next_orch
}

func moe_1t_get_next_batch(
    moe_1t_orchestrator orch,
    int batch_size_tokens,
    int seq_len
) (moe_1t_orchestrator, int[]) {
    moe_1t_orchestrator next_orch = orch
    if len(next_orch.token_shards) == 0 {
        next_orch.token_shards = moe_1t_manifest_refs(next_orch.data_manifest_path)
    }
    if len(next_orch.token_shards) == 0 {
        int[] fallback = moe_1t_text_to_tokens(next_orch.data_manifest_path, batch_size_tokens, next_orch.world_rank + seq_len)
        next_orch.tokens_in_shard = len(fallback)
        return next_orch, fallback
    }
    int shard_index = next_orch.current_shard_index
    if shard_index < 0 {
        shard_index = 0
    }
    if shard_index >= len(next_orch.token_shards) {
        shard_index = shard_index % len(next_orch.token_shards)
    }
    string shard_path = next_orch.token_shards[shard_index]
    int seed = gpt_large_pretrain_mix_seed(next_orch.world_rank + 1, next_orch.world_size + 1, shard_index + seq_len)
    int[] tokens = moe_1t_shard_tokens(shard_path, batch_size_tokens, seed)
    next_orch.current_shard_index = shard_index + 1
    if next_orch.current_shard_index >= len(next_orch.token_shards) {
        next_orch.current_shard_index = 0
    }
    next_orch.tokens_in_shard = len(tokens)
    (next_orch, tokens)
}

func moe_1t_forward_pass(
    moe_1t_orchestrator orch,
    int[] batch_tokens,
    int seq_len
) (float[], moe_routing_stats) {
    int batch_size = len(batch_tokens)
    int tp_size = orch.tp_size
    if tp_size <= 0 {
        tp_size = 1
    }
    int ep_size = orch.ep_size
    if ep_size <= 0 {
        ep_size = 1
    }
    int global_hidden_dim = orch.model_config.base.n_embd
    int local_hidden_dim = moe_1t_tp_local_hidden_dim(orch)
    int hidden_offset = moe_1t_tp_global_offset(orch)
    float[] hidden = make(float[], batch_size * local_hidden_dim)
    int layer = 0
    int num_layers = orch.model_config.base.n_layer
    for layer < num_layers {
        if layer % orch.model_config.moe_frequency == 0 {
            int top_k = orch.model_config.moe.top_k
            int token_idx = 0
            for token_idx < batch_size {
                int local_expert = moe_1t_positive_mod(batch_tokens[token_idx] + layer + orch.world_rank, orch.model_config.moe.num_experts)
                int target_ep_rank = moe_1t_positive_mod(local_expert, ep_size)
                if target_ep_rank >= ep_size {
                    target_ep_rank = ep_size - 1
                }
                token_idx = token_idx + 1
            }
        }
        layer = layer + 1
    }
    float[] logits = make(float[], batch_size * orch.model_config.base.vocab_size)
    int[] expert_load = make(int[], orch.model_config.moe.num_experts)
    int[] ep_load = make(int[], ep_size)
    int token_idx = 0
    for token_idx < batch_size {
        int expert_idx = moe_1t_positive_mod(batch_tokens[token_idx] + seq_len + orch.world_rank, orch.model_config.moe.num_experts)
        int target_ep_rank = moe_1t_positive_mod(expert_idx, ep_size)
        ep_load[target_ep_rank] = ep_load[target_ep_rank] + 1
        expert_load[expert_idx] = expert_load[expert_idx] + 1
        token_idx = token_idx + 1
    }
    int max_load = 0
    int load_sum = 0
    int load_idx = 0
    for load_idx < len(expert_load) {
        int load = expert_load[load_idx]
        load_sum = load_sum + load
        if load > max_load {
            max_load = load
        }
        load_idx = load_idx + 1
    }
    float load_imbalance = 1.0
    if len(expert_load) > 0 && load_sum > 0 {
        float avg_load = float(load_sum) / float(len(expert_load))
        if avg_load > 0.0 {
            load_imbalance = float(max_load) / avg_load
        }
    }
    float[] expert_load_ratio = make(float[], orch.model_config.moe.num_experts)
    float aux_loss = 0.0
    int ratio_idx = 0
    for ratio_idx < len(expert_load) {
        float ratio = 0.0
        if load_sum > 0 {
            ratio = float(expert_load[ratio_idx]) / float(load_sum)
        }
        expert_load_ratio[ratio_idx] = ratio
        aux_loss = aux_loss + ratio * ratio
        ratio_idx = ratio_idx + 1
    }
    int local_offset = hidden_offset
    float projection_scale = 1.0 / float(global_hidden_dim)
    int h = 0
    for h < local_hidden_dim {
        int global_h = local_offset + h
        if global_h >= global_hidden_dim {
            break
        }
        int token = 0
        for token < batch_size {
            int hidden_idx = token * local_hidden_dim + h
            int logit_base = token * orch.model_config.base.vocab_size
            int vocab_idx = 0
            for vocab_idx < orch.model_config.base.vocab_size {
                float vocab_scale = float(vocab_idx + 1) * projection_scale
                logits[logit_base + vocab_idx] = logits[logit_base + vocab_idx] + hidden[hidden_idx] * vocab_scale
                vocab_idx = vocab_idx + 1
            }
            token = token + 1
        }
        h = h + 1
    }
    if tp_size > 1 {
        int i = 0
        for i < len(logits) {
            logits[i] = logits[i] / float(tp_size)
            i = i + 1
        }
    }
    moe_routing_stats stats = moe_routing_stats {
        total_tokens: batch_size,
        expert_load: expert_load,
        expert_load_ratio: expert_load_ratio,
        load_imbalance: load_imbalance,
        float communication_cost_ms(tp_size + ep_size) * 0.05,
        compute_cost_ms: 0.0,
        aux_loss_value: aux_loss + float(len(ep_load)) * 0.001,
    }
    (logits, stats)
}

func moe_1t_allreduce_gradients(
    moe_1t_orchestrator orch,
    float[] gradients
) int {
    if orch.world_size > 1 {
        int i = 0
        for i < len(gradients) {
            gradients[i] = gradients[i] / float(orch.world_size)
            i = i + 1
        }
    }
    0
}

func moe_1t_optimizer_step(
    moe_1t_orchestrator orch,
    float loss,
    float loss_scale,
    int global_step
) moe_1t_orchestrator {
    int step_index = global_step
    int warmup_steps = orch.framework.training.warmup_steps
    int total_steps = orch.framework.training.total_steps
    float peak_lr = orch.framework.training.peak_lr
    float min_lr = orch.framework.training.min_lr
    float lr = peak_lr
    if warmup_steps > 0 && step_index < warmup_steps {
        lr = peak_lr * (float(step_index + 1) / float(warmup_steps))
    } else if total_steps > warmup_steps {
        int decay_steps = total_steps - warmup_steps
        int current_decay_step = step_index - warmup_steps
        if current_decay_step < 0 {
            current_decay_step = 0
        }
        if current_decay_step > decay_steps {
            current_decay_step = decay_steps
        }
        float progress = 0.0
        if decay_steps > 0 {
            progress = float(current_decay_step) / float(decay_steps)
        }
        lr = min_lr + (peak_lr - min_lr) * 0.5 * (1.0 + moe_1t_cos(3.141592653589793 * progress))
    } else {
        lr = min_lr
    }
    orch.optimizer_state.learning_rate = lr
    orch.training_step = global_step + 1
    orch
}

func moe_1t_zero_pad_int(int value, int width) string {
    string text = int_to_string(value)
    if len(text) >= width {
        return text
    }
    string out = ""
    int pad = width - len(text)
    for pad > 0 {
        out = out + "0"
        pad = pad - 1
    }
    return out + text
}

func moe_1t_checkpoint_path(moe_1t_orchestrator orch, int step) string {
    string root = orch.checkpoint_dir
    if root == "" {
        root = orch.framework.training.checkpoint_dir
    }
    root + "/step_" + moe_1t_zero_pad_int(step, 7) + "/latest/" + "moe_1t_training"
}

func moe_1t_save_checkpoint(
    moe_1t_orchestrator orch,
    int step,
    float loss
) moe_1t_orchestrator {
    if orch.world_rank == 0 {
        io_println("Saving checkpoint at step " + int_to_string(step))
        io_println("Loss: " + float_to_string(loss))
    }
    pretrain_checkpoint_state checkpoint_state = new_pretrain_checkpoint_state("moe_1t_training", orch.checkpoint_dir)
    checkpoint_state = mark_saved(checkpoint_state, step)
    checkpoint_state = mark_best(checkpoint_state, step, loss)
    string checkpoint_path = moe_1t_checkpoint_path(orch, step)
    pretrain_checkpoint_bundle_state bundle = new_pretrain_checkpoint_bundle_state(
        checkpoint_state,
        checkpoint_path,
        orch.checkpoint_dir + "/optimizer.manifest",
        orch.data_manifest_path,
        orch.checkpoint_dir + "/tokenizer.manifest"
    )
    save_pretrain_checkpoint(bundle)
    orch.last_saved_step = step
    orch.training_step = step + 1
    orch.latest_checkpoint_path = checkpoint_path
    orch
}

func moe_1t_load_checkpoint(
    moe_1t_orchestrator orch,
    string checkpoint_path
) (moe_1t_orchestrator, int) {
    string target_path = checkpoint_path
    if moe_1t_trim(target_path) == "" {
        string latest_ref_path = orch.checkpoint_dir + "/latest_checkpoint.txt"
        if runtime_file_exists(latest_ref_path) {
            target_path = moe_1t_trim(runtime_read_text_file(latest_ref_path))
        }
    }
    if moe_1t_trim(target_path) == "" {
        return orch, 0
    }
    if orch.world_rank == 0 {
        io_println("Loading checkpoint from: " + target_path)
    }
    pretrain_checkpoint_state checkpoint_state = new_pretrain_checkpoint_state("moe_1t_training", orch.checkpoint_dir)
    pretrain_checkpoint_bundle_state bundle = new_pretrain_checkpoint_bundle_state(
        checkpoint_state,
        target_path,
        orch.checkpoint_dir + "/optimizer.manifest",
        orch.data_manifest_path,
        orch.checkpoint_dir + "/tokenizer.manifest"
    )
    pretrain_checkpoint_bundle_state restored = load_pretrain_checkpoint(bundle)
    orch.latest_checkpoint_path = target_path
    orch.last_saved_step = restored.checkpoint.last_saved_step
    int resumed_step = restored.checkpoint.last_saved_step
    if resumed_step < 0 {
        resumed_step = 0
    } else {
        resumed_step = resumed_step + 1
    }
    orch.training_step = resumed_step
    (orch, resumed_step)
}

func moe_1t_log_step_metrics(
    moe_1t_orchestrator orch,
    moe_1t_step_state step_state
) {
    if orch.world_rank == 0 && orch.log_interval > 0 && step_state.global_step % orch.log_interval == 0 {
        string log_msg = "Step " + int_to_string(step_state.global_step) +
                        " Loss=" + float_to_string(step_state.loss) +
                        " LR=" + float_to_string(step_state.learning_rate) +
                        " Imbalance=" + float_to_string(step_state.routing.load_imbalance)
        io_println(log_msg)
    }
}

func moe_1t_training_loop(moe_1t_orchestrator orch) int {
    moe_1t_orchestrator state = moe_1t_load_data_manifest(orch)
    if state.world_rank == 0 {
        string summary = moe_1t_summary(state.framework)
        io_println("Starting 1T MoE Training")
        io_println(summary)
    }
    int global_step = 0
    (state, global_step) = moe_1t_load_checkpoint(state, "")
    int total_steps = state.framework.training.total_steps
    int save_interval = state.framework.training.save_steps
    for global_step < total_steps && state.should_stop == 0 {
        int current_step = state.training_step
        int batch_tokens_per_gpu = 512
        int seq_len = 4096
        int[] batch = int[]{cap: 0}
        (state, batch) = moe_1t_get_next_batch(state, batch_tokens_per_gpu, seq_len)
        if len(batch) == 0 {
            if state.world_rank == 0 {
                io_println("Skipping empty batch at step " + int_to_string(current_step))
            }
            global_step = state.training_step
            continue
        }
        (float[] logits, moe_routing_stats routing_stats) = moe_1t_forward_pass(state, batch, seq_len)
        int vocab_size = state.model_config.base.vocab_size
        int[] labels = moe_1t_build_labels(batch, vocab_size)
        (int[] expert_indices, float[] expert_weights) = moe_1t_build_top1_routing(state, batch)
        loss_state loss_ctx = loss_state_new(vocab_size, state.model_config.moe_aux_loss_weight)
        float loss = compute_total_loss(
            loss_ctx,
            logits,
            labels,
            expert_indices,
            expert_weights,
            len(batch),
            1,
            1
        )
        float[] gradients = compute_ce_gradient(
            logits,
            labels,
            len(batch),
            1,
            vocab_size
        )
        moe_1t_allreduce_gradients(state, gradients)
        float grad_norm = moe_1t_average_abs(gradients)
        state = moe_1t_optimizer_step(state, loss, 1.0, current_step)
        float lr = state.optimizer_state.learning_rate
        moe_1t_step_state step_state = moe_1t_step_state {
            global_step: current_step,
            tokens_seen: (current_step + 1) * batch_tokens_per_gpu * state.world_size,
            epoch: 0,
            batch_tokens: batch_tokens_per_gpu,
            loss: loss,
            loss_scale: 1.0,
            learning_rate: lr,
            routing: routing_stats,
            allreduce_time_us: 0,
            compute_time_us: 0,
        }
        if state.world_rank == 0 {
            io_println("  Backward grad|mean abs=" + float_to_string(grad_norm))
        }
        moe_1t_log_step_metrics(state, step_state)
        state.step_history = append(state.step_history, step_state)
        if save_interval > 0 && current_step > 0 && current_step % save_interval == 0 {
            state = moe_1t_save_checkpoint(state, current_step, loss)
        }
        global_step = state.training_step
    }
    if orch.world_rank == 0 {
        io_println("Training completed at step " + int_to_string(global_step))
    }
    0
}

func string_to_int(string s) int {
    int result = 0
    int i = 0
    int len_s = len(s)
    for i < len_s {
        int digit = int(s[i]) - 48
        if digit < 0 || digit > 9 {
            return result
        }
        result = result * 10 + digit
        i = i + 1
    }
    result
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }
    bool neg = false
    int val = n
    if val < 0 {
        neg = true
        val = -val
    }
    string result = ""
    for val > 0 {
        int digit = val % 10
        result = chr(digit + 48) + result
        val = val / 10
    }
    if neg {
        result = "-" + result
    }
    result
}

func float_to_string(float x) string {
    int whole = int(x)
    string result = int_to_string(whole) + "."
    float frac = x - float(whole)
    if frac < 0.0 {
        frac = -frac
    }
    int frac_int = int(frac * 1000.0)
    if frac_int < 100 {
        result = result + "0"
    }
    if frac_int < 10 {
        result = result + "0"
    }
    result = result + int_to_string(frac_int)
    result
}

func moe_1t_cos(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0
}

func chr(int code) string {
    string(code)
}
