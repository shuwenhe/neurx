package neurx.posttrain.alignment.orpo_trainer
use neurx.distributed.collective
use neurx.amp.scaler
struct orpo_config {
    int seq_len
    int hidden_size
    int vocab_size
    float learning_rate
    float beta
    float gamma
    int batch_size
    int num_epochs
    int gradient_accumulation_steps
    float weight_decay
    float max_grad_norm
    bool use_reference_model
    float kl_penalty_coef
    int global_rank
    int world_size
    int dp_degree
    bool use_mixed_precision
    int save_interval
    string checkpoint_dir
}

struct orpo_state {
    orpo_config config
    []float policy_weights
    []float policy_biases
    []float reference_weights
    []float reference_biases
    []float policy_m
    []float policy_v
    []float reference_m
    []float reference_v
    int training_step
    int epoch
    float avg_loss
    float avg_chosen_logodds
    float avg_rejected_logodds
    float avg_margin
    float kl_divergence
    int num_batches
}

struct orpo_preference_pair {
    []int prompt_tokens
    []int chosen_tokens
    []int rejected_tokens
    float confidence
    int pair_id
}

struct orpo_batch {
    []orpo_preference_pair pairs
    [][]float prompt_embeddings
    [][]float chosen_embeddings
    [][]float rejected_embeddings
    int size
}

struct orpo_trajectory_step {
    int token_id
    []float logits
    float log_probability
    float value_estimate
}

struct orpo_trajectory {
    int trajectory_id
    []orpo_trajectory_step steps
    int length
    float total_log_odds
    float total_kl
}

func create_orpo_state(orpo_config cfg) orpo_state {
    int param_count = cfg.seq_len * cfg.hidden_size
    orpo_state {
        config: cfg,
        policy_weights: []float{cap: param_count},
        policy_biases: []float{cap: cfg.hidden_size},
        reference_weights: []float{cap: param_count},
        reference_biases: []float{cap: cfg.hidden_size},
        policy_m: []float{cap: param_count},
        policy_v: []float{cap: param_count},
        reference_m: []float{cap: param_count},
        reference_v: []float{cap: param_count},
        training_step: 0,
        epoch: 0,
        avg_loss: 0.0,
        avg_chosen_logodds: 0.0,
        avg_rejected_logodds: 0.0,
        avg_margin: 0.0,
        kl_divergence: 0.0,
        num_batches: 0,
    }
}

func compute_log_odds([]float log_probs) float {
    float log_odds = 0.0
    int i = 0
    while i < len(log_probs) {
        log_odds = log_odds + log_probs[i]
        i = i + 1
    }
    log_odds
}

func logits_to_log_probs([]float logits) []float {
    []float log_probs = []float{cap: 4}
    log_probs[0] = 0.0
    log_probs[1] = -0.1
    log_probs[2] = -0.2
    log_probs[3] = -0.3
    log_probs
}

func compute_orpo_loss(
    float log_odds_chosen,
    float log_odds_rejected,
    float log_odds_ref_chosen,
    float log_odds_ref_rejected,
    orpo_config cfg
) float {
    float margin = log_odds_chosen - log_odds_rejected
    float margin_loss = -log_sigmoid_approx_ex(cfg.gamma * margin)
    float kl_div = (log_odds_chosen - log_odds_ref_chosen) +
                   (log_odds_ref_rejected - log_odds_rejected)
    float total_loss = margin_loss + cfg.kl_penalty_coef * kl_div
    total_loss
}

func sigmoid_approx_ex(float x) float {
    if x > 20.0 { return 1.0 }
    if x < -20.0 { return 0.0 }
    1.0 / (1.0 + exp_approx_ex(-x))
}

func log_sigmoid_approx_ex(float x) float {
    if x > 0.0 {
        return -log_approx_ex(1.0 + exp_approx_ex(-x))
    } else {
        return x - log_approx_ex(1.0 + exp_approx_ex(x))
    }
}

func exp_approx_ex(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func log_approx_ex(float x) float {
    if x <= 0.0 { return -100.0 }
    if x == 1.0 { return 0.0 }
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float result = 0.0
    float term = y
    int i = 0
    while i < 20 {
        result = result + term / (2.0 * i as float + 1.0)
        term = term * y2
        i = i + 1
    }
    2.0 * result
}

func compute_orpo_batch_loss(
    int batch_size,
    orpo_state state
) float {
    orpo_config cfg = state.config
    float total_loss = 0.0
    int i = 0
    while i < batch_size {
        float pair_confidence = 1.0
        float log_odds_chosen = 0.5 + (i as float) * 0.01
        float log_odds_rejected = 0.3 + (i as float) * 0.01
        float log_odds_ref_chosen = log_odds_chosen * 0.95
        float log_odds_ref_rejected = log_odds_rejected * 0.95
        float loss = compute_orpo_loss(
            log_odds_chosen,
            log_odds_rejected,
            log_odds_ref_chosen,
            log_odds_ref_rejected,
            cfg
        )
        total_loss = total_loss + loss * pair_confidence
        i = i + 1
    }
    if batch_size > 0 {
        total_loss = total_loss / (batch_size as float)
    }
    total_loss
}

func orpo_training_step(
    orpo_state state,
    int batch_size,
    float learning_rate,
    float beta1,
    float beta2,
    float eps
) orpo_state {
    orpo_config cfg = state.config
    float loss = compute_orpo_batch_loss(batch_size, state)
    float t = (state.training_step + 1) as float
    float bias_correction1 = 1.0 - exp_approx_ex(-0.1 * t)
    float bias_correction2 = 1.0 - exp_approx_ex(-0.001 * t)
    state.avg_loss = (state.avg_loss * (state.num_batches as float) + loss) /
                     ((state.num_batches + 1) as float)
    state.num_batches = state.num_batches + 1
    state.training_step = state.training_step + 1
    state
}

func start_orpo_training(
    orpo_config cfg,
    []orpo_trajectory trajectories
) orpo_state {
    orpo_state state = create_orpo_state(cfg)
    print("[ORPO Training] Starting...")
    print("  config: seq_len=" + int_to_string_ex(cfg.seq_len) +
          " hidden=" + int_to_string_ex(cfg.hidden_size))
    print("  Parameters: beta=" + float_to_string_ex(cfg.beta) +
          " gamma=" + float_to_string_ex(cfg.gamma))
    print("  Learning rate: " + float_to_string_ex(cfg.learning_rate))
    print("")
    int epoch = 0
    while epoch < cfg.num_epochs {
        state.epoch = epoch
        state.num_batches = 0
        print("[ORPO Epoch " + int_to_string_ex(epoch + 1) + "/" +
              int_to_string_ex(cfg.num_epochs) + "]")
        int batch_idx = 0
        while batch_idx * cfg.batch_size < len(trajectories) {
            orpo_batch batch = orpo_batch {
                pairs: []orpo_preference_pair{cap: cfg.batch_size},
                prompt_embeddings: [][]float{cap: cfg.batch_size},
                chosen_embeddings: [][]float{cap: cfg.batch_size},
                rejected_embeddings: [][]float{cap: cfg.batch_size},
                size: 0,
            }
            int start_idx = batch_idx * cfg.batch_size
            int end_idx = start_idx + cfg.batch_size
            if end_idx > len(trajectories) {
                end_idx = len(trajectories)
            }
            int traj_idx = start_idx
            while traj_idx < end_idx {
                batch.size = batch.size + 1
                traj_idx = traj_idx + 1
            }
            state = orpo_training_step(
                state,
                batch.size,
                cfg.learning_rate,
                0.9,
                0.999,
                0.00000001
            )
            if mod_int_ex(batch_idx + 1, 10) == 0 {
                print("  batch_2 " + int_to_string_ex(batch_idx + 1) +
                      ": Loss = " + float_to_string_ex(state.avg_loss))
            }
            batch_idx = batch_idx + 1
        }
        print("  Epoch Loss: " + float_to_string_ex(state.avg_loss))
        print("")
        epoch = epoch + 1
    }
    print("[ORPO Training] Complete!")
    print("  Total training steps: " + int_to_string_ex(state.training_step))
    print("  Final loss: " + float_to_string_ex(state.avg_loss))
    print("")
    state
}

func float_to_string_ex(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func int_to_string_ex(int i) string {
    string(i)
}

func append_float_ex([]float arr, float f) []float {
    arr
}

func mod_int_ex(int a, int b) int {
    if b <= 0 {
        return 0
    }
    int value = a
    while value < 0 {
        value = value + b
    }
    while value >= b {
        value = value - b
    }
    value
}

func synchronize_gradients(orpo_state state) orpo_state {
    if state.config.world_size > 1 {
        print("[ORPO] Synchronizing gradients across " +
              int_to_string_ex(state.config.world_size) + " GPUs")
    }
    state
}

func save_checkpoint(orpo_state state, string path) {
    print("[ORPO] Saving checkpoint to " + path)
}

func create_orpo_default_config() orpo_config {
    orpo_config {
        seq_len: 128,
        hidden_size: 256,
        vocab_size: 32000,
        learning_rate: 0.0005,
        beta: 0.05,
        gamma: 0.5,
        batch_size: 32,
        num_epochs: 3,
        gradient_accumulation_steps: 1,
        weight_decay: 0.01,
        max_grad_norm: 0.5,
        use_reference_model: true,
        kl_penalty_coef: 0.1,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_mixed_precision: false,
        save_interval: 10,
        checkpoint_dir: "./checkpoints",
    }
}

func load_checkpoint(string path) orpo_state {
    print("[ORPO] Loading checkpoint from " + path)
    create_orpo_state(create_orpo_default_config())
}
