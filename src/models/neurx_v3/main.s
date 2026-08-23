package neurx.model.neurx.main
use neurx.attention.mla
use neurx.moe.fine_grained
use neurx.model.neurx.mtp
use neurx.model.neurx.fp8_training
use neurx.alignment.neurx_r1_grpo

struct neurx_v3_config {
    int hidden_dim
    int num_layers
    int vocab_size
    int num_heads
    int kv_lora_rank
    int q_lora_rank
    int rope_head_dim
    int n_routed_experts
    int n_shared_experts
    int n_activated_experts
    int ffn_dim
    float bias_update_speed
    int num_mtp_layers
    int mtp_ffn_dim
    int max_seq_len
    int batch_size
}

func new_neurx_v3_config() neurx_v3_config {
    neurx_v3_config {
        hidden_dim: 5120,
        num_layers: 60,
        vocab_size: 128000,
        num_heads: 128,
        kv_lora_rank: 512,
        q_lora_rank: 1536,
        rope_head_dim: 64,
        n_routed_experts: 256,
        n_shared_experts: 2,
        n_activated_experts: 8,
        ffn_dim: 1536,
        bias_update_speed: 0.001,
        num_mtp_layers: 2,
        mtp_ffn_dim: 12288,
        max_seq_len: 4096,
        batch_size: 128,
    }
}

struct neurx_transformer_block {
    mla.mla_weights mla_weights
    []float mla_norm
    moe.neurx_moe_weights moe_weights
    []float moe_norm
}

struct neurx_v3_model {
    neurx_v3_config config
    []float token_embedding
    []float position_embedding
    []neurx_transformer_block blocks
    []float final_norm
    []float lm_head
    mtp.mtp_weights mtp_weights
}

func demonstrate_kv_cache_savings() {
    println("========================================")
    println("  KV cache: MLA vs Standard MHA")
    println("========================================")
    println("")
    int n_layers = 60
    int n_heads = 128
    int d_head = 128
    int d_lora = 512
    int d_rope = 64
    int standard_kv = 2 * n_layers * n_heads * d_head
    int mla_kv = 2 * n_layers * (d_lora + n_heads * d_rope)
    println("Standard MHA KV cache (per token):")
    println("  2 * " + int_to_string(n_layers) + " * " + int_to_string(n_heads) + " * " + int_to_string(d_head) +
            " = " + int_to_string(standard_kv) + " floats")
    println("  ~ " + int_to_string(standard_kv * 4 / 1024) + " KB (fp32)")
    println("")
    println("MLA KV cache (per token):")
    println("  2 * " + int_to_string(n_layers) + " * (" + int_to_string(d_lora) + " + " +
            int_to_string(n_heads) + " * " + int_to_string(d_rope) + ")")
    println("  = " + int_to_string(mla_kv) + " floats")
    println("  ~ " + int_to_string(mla_kv * 4 / 1024) + " KB (fp32)")
    println("")
    float savings = (standard_kv - mla_kv) as float / standard_kv as float * 100.0
    println("Savings: " + float_to_string(savings) + "%")
    println("")
    int seq_len = 4096
    int mla_total_kb = mla_kv * seq_len * 4 / 1024
    int standard_total_gb = standard_kv * seq_len * 4 / 1024 / 1024
    println("Real scenario (seq_len=" + int_to_string(seq_len) + "):")
    println("  Standard MHA: ~" + int_to_string(standard_total_gb) + " GB")
    println("  MLA:          ~" + int_to_string(mla_total_kb / 1024) + " MB")
}

func demonstrate_moe() {
    println("")
    println("========================================")
    println("  NeurX MoE Architecture Demo")
    println("========================================")
    println("")
    moe.neurx_moe_config cfg = moe.new_neurx_moe_config()
    println("config:")
    println("  Routed experts:  " + int_to_string(cfg.n_routed_experts) + " (fine-grained)")
    println("  Shared experts:  " + int_to_string(cfg.n_shared_experts) + " (always on)")
    println("  Activated:       " + int_to_string(cfg.n_activated_experts) + " (per token)")
    println("  Bias update:     gamma = " + float_to_string(cfg.bias_update_speed))
    println("")
    int total_params = moe.compute_moe_params(cfg)
    int activated_params = moe.compute_activated_params(cfg)
    println("Parameters:")
    println("  Total:     " + int_to_string(total_params / 1000000) + "M")
    println("  Activated: " + int_to_string(activated_params / 1000000) + "M")
    println("  Sparsity:  " + float_to_string((1.0 - activated_params as float / total_params as float) * 100) + "%")
    println("")
    moe.neurx_moe_weights w = moe.new_neurx_moe_weights(cfg)
    println("NeurX MoE weights initialized")
    println("  Gate: [" + int_to_string(cfg.hidden_dim) + " x " + int_to_string(cfg.n_routed_experts) + "]")
    println("  Routed experts: " + int_to_string(len(w.routed_w1)))
    println("")
    int n_tokens = 4
    []float h = moe.zeros(n_tokens * cfg.hidden_dim)
    int i = 0
    while i < n_tokens * cfg.hidden_dim {
        h[i] = 0.1
        i = i + 1
    }
    moe.neurx_moe_output out = moe.neurx_moe_forward(w, h, n_tokens)
    println("Forward test:")
    println("  Input tokens: " + int_to_string(n_tokens))
    println("  Output dim:   [" + int_to_string(n_tokens) + " x " + int_to_string(cfg.hidden_dim) + "]")
    println("  Output[0]:    " + float_to_string(out.output[0]))
    moe.load_balance_stats stats = moe.compute_load_stats(
        out.route.expert_load, cfg.n_routed_experts, n_tokens, cfg.n_activated_experts
    )
    println("  Load balance: max/avg = " + float_to_string(stats.load_imbalance_ratio))
    println("  Utilization:  " + float_to_string(stats.utilization * 100.0) + "%")
}

func demonstrate_mtp() {
    println("")
    println("========================================")
    println("  Multi-Token Prediction Demo")
    println("========================================")
    println("")
    mtp.mtp_config cfg = mtp.new_mtp_config()
    println("config:")
    println("  Prediction depth D: " + int_to_string(cfg.num_mtp_layers))
    println("  Hidden dim:         " + int_to_string(cfg.hidden_dim))
    println("  FFN dim:            " + int_to_string(cfg.ff_intermediate_dim))
    println("")
    println("Data efficiency:")
    println("  Standard: 1 supervision signal per token")
    println("  MTP (D=" + int_to_string(cfg.num_mtp_layers) + "): " + int_to_string(1 + cfg.num_mtp_layers) + " signals per token")
    println("  Improvement: " + float_to_string(cfg.num_mtp_layers as float * 100.0) + "%")
    println("")
    mtp.mtp_weights w = mtp.new_mtp_weights(cfg)
    println("MTP weights initialized, modules: " + int_to_string(len(w.modules)))
    int seq_len = 4
    int d = cfg.hidden_dim
    []float main_hidden = mla.zeros(seq_len * d)
    int i = 0
    while i < seq_len * d {
        main_hidden[i] = 0.1
        i = i + 1
    }
    []int targets = []int{cap: 4}
    targets[0] = 42
    targets[1] = 100
    targets[2] = 5000
    targets[3] = 7
    mtp.mtp_forward_output out = mtp.mtp_forward(w, main_hidden, targets, seq_len)
    println("Forward test:")
    println("  Total loss: " + float_to_string(out.total_loss))
    int j = 0
    while j < cfg.num_mtp_layers {
        println("  Module " + int_to_string(j) + " loss: " + float_to_string(out.per_module_loss[j]))
        j = j + 1
    }
}

func demonstrate_grpo() {
    println("")
    println("========================================")
    println("  NeurX-R1 GRPO Demo")
    println("========================================")
    println("")
    neurx_r1_grpo.grpo_config cfg = neurx_r1_grpo.new_grpo_config()
    println("config:")
    println("  Group size G:  " + int_to_string(cfg.group_size))
    println("  Clip epsilon:  " + float_to_string(cfg.clip_epsilon))
    println("  KL beta:       " + float_to_string(cfg.kl_beta))
    println("")
    println("NeurX-R1 vs standard PPO/GRPO:")
    println("  - No Critic model: group-relative advantage")
    println("  - Rule Rewards: deterministic, not neural RM")
    println("  - A_i = (r_i - mean) / std (within group)")
    println("")
    int G = cfg.group_size
    []neurx_r1_grpo.generation_output outputs = []neurx_r1_grpo.generation_output{cap: G}
    int i = 0
    while i < G {
        float quality = (i as float + 1.0) / G as float * 2.0
        []float log_probs = []float{cap: 10}
        int j = 0
        while j < 10 {
            log_probs[j] = -0.1 * quality + (j as float - 5.0) * 0.05
            j = j + 1
        }
        []int token_ids = []int{cap: 10}
        j = 0
        while j < 10 {
            token_ids[j] = j * 10 + i
            j = j + 1
        }
        outputs[i] = neurx_r1_grpo.generation_output {
            text: "Output " + int_to_string(i),
            token_ids: token_ids,
            log_probs: log_probs,
            reward: quality,
            format_reward: 0.8,
            accuracy_reward: quality - 0.8,
        }
        i = i + 1
    }
    ([]float advantages, float mean_r, float std_r) = neurx_r1_grpo.compute_group_advantages(outputs, G)
    println("Group rewards & advantages (G=" + int_to_string(G) + "):")
    println("  mean = " + float_to_string(mean_r) + ", std = " + float_to_string(std_r))
    println("")
    i = 0
    while i < G {
        println("  Output " + int_to_string(i) + ": reward=" + float_to_string(outputs[i].reward) +
                ", advantage=" + float_to_string(advantages[i]))
        i = i + 1
    }
    println("")
    println("  advantage > 0 -> better than group avg -> reinforced")
    println("  advantage < 0 -> worse than group avg -> suppressed")
    println("  No critic/value model needed!")
}

func demonstrate_rule_rewards() {
    println("")
    println("========================================")
    println("  Rule-Based Rewards Demo")
    println("========================================")
    println("")
    string correct = "  Let me solve this step by step.\n" +
        "First, x + 2 = 5, so x = 3.\n" +
        "Therefore, the answer is \\boxed{3}.  "
    string bad = "3"
    println("Correct format output:")
    float format_r1 = neurx_r1_grpo.compute_format_reward(correct)
    float accuracy_r1 = neurx_r1_grpo.compute_accuracy_reward(correct, "3")
    println("  Format: " + float_to_string(format_r1) + ", Accuracy: " + float_to_string(accuracy_r1))
    println("")
    println("Bad format output: \"" + bad + "\"")
    float format_r2 = neurx_r1_grpo.compute_format_reward(bad)
    float accuracy_r2 = neurx_r1_grpo.compute_accuracy_reward(bad, "3")
    println("  Format: " + float_to_string(format_r2) + ", Accuracy: " + float_to_string(accuracy_r2))
    println("")
    println("  Deterministic, explainable, no reward hacking")
}

func demonstrate_fp8() {
    println("")
    println("========================================")
    println("  FP8 Mixed Precision Training Demo")
    println("========================================")
    println("")
    fp8_training.fp8_config cfg = fp8_training.new_fp8_config()
    println("config:")
    println("  Forward dtype:  " + cfg.forward_dtype)
    println("  Backward dtype: " + cfg.backward_dtype)
    println("  Tile size:      " + int_to_string(cfg.tile_size_m) + "x" + int_to_string(cfg.tile_size_n))
    println("  Grad compress:  " + bool_to_string(cfg.compress_gradients))
    println("")
    println("NeurX-V3 FP8 strategy:")
    println("  GEMM:       FP8 forward + FP8 backward")
    println("  embedding:  BF16 (precision sensitive)")
    println("  Attention:  BF16 (softmax sensitive)")
    println("  MoE gate:   BF16 (routing sensitive)")
    println("  Norm:       FP32 (stability)")
    println("")
    fp8_training.fp8_training_state state = fp8_training.new_fp8_training_state(cfg)
    fp8_training.fp8_monitor monitor = fp8_training.fp8_get_monitor(state, 1000000)
    println("Monitor:")
    println("  Memory saved:  " + float_to_string(monitor.memory_saved_percent) + "%")
    println("  Speedup:       " + float_to_string(monitor.speedup_estimated) + "x")
}

func int_to_string(int n) string {
    if n == 0 { return "0" }
    string result = ""
    int num = n
    bool is_neg = n < 0
    if is_neg { num = -num }
    while num > 0 {
        int digit = num % 10
        result = digit_to_char(digit) + result
        num = num / 10
    }
    if is_neg { result = "-" + result }
    result
}

func digit_to_char(int d) string {
    if d == 0 { return "0" }
    if d == 1 { return "1" }
    if d == 2 { return "2" }
    if d == 3 { return "3" }
    if d == 4 { return "4" }
    if d == 5 { return "5" }
    if d == 6 { return "6" }
    if d == 7 { return "7" }
    if d == 8 { return "8" }
    if d == 9 { return "9" }
    "?"
}

func float_to_string(float x) string {
    string result = ""
    if x < 0.0 {
        result = "-"
        x = -x
    }
    int int_part = x as int
    result = result + int_to_string(int_part)
    result = result + "."
    float frac = x - int_part as float
    int d = 0
    while d < 4 {
        frac = frac * 10.0
        int digit = frac as int
        result = result + digit_to_char(digit)
        frac = frac - digit as float
        d = d + 1
    }
    result
}

func bool_to_string(bool b) string {
    if b { return "true" }
    "false"
}

func unit_name() string {
    "neurx/model/neurx/main"
}

func unit_ready() int {
    1
}

func main() {
    println("============================================")
    println("  NeurX Core Features - neurx project")
    println("============================================")
    println("")
    println("Five core innovations:")
    println("  1. MLA  - Multi-Head Latent Attention")
    println("  2. MoE  - NeurX MoE (fine-grained + shared)")
    println("  3. MTP  - Multi-Token Prediction")
    println("  4. GRPO - Group Relative Policy Optimization")
    println("  5. FP8  - Block-wise FP8 Mixed Precision")
    println("")
    println("Files:")
    println("  neurx/model/neurx/mla.s")
    println("  src/models/extensions/moe/fine_grained_moe.s")
    println("  neurx/model/neurx/mtp.s")
    println("  neurx/model/neurx/fp8_training.s")
    println("  neurx/alignment/neurx_r1_grpo.s")
    println("")
    demonstrate_kv_cache_savings()
    demonstrate_moe()
    demonstrate_mtp()
    demonstrate_grpo()
    demonstrate_rule_rewards()
    demonstrate_fp8()
    println("")
    println("============================================")
    println("  Summary: neurx vs NeurX reference")
    println("============================================")
    println("")
    println("  Feature            | neurx         | NeurX")
    println("  -------------------+---------------+---------------")
    println("  Attention          | MHA/GQA       | MLA (93% less)")
    println("  MoE                | Standard TopK | Fine+Shared")
    println("  Load Balancing     | Aux loss      | Dynamic bias")
    println("  Multi-Token Pred   | -             | MTP (D=2)")
    println("  RL Alignment       | DPO+GRPO      | R1-Style GRPO")
    println("  Reward model       | Neural RM     | Rule-based")
    println("  FP8 Training       | -             | Block-wise FP8")
    println("  Expert Count       | 8-64          | 256+2")
    println("")
    println("=== NeurX Core Features Demo Complete ===")
}
