package neurx.train.v2
use std.tensor_core as T
use std.math_dl as M
use std.autograd as AG
use std.nn as NN
use std.training_io as IO
struct train_config {
    int vocab_size
    int embed_dim
    int num_heads
    int ffn_dim
    int num_layers
    int max_seq_len
    float learning_rate
    string optimizer
    float weight_decay
    float dropout_prob
    int batch_size
    int seq_len
    int max_steps
    int save_every
}

func default_config() train_config {
    train_config {
        vocab_size: 256, embed_dim: 128, num_heads: 4,
        ffn_dim: 512, num_layers: 4, max_seq_len: 32,
        learning_rate: 0.001, optimizer: "adam",
        weight_decay: 0.01, dropout_prob: 0.1,
        batch_size: 8, seq_len: 32, max_steps: 50,
        save_every: 25,
    }
}

func config_string(train_config cfg) string {
    string s = ""
    s = s + "=== NeurX GPT Training config ===\n"
    s = s + "model:\n"
    s = s + "  vocab_size=" + int_to_str(cfg.vocab_size) + "\n"
    s = s + "  embed_dim=" + int_to_str(cfg.embed_dim) + "\n"
    s = s + "  heads=" + int_to_str(cfg.num_heads) + " layers=" + int_to_str(cfg.num_layers) + "\n"
    s = s + "Training:\n"
    s = s + "  lr=" + M.fmt_float(cfg.learning_rate, 6) + " opt=" + cfg.optimizer + "\n"
    s = s + "  batch=" + int_to_str(cfg.batch_size) + " steps=" + int_to_str(cfg.max_steps) + "\n"
    s
}

func main() {
    println("")
    println("========================================")
    println("  NeurX GPT - S Language AI-Native Training")
    println("  All 5 Core DL Capabilities Integrated:")
    println("    [v] tensor_2 Core (N-dim, broadcast)")
    println("    [v] Math Library (80+ functions)")
    println("    [v] Autograd (auto differentiation)")
    println("    [v] NN Modules (Linear/GPT/Attention)")
    println("    [v] Training I/O (checkpoint v2)")
    println("========================================")
    println("")
    train_config cfg = default_config()
    println(config_string(cfg))
    println("[1/5] Building GPT model...")
    NN.gptconfig gpt_cfg
    gpt_cfg.vocab_size = cfg.vocab_size
    gpt_cfg.embed_dim = cfg.embed_dim
    gpt_cfg.num_heads = cfg.num_heads
    gpt_cfg.ffn_dim = cfg.ffn_dim
    gpt_cfg.num_layers = cfg.num_layers
    gpt_cfg.max_seq_len = cfg.max_seq_len
    gpt_cfg.dropout_prob = cfg.dropout_prob
    NN.gptmodel model = NN.make_gpt(gpt_cfg)
    NN.print_gpt_summary(model)
    int total_params = NN.gpt_total_params(model)
    println("[OK] model ready: ", format_int(total_params), " parameters")
    println("")
    println("[2/5] Setting up optimizer...")
    AG.optimizer_2 opt
    if cfg.optimizer == "adam" || cfg.optimizer == "adamw" {
        opt = AG.make_adam(cfg.learning_rate, 0.9, 0.999, cfg.weight_decay, 1e-8)
    } else {
        opt = AG.make_sgd(cfg.learning_rate, 0.9, cfg.weight_decay)
    }
    println("[OK] optimizer_2: ", cfg.optimizer, " lr=", M.fmt_float(opt.lr, 6))
    println("")
    println("[3/5] Preparing synthetic data...")
    int data_len = cfg.max_steps * cfg.batch_size * cfg.seq_len * 2
    []int train_data = generate_data(data_len, cfg.vocab_size)
    println("[OK] Generated ", format_int(data_len), " training tokens")
    println("")
    println("[4/5] Starting training loop...")
    println("")
    println("Step |  Loss   | Best    | GradNorm | LR       | Note")
    println("-----|---------|---------|----------|----------|-----")
    IO.TrainState state = IO.initial_train_state()
    string output_dir = "artifacts/checkpoints"
    int step = 0
    while step < cfg.max_steps {
        []int input_ids = get_batch(train_data, step, cfg.batch_size * cfg.seq_len)
        []int target_ids = get_batch(train_data, step + 1, cfg.batch_size * cfg.seq_len)
        AG.AGTensor logits = NN.forward(model, input_ids, cfg.batch_size, cfg.seq_len)
        []int targets = make_targets(target_ids, cfg.batch_size)
        AG.AGTensor loss_tensor = AG.ag_cross_entropy(logits, targets)
        float loss_val = AG.item(loss_tensor)
        state.global_step = state.global_step + 1
        if loss_val < state.best_loss {
            state.best_loss = loss_val
            state.best_step = step + 1
        }
        int wi = mod(step, len(state.loss_history))
        state.loss_history[wi] = loss_val
        AG.zero_grad(model.all_params)
        var grads = AG.backward(loss_tensor)
        float grad_norm = AG.clip_grad_norm_(model.all_params, 1.0)
        state.grad_norm = grad_norm
        if cfg.optimizer == "adam" { AG.adam_step(opt, model.all_params) }
        else { AG.sgd_step(opt, model.all_params) }
        bool should_log = (((step + 1) - ((step + 1) / 10) * 10) == 0 || step == cfg.max_steps - 1 || loss_val < state.best_loss)
        if should_log {
            string note = ""
            if loss_val < state.best_loss { note = "*NEW BEST*" }
            print_training_line(step + 1, loss_val, state.best_loss,
                               grad_norm, opt.lr, note)
            IO.log_entry(step + 1, loss_val, state.best_loss,
                        grad_norm, opt.lr, 0, note)
        }
        if should_save(step + 1, cfg.save_every) {
            var weights = AG.export_weights(model.all_params)
            NN.ModelConfigSnapshot snap = NN.make_config_snapshot(
                cfg.vocab_size, cfg.embed_dim, cfg.num_heads, cfg.ffn_dim,
                cfg.num_layers, cfg.max_seq_len, cfg.dropout_prob, total_params
            )
            string ckpt_path = IO.quick_save(output_dir, step + 1, loss_val,
                                             state.best_loss, state.best_step,
                                             snap, weights, state.loss_history)
            if len(ckpt_path) > 0 {
                IO.update_manifest(output_dir + "/latest_checkpoint.txt", ckpt_path)
            }
        }
        step = step + 1
    }
    println("")
    println("[5/5] Saving final checkpoints...")
    var final_weights = AG.export_weights(model.all_params)
    NN.ModelConfigSnapshot final_snap = NN.make_config_snapshot(
        cfg.vocab_size, cfg.embed_dim, cfg.num_heads, cfg.ffn_dim,
        cfg.num_layers, cfg.max_seq_len, cfg.dropout_prob, total_params
    )
    IO.quick_save(output_dir, cfg.max_steps, state.current_loss,
                  state.best_loss, state.best_step, final_snap,
                  final_weights, state.loss_history)
    IO.save_log(output_dir + "/training_log.tsv")
    println("")
    println("╔══════════════════════════════════════╗")
    println("║     Training Complete!               ║")
    println("╠══════════════════════════════════════╣")
    println("║ Steps:     ", pad_int(cfg.max_steps, 6), "                ║")
    println("║ Final:     ", pad_float(state.current_loss, 8, 6), "             ║")
    println("║ Best:      ", pad_float(state.best_loss, 8, 6), "             ║")
    println("║ Params:    ", format_int(total_params), "              ║")
    println("╚══════════════════════════════════════╝")
    println("")
    IO.print_log_summary()
    println("")
    println("Checkpoints saved to: " + output_dir + "/")
    println("")
    if state.current_loss < 2.0 {
    } else {
    }
}

func generate_data(int n_tokens, int vocab_size) []int {
    []int data = new int[n_tokens]
    []int pattern = [1, 23, 45, 67, 89, 12, 34, 56]
    int pattern_len = 8
    int seed = 42
    int i = 0
    while i < n_tokens {
        if mod(i, pattern_len * 3) < pattern_len {
            data[i] = pattern[mod(i, pattern_len)]
        } else {
            seed = seed * 1103515245 + 12345
            data[i] = mod(seed / 65536, vocab_size)
        }
        i = i + 1
    }
    data
}

func get_batch([]int data, int offset, int count) []int {
    []int batch = new int[count]
    int actual_offset = o(offset - (offset / (len(data) - count)) * (len(data) - count))
    int i = 0
    while i < count {
        batch[i] = data[actual_offset + i]
        i = i + 1
    }
    batch
}

func make_targets([]int token_ids, int batch_size) []int {
    []int targets = new int[batch_size]
    int i = 0
    while i < batch_size {
        targets[i] = token_ids[i]
        if targets[i] > 255 { targets[i] = t(targets[i] - (targets[i] / 256) * 256) }
        i = i + 1
    }
    targets
}

func should_save(int step, int every) bool {
    if every <= 0 { return true }
    int r = step - (step / every) * every
    r == 0  step > 0
}

func print_training_line(int step, float loss, float best, float gn, float lr, string note) void {
    string line = ""
    line = line + pad_int(step, 4) + " | "
    line = line + pad_float(loss, 7, 6) + " | "
    line = line + pad_float(best, 7, 6) + " | "
    line = line + pad_float(gn, 6, 4) + " | "
    line = line + pad_float(lr, 7, 8) + " | "
    line = line + note
    println(line)
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    bool neg = n < 0
    if neg { n = -n }
    string s = ""
    while n > 0 {
        s = string((n * (n - (n / 10) * 10)) + 48) + s
        n = n / 10
    }
    if neg { s = "-" + s }
    s
}

func format_int(int n) string {
    if n == 0 { return "0" }
    bool neg = n < 0
    if neg { n = -n }
    string s = ""
    int count = 0
    while n > 0 {
        int digit = n - (n / 10) * 10
        s = string(digit + 48) + s
        n = n / 10
        count = count + 1
        if count - (count / 3) * 3 == 0 && n > 0 {
            s = "," + s
        }
    }
    if neg { s = "-" + s }
    s
}

func pad_float(float val, int w, int d) string {
    string s = M.fmt_float(val, d)
    while len(s) < w { s = " " + s }
    s
}

func pad_int(int n, int w) string {
    string s = int_to_str(n)
    while len(s) < w { s = " " + s }
    s
}

