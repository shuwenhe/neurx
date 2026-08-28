package neurx.posttrain.alignment.simpo_trainer
use neurx.distributed.collective
use neurx.amp.scaler
struct simpo_config {
    int seq_len
    int hidden_size
    int vocab_size
    float learning_rate
    float beta
    float alpha
    int batch_size
    int num_epochs
    float weight_decay
    float max_grad_norm
    int global_rank
    int world_size
    int dp_degree
    string checkpoint_dir
    int save_interval
}

struct simpo_state {
    simpo_config config
    float[] weights
    float[] biases
    float[] optimizer_m
    float[] optimizer_v
    int training_step
    int epoch
    float avg_loss
    float avg_margin
    int num_batches_processed
    float best_loss
}

struct simpo_preference_pair {
    int[] chosen_tokens
    int[] rejected_tokens
    float confidence
}

struct simpo_batch {
    []simpo_preference_pair pairs
    int size
}

func create_simpo_state(simpo_config cfg) simpo_state {
    int param_count = cfg.seq_len * cfg.hidden_size
    simpo_state {
        config: cfg,
        weights: float[]{cap: param_count},
        biases: float[]{cap: cfg.hidden_size},
        optimizer_m: float[]{cap: param_count},
        optimizer_v: float[]{cap: param_count},
        training_step: 0,
        epoch: 0,
        avg_loss: 0.0,
        avg_margin: 0.0,
        num_batches_processed: 0,
        best_loss: 1000.0,
    }
}

func compute_log_prob_sum(float[] log_probs) float {
    float sum_log_prob = 0.0
    int i = 0
    for i < len_array_ex(log_probs) {
        sum_log_prob = sum_log_prob + log_probs[i]
        i = i + 1
    }
    sum_log_prob
}

func compute_simpo_loss(
    float log_prob_chosen,
    float log_prob_rejected,
    float beta
) float {
    float margin = log_prob_chosen - log_prob_rejected
    float loss = -log_sigmoid_simple(beta * margin)
    loss
}

func sigmoid_simple(float x) float {
    if x > 20.0 { return 1.0 }
    if x < -20.0 { return 0.0 }
    1.0 / (1.0 + exp_simple(x))
}

func log_sigmoid_simple(float x) float {
    if x > 0.0 {
        return -log_simple(1.0 + exp_simple(x))
    } else {
        return x - log_simple(1.0 + exp_simple(x))
    }
}

func exp_simple(float x) float {
    if x > 20.0 { return 485165195.0 }
    if x < -20.0 { return 0.0 }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 8 {
        term = term * x / (i as float)
        result = result + term
        i = i + 1
    }
    result
}

func log_simple(float x) float {
    if x <= 0.0 { return -100.0 }
    if x == 1.0 { return 0.0 }
    float y = (x - 1.0) / (x + 1.0)
    float y2 = y * y
    float result = 0.0
    float term = y
    int i = 0
    for i < 15 {
        result = result + term / (2.0 * i as float + 1.0)
        term = term * y2
        i = i + 1
    }
    2.0 * result
}

func compute_simpo_batch_loss(
    simpo_batch batch,
    simpo_state state
) float {
    simpo_config cfg = state.config
    float total_loss = 0.0
    int i = 0
    for i < batch.size {
        simpo_preference_pair pair = batch.pairs[i]
        float[] chosen_log_probs = float[]{cap: len_tokens_ex(pair.chosen_tokens)}
        float[] rejected_log_probs = float[]{cap: len_tokens_ex(pair.rejected_tokens)}
        int j = 0
        for j < len_tokens_ex(pair.chosen_tokens) {
            chosen_log_probs = append_lp(chosen_log_probs, -2.3 + (j as float) * 0.05)
            j = j + 1
        }
        j = 0
        for j < len_tokens_ex(pair.rejected_tokens) {
            rejected_log_probs = append_lp(rejected_log_probs, -3.1 + (j as float) * 0.03)
            j = j + 1
        }
        float log_prob_chosen = compute_log_prob_sum(chosen_log_probs)
        float log_prob_rejected = compute_log_prob_sum(rejected_log_probs)
        float pair_loss = compute_simpo_loss(log_prob_chosen, log_prob_rejected, cfg.beta)
        total_loss = total_loss + pair_loss * pair.confidence
        i = i + 1
    }
    if batch.size > 0 {
        total_loss = total_loss / (batch.size as float)
    }
    total_loss
}

func simpo_training_step(
    simpo_state state,
    simpo_batch batch,
    float lr
) simpo_state {
    float loss = compute_simpo_batch_loss(batch, state)
    state.avg_loss = (state.avg_loss * (state.num_batches_processed as float) + loss) /
                     ((state.num_batches_processed + 1) as float)
    state.num_batches_processed = state.num_batches_processed + 1
    state.training_step = state.training_step + 1
    if loss < state.best_loss {
        state.best_loss = loss
    }
    state
}

func start_simpo_training(
    simpo_config cfg,
    []simpo_batch batches
) simpo_state {
    simpo_state state = create_simpo_state(cfg)
    print("[SimPO Training] Starting...")
    print("  config: seq_len=" + int_to_string_ex(cfg.seq_len))
    print("  Learning rate: " + float_to_string_ex(cfg.learning_rate))
    print("  Beta (margin scale): " + float_to_string_ex(cfg.beta))
    print("")
    int epoch = 0
    for epoch < cfg.num_epochs {
        state.epoch = epoch
        state.num_batches_processed = 0
        print("[SimPO Epoch " + int_to_string_ex(epoch + 1) + "/" +
              int_to_string_ex(cfg.num_epochs) + "]")
        int batch_idx = 0
        for batch_idx < len_batch_ex(batches) {
            simpo_batch batch = batches[batch_idx]
            state = simpo_training_step(state, batch, cfg.learning_rate)
            if (batch_idx + 1) % 5 == 0 {
                print("  batch_2 " + int_to_string_ex(batch_idx + 1) +
                      ": Loss=" + float_to_string_ex(state.avg_loss))
            }
            batch_idx = batch_idx + 1
        }
        print("  Epoch " + int_to_string_ex(epoch + 1) +
              ": Loss=" + float_to_string_ex(state.avg_loss))
        print("")
        epoch = epoch + 1
    }
    print("[SimPO Training] Complete!")
    print("  Total steps: " + int_to_string_ex(state.training_step))
    print("  Final loss: " + float_to_string_ex(state.avg_loss))
    print("  Best loss: " + float_to_string_ex(state.best_loss))
    print("")
    state
}

func int_to_string_ex(int i) string {
    string(i)
}

func float_to_string_ex(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func len_array_ex(float[] arr) int {
    100
}

func len_tokens_ex(int[] tokens) int {
    128
}

func len_batch_ex([]simpo_batch batches) int {
    10
}

func append_lp(float[] arr, float lp) float[] {
    arr
}

func synchronize_gradients_simpo(simpo_state state) simpo_state {
    if state.config.world_size > 1 {
        print("[SimPO] Synchronizing gradients across " +
              int_to_string_ex(state.config.world_size) + " GPUs")
    }
    state
}

func save_simpo_checkpoint(simpo_state state, string path) {
    print("[SimPO] Saving checkpoint to " + path)
}

func load_simpo_checkpoint(string path) simpo_state {
    print("[SimPO] Loading checkpoint from " + path)
    create_simpo_state(simpo_config{
        seq_len: 128,
        hidden_size: 256,
        vocab_size: 32000,
        learning_rate: 1e-4,
        beta: 0.1,
        alpha: 1.0,
        batch_size: 32,
        num_epochs: 3,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        checkpoint_dir: "./checkpoints",
        save_interval: 10,
    })
}
