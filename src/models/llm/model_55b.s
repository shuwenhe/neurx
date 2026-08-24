package neurx.model.llm.base_5_5
use neurx.model.llm.gpt.{
    model_config, gpt_param_count, gpt_describe, int_to_str_simple
}
use neurx.moe.llm.{
    gpt_moe_config, gpt_moe_param_count
}
use neurx.moe.transformer.{
    moe_stats, moe_compute_stats, new_moe_config
}

struct gpt_5_5_model_spec {
    string model_name
    model_config dense_base
    gpt_moe_config sparse_model
    int target_total_params
    int target_active_params
    int target_tokens_b
    int context_window
    int warmup_steps
    int total_steps
    int save_interval
    int eval_interval
    int log_interval
    float peak_lr
    float min_lr
    string tokenizer_manifest
    string data_manifest
    string checkpoint_dir
    string output_dir
}

struct gpt_5_5_parallel_plan {
    int world_size
    int tensor_parallel_size
    int pipeline_parallel_size
    int expert_parallel_size
    int data_parallel_size
    int zero_stage
    bool activation_checkpointing
    bool sharded_optimizer
    bool sharded_checkpoint
    bool bf16
    bool flash_attention
    bool elastic_recovery
}

struct gpt_5_5_model {
    gpt_5_5_model_spec spec
    gpt_5_5_parallel_plan parallel
}

func gpt_5_5_dense_base() model_config {
    model_config {
        name: "gpt-5.5-style",
        vocab_size: 128000,
        n_embd: 12288,
        n_layer: 96,
        n_head: 96,
        n_kv_head: 16,
        ffn_dim: 49152,
        block_size: 32768,
        rope_base: 500000.0,
        dropout: 0.0,
        use_bias: false,
        activation: "swiglu",
        tie_embeddings: false,
    }
}

func gpt_5_5_sparse_model() gpt_moe_config {
    gpt_moe_config {
        base: gpt_5_5_dense_base(),
        moe: new_moe_config(12288, 49152, 128, 2),
        moe_frequency: 1,
        moe_aux_loss_weight: 0.0025,
    }
}

func gpt_5_5_parallel_default() gpt_5_5_parallel_plan {
    gpt_5_5_parallel_plan {
        world_size: 64,
        tensor_parallel_size: 8,
        pipeline_parallel_size: 8,
        expert_parallel_size: 8,
        data_parallel_size: 1,
        zero_stage: 3,
        activation_checkpointing: true,
        sharded_optimizer: true,
        sharded_checkpoint: true,
        bf16: true,
        flash_attention: true,
        elastic_recovery: true,
    }
}

func gpt_5_5_spec_default() gpt_5_5_model_spec {
    gpt_5_5_model_spec {
        model_name: "gpt-5.5-style-frontier",
        dense_base: gpt_5_5_dense_base(),
        sparse_model: gpt_5_5_sparse_model(),
        target_total_params: 2000000000000,
        target_active_params: 180000000000,
        target_tokens_b: 3000,
        context_window: 32768,
        warmup_steps: 10000,
        total_steps: 750000,
        save_interval: 1000,
        eval_interval: 5000,
        log_interval: 50,
        peak_lr: 0.0002,
        min_lr: 0.00002,
        tokenizer_manifest: "src/training/data/tokenizer.manifest",
        data_manifest: "dataset/pretrain/manifest.json",
        checkpoint_dir: "checkpoints/gpt_5_5",
        output_dir: "artifact/gpt_5_5",
    }
}

func gpt_5_5_model_default() gpt_5_5_model {
    gpt_5_5_model {
        spec: gpt_5_5_spec_default(),
        parallel: gpt_5_5_parallel_default(),
    }
}

func gpt_5_5_total_params(gpt_5_5_model_spec spec) int {
    gpt_moe_param_count(spec.sparse_model)
}

func gpt_5_5_dense_params(gpt_5_5_model_spec spec) int {
    gpt_param_count(spec.dense_base)
}

func gpt_5_5_effective_active_params(gpt_5_5_model_spec spec) int {
    int total_params = gpt_5_5_total_params(spec)
    int dense_params = gpt_5_5_dense_params(spec)
    int nl = spec.sparse_model.base.n_layer
    int H = spec.sparse_model.base.n_embd
    int moe_freq = spec.sparse_model.moe_frequency
    if moe_freq < 1 {
        moe_freq = 1
    }
    int moe_layers = nl / moe_freq
    if moe_layers < 1 {
        moe_layers = 1
    }
    int dense_ffn_per_layer = 3 * H * spec.sparse_model.base.ffn_dim
    int removed_dense_ffn = moe_layers * dense_ffn_per_layer
    moe_stats stats = moe_compute_stats(spec.sparse_model.moe)
    int active_params = dense_params - removed_dense_ffn
    if active_params < 0 {
        active_params = 0
    }
    active_params = active_params + moe_layers * stats.active_params
    if total_params > 0 && active_params > total_params {
        active_params = total_params
    }
    active_params
}

func gpt_5_5_active_ratio(gpt_5_5_model_spec spec) float {
    int total_params = gpt_5_5_total_params(spec)
    int active_params = gpt_5_5_effective_active_params(spec)
    if total_params <= 0 {
        return 0.0
    }
    active_params * 1.0 / (total_params * 1.0)
}

func gpt_5_5_ready(gpt_5_5_model model) bool {
    if model.parallel.world_size <= 0 {
        return false
    }
    if model.parallel.tensor_parallel_size * model.parallel.pipeline_parallel_size * model.parallel.expert_parallel_size * model.parallel.data_parallel_size != model.parallel.world_size {
        return false
    }
    if model.spec.dense_base.n_embd <= 0 || model.spec.dense_base.n_layer <= 0 {
        return false
    }
    if model.spec.dense_base.n_embd / model.spec.dense_base.n_head * model.spec.dense_base.n_head != model.spec.dense_base.n_embd {
        return false
    }
    true
}

func gpt_5_5_summary(gpt_5_5_model model) string {
    int total_params = gpt_5_5_total_params(model.spec)
    int dense_params = gpt_5_5_dense_params(model.spec)
    int active_params = gpt_5_5_effective_active_params(model.spec)
    float active_ratio = gpt_5_5_active_ratio(model.spec) * 100.0
    string out = ""
    out = out + "GPT-5.5 Style Frontier Spec\n"
    out = out + "name=" + model.spec.model_name + "\n"
    out = out + "dense_base=" + gpt_describe(model.spec.dense_base) + "\n"
    out = out + "total_params=" + int_to_str_simple(total_params) + "\n"
    out = out + "dense_params=" + int_to_str_simple(dense_params) + "\n"
    out = out + "active_params=" + int_to_str_simple(active_params) + "\n"
    out = out + "active_ratio=" + float_to_string(active_ratio) + "%\n"
    out = out + "context_window=" + int_to_str_simple(model.spec.context_window) + "\n"
    out = out + "warmup_steps=" + int_to_str_simple(model.spec.warmup_steps) + "\n"
    out = out + "total_steps=" + int_to_str_simple(model.spec.total_steps) + "\n"
    out = out + "peak_lr=" + float_to_string(model.spec.peak_lr) + "\n"
    out = out + "min_lr=" + float_to_string(model.spec.min_lr) + "\n"
    out = out + "tokenizer=" + model.spec.tokenizer_manifest + "\n"
    out = out + "data_manifest=" + model.spec.data_manifest + "\n"
    out = out + "checkpoint_dir=" + model.spec.checkpoint_dir + "\n"
    out = out + "output_dir=" + model.spec.output_dir + "\n"
    out = out + "world_size=" + int_to_str_simple(model.parallel.world_size) + "\n"
    out = out + "tp=" + int_to_str_simple(model.parallel.tensor_parallel_size) + "\n"
    out = out + "pp=" + int_to_str_simple(model.parallel.pipeline_parallel_size) + "\n"
    out = out + "ep=" + int_to_str_simple(model.parallel.expert_parallel_size) + "\n"
    out = out + "zero_stage=" + int_to_str_simple(model.parallel.zero_stage) + "\n"
    out = out + "ready=" + int_to_str_simple(bool_to_int(gpt_5_5_ready(model))) + "\n"
    out
}

func bool_to_int(bool v) int {
    if v {
        return 1
    }
    0
}

func int_from_float(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}

func float_to_string(float x) string {
    int whole = int_from_float(x)
    float remainder = x - whole * 1.0
    int frac = int_from_float(remainder * 100.0)
    if frac < 0 {
        frac = -frac
    }
    string s = int_to_str_simple(whole) + "."
    if frac < 10 {
        s = s + "0"
    }
    s = s + int_to_str_simple(frac)
    s
}
