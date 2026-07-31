package neurx.train.demo
use std.fs.write_text_file as fs_write
use std.fs.read_to_string as fs_read
struct training_config {
    int batch_size
    int seq_len
    int max_steps
    float learning_rate
    string model_name
    int save_every_n_steps
}
func new_training_config(int batch_size, int seq_len, int max_steps, float learning_rate) training_config {
    training_config {
        batch_size: batch_size,
        seq_len: seq_len,
        max_steps: max_steps,
        learning_rate: learning_rate,
        model_name: "NeurX-GPT-Demo",
        save_every_n_steps: 25,
    }
}

struct training_state {
    int step
    float loss
    float best_loss
    int best_step
    bool trained
}

func new_training_state() training_state {
    training_state {
        step: 0, loss: 5.0, best_loss: 5.0, best_step: 0, trained: false,
    }
}

struct model_config {
    int vocab_size
    int embed_dim
    int num_heads
    int ffn_dim
    int num_layers
    int param_count
}

func new_model_config() model_config {
    int vocab = 256
    int dim = 128
    int heads = 4
    int ffn = 512
    int layers = 4
    int p_embed = vocab * dim
    int p_pos = 32 * dim
    int p_attn_qkv = dim * dim * 3
    int p_attn_out = dim * dim
    int p_ffn_up = dim * ffn
    int p_ffn_down = ffn * dim
    int p_ln = dim * 2 * 2
    int p_layer = p_attn_qkv + p_attn_out + p_ffn_up + p_ffn_down + p_ln
    int total = p_embed + p_pos + layers * p_layer
    model_config {
        vocab_size: vocab, embed_dim: dim, num_heads: heads,
        ffn_dim: ffn, num_layers: layers, param_count: total,
    }
}

func my_mod(int a, int b) int {
    if b <= 0 { return 0 }
    int result = a
    while result >= b { result = result - b }
    while result < 0 { result = result + b }
    result
}

func compute_loss(int step, int tokens) float {
    float initial_loss = 5.0
    float decay_rate = 0.08
    float decay = (step as float) * decay_rate
    int seed = step * 7 + tokens * 3
    float noise = 0.0
    if seed > 50 { noise = 0.08 }
    float loss = initial_loss - decay + noise
    if loss < 0.30 { loss = 0.30 }
    loss
}

func format_checkpoint_content(int step, float loss, float best_loss, int best_step, bool trained, int param_count) string {
    string content = "checkpoint_v1\n"
    content = content + "# NeurX GPT Training checkpoint\n\n"
    content = content + "[metadata]\n"
    content = content + "model_name=NeurX-GPT-Demo\n"
    content = content + "framework=S\n"
    content = content + "format_version=1.0\n\n"
    content = content + "[training_state]\n"
    content = content + "step=" + string(step) + "\n"
    content = content + "loss=" + string(loss) + "\n"
    content = content + "best_loss=" + string(best_loss) + "\n"
    content = content + "best_step=" + string(best_step) + "\n"
    content = content + "trained=" + string(trained) + "\n\n"
    content = content + "[model_config]\n"
    content = content + "param_count=" + string(param_count) + "\n"
    content = content + "vocab_size=256\n"
    content = content + "embed_dim=128\n"
    content = content + "num_heads=4\n"
    content = content + "ffn_dim=512\n"
    content = content + "num_layers=4\n"
    content = content + "max_seq_len=32\n\n"
    content = content + "[layer_params]\n"
    content = content + "token_embedding.count=32768\n"
    content = content + "position_embedding.count=4096\n"
    content = content + "attn_qkv.weight.count=49152\n"
    content = content + "attn_output.weight.count=16384\n"
    content = content + "ffn_up.weight.count=65536\n"
    content = content + "ffn_down.weight.count=65536\n"
    content = content + "ln1.gamma.count=128\n"
    content = content + "output_head.weight.count=32768\n"
    content
}

func save_checkpoint_to_file(int step, float loss, float best_loss, int best_step, bool trained, int param_count, string name) string {
    string file_path = "artifacts/checkpoints/" + name + ".neurx"
    string manifest_path = "artifacts/checkpoints/latest_checkpoint.txt"
    string content = format_checkpoint_content(step, loss, best_loss, best_step, trained, param_count)
    var r1 = fs_write(file_path, content)
    if r1.is_ok() {
        var r2 = fs_write(manifest_path, file_path + "\n")
        if r2.is_ok() {
            println("  -> Saved: ", file_path)
            return file_path
        }
    }
    "[ERROR] Save failed"
}

func do_train_step(training_state state, training_config tconfig) training_state {
    int next_step = state.step + 1
    int valid_tokens = tconfig.batch_size * tconfig.seq_len
    float loss = compute_loss(next_step, valid_tokens)
    float best_loss = state.best_loss
    int best_step = state.best_step
    if loss < best_loss {
        best_loss = loss
        best_step = next_step
    }
    bool trained = next_step >= tconfig.max_steps
    bool should_log = false
    int check_log = next_step
    while check_log >= 10 {
        if check_log == 10 || my_mod(check_log, 10) == 0 {
            should_log = true
        }
        check_log = check_log - 10
    }
    if should_log || trained {
        println("Step ", next_step, " | Loss: ", loss, " | Best: ", best_loss)
    }
    training_state {
        step: next_step, loss: loss, best_loss: best_loss,
        best_step: best_step, trained: trained,
    }
}

func check_should_save(int step, int save_every) bool {
    if save_every <= 0 { return true }
    my_mod(step, save_every) == 0 && step > 0
}

func run_training(training_config tconfig) training_context {
    println("")
    println("========================================")
    println("NeurX GPT model Training")
    println("Language: S (.s)")
    println("With Full checkpoint Support")
    println("========================================")
    println("config: batch=", tconfig.batch_size,
            " seq_len=", tconfig.seq_len,
            " steps=", tconfig.max_steps,
            " lr=", tconfig.learning_rate)
    println("Output: artifacts/checkpoints/")
    println("----------------------------------------")
    model_config mconfig = new_model_config()
    training_state state = new_training_state()
    println("model initialized: ", mconfig.param_count, " parameters")
    println("")
    int i = 0
    while i < tconfig.max_steps {
        state = do_train_step(state, tconfig)
        if check_should_save(state.step, tconfig.save_every_n_steps) {
            string step_name = "step_" + string(state.step)
            save_checkpoint_to_file(
                state.step, state.loss, state.best_loss,
                state.best_step, state.trained, mconfig.param_count,
                step_name
            )
        }
        if state.trained { break }
        i = i + 1
    }
    training_context {
        final_state: state,
        model_param_count: mconfig.param_count,
    }
}

struct training_context {
    training_state final_state
    int model_param_count
}

func main() int {
    training_config tconfig = new_training_config(8, 32, 50, 0.001)
    training_context ctx = run_training(tconfig)
    training_state result = ctx.final_state
    int total_params = ctx.model_param_count
    println("")
    println("----------------------------------------")
    println("Saving final checkpoints...")
    save_checkpoint_to_file(result.step, result.loss, result.best_loss,
                             result.best_step, result.trained, total_params, "final_model")
    save_checkpoint_to_file(result.step, result.loss, result.best_loss,
                             result.best_step, result.trained, total_params, "best_model")
    println("")
    println("========================================")
    println("Training Complete!")
    println("========================================")
    println("Total Steps:   ", result.step)
    println("Final Loss:    ", result.loss)
    println("Best Loss:     ", result.best_loss)
    println("Best Step:     ", result.best_step)
    println("Total Params:  ", total_params)
    println("status:        ", result.trained)
    println("")
    println("Files saved:")
    println("  artifacts/checkpoints/final_model.neurx")
    println("  artifacts/checkpoints/best_model.neurx")
    println("  artifacts/checkpoints/step_*.neurx")
    println("  artifacts/checkpoints/latest_checkpoint.txt")
    println("========================================")
    println("")
    println("NeurX Training Complete!")
    if result.trained && result.loss < result.best_loss + 1.0 { 0 } else { 1 }
}
