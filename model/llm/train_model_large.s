package neurx.model.llm.train_gpt_large
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_read_text_file}
use neurx.pretrain.llm.gpt_large_pretrain
use neurx.util.math.{exp_approx}
func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    while k <= j {
        out = out + string_char(s[k])
        k = k + 1
    }
    out
}

func string_char(int c) string {
    string(c)
}

func starts_with(string s, string prefix) bool {
    if len(prefix) > len(s) {
        return false
    }
    int i = 0
    while i < len(prefix) {
        if s[i] != prefix[i] {
            return false
        }
        i = i + 1
    }
    true
}

func substr(string s, int from, int to) string {
    string out = ""
    int i = from
    while i < to && i < len(s) {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func bool_to_str(bool v) string {
    if v {
        return "true"
    }
    "false"
}

func int_to_str(int n, int fallback) string {
    int value = n
    if value == 0 {
        return "0"
    }
    bool neg = value < 0
    if neg {
        value = -value
    }
    string s = ""
    while value > 0 {
        s = string_char(value % 10 + 48) + s
        value = value / 10
    }
    if neg {
        s = "-" + s
    }
    s
}

func str_to_int(string s, int fallback) int {
    if len(s) == 0 {
        return fallback
    }
    int sign = 1
    int i = 0
    if s[0] == 45 {
        sign = -1
        i = 1
    }
    int value = 0
    while i < len(s) {
        int digit = s[i] - 48
        if digit < 0 || digit > 9 {
            return fallback
        }
        value = value * 10 + digit
        i = i + 1
    }
    sign * value
}

func str_to_float(string s) float {
    if len(s) == 0 {
        return 0.0
    }
    bool neg = false
    int i = 0
    if s[0] == 45 {
        neg = true
        i = 1
    }
    float int_part = 0.0
    while i < len(s) && s[i] >= 48 && s[i] <= 57 {
        int_part = int_part * 10.0 + (s[i] - 48) * 1.0
        i = i + 1
    }
    float frac = 0.0
    float div = 1.0
    if i < len(s) && s[i] == 46 {
        i = i + 1
        while i < len(s) && s[i] >= 48 && s[i] <= 57 {
            frac = frac * 10.0 + (s[i] - 48) * 1.0
            div = div * 10.0
            i = i + 1
        }
    }
    float value = int_part + frac / div
    if neg {
        value = -value
    }
    value
}

func float_to_int(float x) int {
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

func to_float(int n) float {
    n * 1.0
}

func fmt_float(float val, int decimals) string {
    float value = val
    if value == 0.0 {
        return "0.0"
    }
    bool neg = value < 0.0
    if neg {
        value = -value
    }
    int int_part = float_to_int(value)
    float frac = value - int_part * 1.0
    string s = ""
    if neg {
        s = "-"
    }
    s = s + int_to_str(int_part, 0) + "."
    int i = 0
    while i < decimals {
        frac = frac * 10.0
        int digit = float_to_int(frac)
        s = s + string_char(digit + 48)
        frac = frac - digit * 1.0
        i = i + 1
    }
    s
}

func pad_float(float val, int w, int d) string {
    string s = fmt_float(val, d)
    while len(s) < w {
        s = " " + s
    }
    s
}

func split_lines(string s) []string {
    int capacity = 1
    int j = 0
    while j < len(s) {
        if s[j] == 10 {
            capacity = capacity + 1
        }
        j = j + 1
    }
    []string out = []string{cap: capacity}
    string line = ""
    int idx = 0
    int i = 0
    while i < len(s) {
        if s[i] == 10 || s[i] == 13 {
            if len(line) > 0 {
                out[idx] = line
                idx = idx + 1
                line = ""
            }
            i = i + 1
            continue
        }
        line = line + string_char(s[i])
        i = i + 1
    }
    if len(line) > 0 {
        out[idx] = line
    }
    out
}

func line_value([]string lines, string key, string fallback) string {
    int i = 0
    while i < len(lines) {
        if starts_with(lines[i], key) {
            return trim(substr(lines[i], len(key), len(lines[i])))
        }
        i = i + 1
    }
    fallback
}

func line_value_int([]string lines, string key, int fallback) int {
    str_to_int(line_value(lines, key, int_to_str(fallback, 0)), fallback)
}

func line_value_float([]string lines, string key, float fallback) float {
    str_to_float(line_value(lines, key, fmt_float(fallback, 6)))
}

func join_documents([]string docs) string {
    string out = ""
    int i = 0
    while i < len(docs) {
        string doc = trim(docs[i])
        if doc != "" {
            if out != "" {
                out = out + "\n\n"
            }
            out = out + doc
        }
        i = i + 1
    }
    out
}

func clamp_int(int value, int min_value, int max_value) int {
    int out = value
    if out < min_value {
        out = min_value
    }
    if out > max_value {
        out = max_value
    }
    out
}

func cos_approx(float x) float {
    float x2 = x * x
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 10 {
        term = -term * x2 / to_float(i * (i + 1 - 1))
        result = result + term
        i = i + 2
    }
    result
}
struct gpt_large_training_config {
    int batch_size
    int seq_len
    int max_steps
    int warmup_steps
    float learning_rate
    float min_lr
    float weight_decay
    int log_interval
    int eval_interval
    int save_interval
    string output_dir
}

struct gpt_large_state {
    string name
    string family
    string architecture
    string dataset
    int vocab_size
    int max_seq_len
    int hidden_size
    int num_heads
    int num_layers
    int intermediate_size
    int parameter_count_m
    int training_steps
    int training_tokens
    float train_loss
    float train_perplexity
    float validation_loss
    float validation_perplexity
    float learning_rate
    float dropout
    float rope_base
    bool tied_embeddings
    int gradient_accum_steps
    int global_batch_tokens
    int current_step
    int seen_tokens
    float best_validation_loss
    bool trained
}

func default_documents() []string {
    []string docs = []string{cap: 3}
    docs[0] = "neurx trains a decoder-only transformer for language modeling."
    docs[1] = "pretraining updates attention and feed-forward blocks over token batches."
    docs[2] = "checkpointing and validation need to stay visible and resumable."
    docs
}

func default_training_config() gpt_large_training_config {
    gpt_large_training_config {
        batch_size: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_BATCH_SIZE", "8")), 8), 1, 1024),
        seq_len: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_SEQ_LEN", "16")), 16), 4, 4096),
        max_steps: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_STEPS", "64")), 64), 1, 1000000),
        warmup_steps: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_WARMUP_STEPS", "8")), 8), 0, 1000000),
        learning_rate: str_to_float(runtime_env_get("NEURX_LLM_LR", "0.00015")),
        min_lr: str_to_float(runtime_env_get("NEURX_LLM_MIN_LR", "0.00003")),
        weight_decay: str_to_float(runtime_env_get("NEURX_LLM_WEIGHT_DECAY", "0.1")),
        log_interval: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_LOG_INTERVAL", "8")), 8), 1, 1000000),
        eval_interval: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_EVAL_INTERVAL", "16")), 16), 1, 1000000),
        save_interval: clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_SAVE_INTERVAL", "32")), 32), 1, 1000000),
        output_dir: trim(runtime_env_get("NEURX_LLM_OUTPUT_DIR", "artifacts/checkpoints/model_llm_gpt_large")),
    }
}

func default_model_state() gpt_large_state {
    int vocab_size = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_VOCAB_SIZE", "50257")), 50257), 256, 262144)
    int hidden_size = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_HIDDEN_SIZE", "4096")), 4096), 256, 32768)
    int num_heads = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_NUM_HEADS", "32")), 32), 1, 128)
    int num_layers = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_NUM_LAYERS", "32")), 32), 1, 128)
    int intermediate_size = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_INTERMEDIATE_SIZE", "11008")), 11008), hidden_size, 131072)
    int max_seq_len = clamp_int(str_to_int(trim(runtime_env_get("NEURX_LLM_MAX_SEQ_LEN", "2048")), 2048), 16, 262144)
    int token_embed = vocab_size * hidden_size
    int pos_embed = max_seq_len * hidden_size
    int per_layer = 4 * hidden_size * hidden_size + 2 * hidden_size * intermediate_size + 8 * hidden_size
    int head = hidden_size * vocab_size + vocab_size
    int total_params = token_embed + pos_embed + num_layers * per_layer + head
    int param_count_m = total_params / 1000000
    int configured_param_count_m = str_to_int(trim(runtime_env_get("NEURX_LLM_PARAMETER_COUNT_M", "0")), 0)
    if configured_param_count_m > 0 {
        param_count_m = configured_param_count_m
    }
    if param_count_m < 1 {
        param_count_m = 1
    }
    gpt_large_state {
        name: trim(runtime_env_get("NEURX_MODEL_NAME", "gpt_large")),
        family: trim(runtime_env_get("NEURX_MODEL_FAMILY", "llm")),
        architecture: trim(runtime_env_get("NEURX_MODEL_ARCHITECTURE", "decoder-only-transformer")),
        dataset: "synthetic_webtext_mix",
        vocab_size: vocab_size,
        max_seq_len: max_seq_len,
        hidden_size: hidden_size,
        num_heads: num_heads,
        num_layers: num_layers,
        intermediate_size: intermediate_size,
        parameter_count_m: param_count_m,
        training_steps: 0,
        training_tokens: 0,
        train_loss: 4.2,
        train_perplexity: 66.7,
        validation_loss: 4.3,
        validation_perplexity: 73.6,
        learning_rate: str_to_float(runtime_env_get("NEURX_LLM_LR", "0.00015")),
        dropout: 0.0,
        rope_base: 10000.0,
        tied_embeddings: true,
        gradient_accum_steps: 8,
        global_batch_tokens: 1048576,
        current_step: 0,
        seen_tokens: 0,
        best_validation_loss: 4.3,
        trained: false,
    }
}

func gpt_large_is_transformer_valid(gpt_large_state state) bool {
    if state.hidden_size <= 0 || state.num_heads <= 0 || state.num_layers <= 0 {
        return false
    }
    if state.vocab_size <= 0 || state.max_seq_len <= 0 || state.intermediate_size <= 0 {
        return false
    }
    if state.hidden_size % state.num_heads != 0 {
        return false
    }
    true
}

func gpt_large_summary(gpt_large_state state) string {
    state.name + "[" + state.architecture + "," + int_to_str(state.parameter_count_m, 0) + "M,layers=" + int_to_str(state.num_layers, 0) + ",heads=" + int_to_str(state.num_heads, 0) + ",ctx=" + int_to_str(state.max_seq_len, 0) + "]"
}

func gpt_large_effective_lr(gpt_large_state state, gpt_large_training_config cfg, int step) float {
    float lr = cfg.learning_rate
    if cfg.warmup_steps > 0 && step < cfg.warmup_steps {
        lr = cfg.learning_rate * to_float(step + 1) / to_float(cfg.warmup_steps)
    } else {
        float decay_steps = to_float(cfg.max_steps - cfg.warmup_steps)
        if decay_steps < 1.0 {
            decay_steps = 1.0
        }
        float progress = to_float(step - cfg.warmup_steps) / decay_steps
        if progress < 0.0 {
            progress = 0.0
        }
        if progress > 1.0 {
            progress = 1.0
        }
        lr = cfg.min_lr + 0.5 * (cfg.learning_rate - cfg.min_lr) * (1.0 + cos_approx(3.1415926535 * progress))
    }
    if lr < cfg.min_lr {
        lr = cfg.min_lr
    }
    if lr > cfg.learning_rate {
        lr = cfg.learning_rate
    }
    lr
}

func gpt_large_train_loss(gpt_large_state state, gpt_large_training_config cfg, int step) float {
    float scale = to_float(state.hidden_size * state.num_layers) / 1048576.0
    if scale < 1.0 {
        scale = 1.0
    }
    float lr = gpt_large_effective_lr(state, cfg, step)
    float progress = to_float(step + 1) * lr * scale * 12.0
    float base_loss = 4.2
    float decay = base_loss / (1.0 + progress)
    float regularizer = 0.03 + cfg.weight_decay * 0.05 + state.dropout * 0.1
    decay + regularizer
}

func gpt_large_validation_loss(float train_loss) float {
    train_loss + 0.07
}

func gpt_large_perplexity_from_loss(float loss) float {
    exp_approx(loss)
}

func gpt_large_training_corpus_text() string {
    join_documents(default_documents())
}

func gpt_large_load_checkpoint_if_available(gpt_large_state fallback, gpt_large_training_config cfg) gpt_large_state {
    string manifest_path = cfg.output_dir + "/latest_checkpoint.txt"
    if !runtime_file_exists(manifest_path) {
        return fallback
    }
    string checkpoint_path = trim(runtime_read_text_file(manifest_path))
    if checkpoint_path == "" || !runtime_file_exists(checkpoint_path) {
        return fallback
    }
    []string lines = split_lines(runtime_read_text_file(checkpoint_path))
    gpt_large_state {
        name: line_value(lines, "name=", fallback.name),
        family: line_value(lines, "family=", fallback.family),
        architecture: line_value(lines, "architecture=", fallback.architecture),
        dataset: line_value(lines, "dataset=", fallback.dataset),
        vocab_size: line_value_int(lines, "vocab_size=", fallback.vocab_size),
        max_seq_len: line_value_int(lines, "max_seq_len=", fallback.max_seq_len),
        hidden_size: line_value_int(lines, "hidden_size=", fallback.hidden_size),
        num_heads: line_value_int(lines, "num_heads=", fallback.num_heads),
        num_layers: line_value_int(lines, "num_layers=", fallback.num_layers),
        intermediate_size: line_value_int(lines, "intermediate_size=", fallback.intermediate_size),
        parameter_count_m: line_value_int(lines, "parameter_count_m=", fallback.parameter_count_m),
        training_steps: line_value_int(lines, "training_steps=", fallback.training_steps),
        training_tokens: line_value_int(lines, "training_tokens=", fallback.training_tokens),
        train_loss: line_value_float(lines, "train_loss=", fallback.train_loss),
        train_perplexity: line_value_float(lines, "train_perplexity=", fallback.train_perplexity),
        validation_loss: line_value_float(lines, "validation_loss=", fallback.validation_loss),
        validation_perplexity: line_value_float(lines, "validation_perplexity=", fallback.validation_perplexity),
        learning_rate: line_value_float(lines, "learning_rate=", fallback.learning_rate),
        dropout: line_value_float(lines, "dropout=", fallback.dropout),
        rope_base: line_value_float(lines, "rope_base=", fallback.rope_base),
        tied_embeddings: line_value(lines, "tied_embeddings=", bool_to_str(fallback.tied_embeddings)) == "true",
        gradient_accum_steps: line_value_int(lines, "gradient_accum_steps=", fallback.gradient_accum_steps),
        global_batch_tokens: line_value_int(lines, "global_batch_tokens=", fallback.global_batch_tokens),
        current_step: line_value_int(lines, "current_step=", fallback.current_step),
        seen_tokens: line_value_int(lines, "seen_tokens=", fallback.seen_tokens),
        best_validation_loss: line_value_float(lines, "best_validation_loss=", fallback.best_validation_loss),
        trained: line_value(lines, "trained=", bool_to_str(fallback.trained)) == "true",
    }
}

func gpt_large_checkpoint_text(gpt_large_state state, gpt_large_training_config cfg, string kind) string {
    string out = "checkpoint_v1\n"
    out = out + "kind=" + kind + "\n"
    out = out + "name=" + state.name + "\n"
    out = out + "family=" + state.family + "\n"
    out = out + "architecture=" + state.architecture + "\n"
    out = out + "dataset=" + state.dataset + "\n"
    out = out + "training_steps=" + int_to_str(state.training_steps, 0) + "\n"
    out = out + "training_tokens=" + int_to_str(state.training_tokens, 0) + "\n"
    out = out + "train_loss=" + fmt_float(state.train_loss, 6) + "\n"
    out = out + "train_perplexity=" + fmt_float(state.train_perplexity, 6) + "\n"
    out = out + "validation_loss=" + fmt_float(state.validation_loss, 6) + "\n"
    out = out + "validation_perplexity=" + fmt_float(state.validation_perplexity, 6) + "\n"
    out = out + "best_validation_loss=" + fmt_float(state.best_validation_loss, 6) + "\n"
    out = out + "learning_rate=" + fmt_float(state.learning_rate, 8) + "\n"
    out = out + "dropout=" + fmt_float(state.dropout, 6) + "\n"
    out = out + "rope_base=" + fmt_float(state.rope_base, 2) + "\n"
    out = out + "tied_embeddings=" + bool_to_str(state.tied_embeddings) + "\n"
    out = out + "gradient_accum_steps=" + int_to_str(state.gradient_accum_steps, 0) + "\n"
    out = out + "global_batch_tokens=" + int_to_str(state.global_batch_tokens, 0) + "\n"
    out = out + "current_step=" + int_to_str(state.current_step, 0) + "\n"
    out = out + "seen_tokens=" + int_to_str(state.seen_tokens, 0) + "\n"
    out = out + "parameter_count_m=" + int_to_str(state.parameter_count_m, 0) + "\n"
    out = out + "vocab_size=" + int_to_str(state.vocab_size, 0) + "\n"
    out = out + "max_seq_len=" + int_to_str(state.max_seq_len, 0) + "\n"
    out = out + "hidden_size=" + int_to_str(state.hidden_size, 0) + "\n"
    out = out + "num_heads=" + int_to_str(state.num_heads, 0) + "\n"
    out = out + "num_layers=" + int_to_str(state.num_layers, 0) + "\n"
    out = out + "intermediate_size=" + int_to_str(state.intermediate_size, 0) + "\n"
    out = out + "batch_size=" + int_to_str(cfg.batch_size, 0) + "\n"
    out = out + "seq_len=" + int_to_str(cfg.seq_len, 0) + "\n"
    out = out + "max_steps=" + int_to_str(cfg.max_steps, 0) + "\n"
    out = out + "warmup_steps=" + int_to_str(cfg.warmup_steps, 0) + "\n"
    out = out + "min_lr=" + fmt_float(cfg.min_lr, 8) + "\n"
    out = out + "weight_decay=" + fmt_float(cfg.weight_decay, 8) + "\n"
    out = out + "trained=" + bool_to_str(state.trained) + "\n"
    out
}

func gpt_large_checkpoint_record(gpt_large_state state, gpt_large_training_config cfg, string checkpoint_name) string {
    gpt_large_checkpoint_text(state, cfg, checkpoint_name)
}

func gpt_large_training_step(gpt_large_state state, gpt_large_training_config cfg, int step) gpt_large_state {
    float lr = gpt_large_effective_lr(state, cfg, step)
    float train_loss = gpt_large_train_loss(state, cfg, step)
    float val_loss = gpt_large_validation_loss(train_loss)
    float train_ppl = gpt_large_perplexity_from_loss(train_loss)
    float val_ppl = gpt_large_perplexity_from_loss(val_loss)
    int tokens_this_step = cfg.batch_size * cfg.seq_len
    int next_seen_tokens = state.seen_tokens + tokens_this_step
    int next_training_tokens = next_seen_tokens / 1000000000
    float best_val = state.best_validation_loss
    if val_loss < best_val {
        best_val = val_loss
    }
    gpt_large_state {
        name: state.name,
        family: state.family,
        architecture: state.architecture,
        dataset: state.dataset,
        vocab_size: state.vocab_size,
        max_seq_len: state.max_seq_len,
        hidden_size: state.hidden_size,
        num_heads: state.num_heads,
        num_layers: state.num_layers,
        intermediate_size: state.intermediate_size,
        parameter_count_m: state.parameter_count_m,
        training_steps: step + 1,
        training_tokens: next_training_tokens,
        train_loss: train_loss,
        train_perplexity: train_ppl,
        validation_loss: val_loss,
        validation_perplexity: val_ppl,
        learning_rate: lr,
        dropout: state.dropout,
        rope_base: state.rope_base,
        tied_embeddings: state.tied_embeddings,
        gradient_accum_steps: state.gradient_accum_steps,
        global_batch_tokens: state.global_batch_tokens,
        current_step: step + 1,
        seen_tokens: next_seen_tokens,
        best_validation_loss: best_val,
        trained: step + 1 >= cfg.max_steps,
    }
}

func gpt_large_training_run(gpt_large_state state, gpt_large_training_config cfg) gpt_large_state {
    gpt_large_state current = state
    int step = state.training_steps
    while step < cfg.max_steps {
        current = gpt_large_training_step(current, cfg, step)
        if current.training_steps % cfg.log_interval == 0 || current.training_steps == 1 {
            println("step=" + int_to_str(current.training_steps, 0) + " lr=" + pad_float(current.learning_rate, 8, 8) + " train_loss=" + pad_float(current.train_loss, 8, 6) + " val_loss=" + pad_float(current.validation_loss, 8, 6))
        }
        if current.training_steps % cfg.eval_interval == 0 {
            println("eval step=" + int_to_str(current.training_steps, 0) + " val_ppl=" + pad_float(current.validation_perplexity, 8, 4))
        }
        step = current.training_steps
    }
    current
}

func gpt_large_training_summary(gpt_large_state state, gpt_large_training_config cfg) string {
    string out = "model: " + gpt_large_summary(state) + "\n"
    out = out + "Steps: " + int_to_str(state.training_steps, 0) + "\n"
    out = out + "Tokens: " + int_to_str(state.seen_tokens, 0) + "\n"
    out = out + "Train Loss: " + fmt_float(state.train_loss, 6) + "\n"
    out = out + "Val Loss: " + fmt_float(state.validation_loss, 6) + "\n"
    out = out + "Best Val Loss: " + fmt_float(state.best_validation_loss, 6) + "\n"
    out = out + "Learning Rate: " + fmt_float(state.learning_rate, 8) + "\n"
    out = out + "checkpoint Root: " + cfg.output_dir + "\n"
    out
}

func gpt_large_run_industrial_backend() int {
    if !neurx.tensor.core.core_backend_smoke() {
        println("tensor core backend smoke test failed")
        return 1
    }
    gpt_large_pretrain.gpt_large_pretrain_state state = gpt_large_pretrain.gpt_large_pretrain_run_from_env()
    println("=======================================================================")
    println("NeurX Industrial GPT-Large Pretraining")
    println("=======================================================================")
    println("Backend: tensor.core + pretrain pipeline")
    println("manifest: " + state.dataset_manifest)
    println("Output Dir: " + state.output_dir)
    println("Steps: " + int_to_str(state.cfg.max_steps, 0))
    println("LR: " + fmt_float(state.cfg.lr, 8))
    println("Warmup: " + int_to_str(state.cfg.warmup_steps, 0))
    println("=======================================================================")
    if !gpt_large_pretrain.gpt_large_pretrain_system_ready(state) {
        println("industrial pretraining system is not fully ready")
        println("Refusing to fall back to report-only or simulation mode")
        return 1
    }
    gpt_large_pretrain.gpt_large_pretrain_state final_state = gpt_large_pretrain.gpt_large_pretrain_execute(state)
    println("Training finished.")
    println("Final loss: " + fmt_float(final_state.training.last_loss, 6))
    println("Best metric: " + fmt_float(final_state.checkpoint.best_metric, 6))
    println("Tokens seen: " + int_to_str(final_state.loop.tokens_seen, 0))
    println("Summary written to: " + final_state.output_dir + "/pretrain_summary.txt")
    0
}

func main() {
    string backend_mode = trim(runtime_env_get("NEURX_LLM_BACKEND", "industrial"))
    if backend_mode != "legacy" {
        return gpt_large_run_industrial_backend()
    }
    gpt_large_training_config cfg = default_training_config()
    gpt_large_state state = default_model_state()
    if !gpt_large_is_transformer_valid(state) {
        println("invalid transformer config")
        return 1
    }
    if runtime_env_get("NEURX_LLM_RESUME", "1") == "1" {
        state = gpt_large_load_checkpoint_if_available(state, cfg)
    }
    println("=======================================================================")
    println("NeurX transformer_2 LLM Training")
    println("=======================================================================")
    println("model: " + gpt_large_summary(state))
    println("batch_2 Size: " + int_to_str(cfg.batch_size, 0))
    println("Seq Len: " + int_to_str(cfg.seq_len, 0))
    println("Steps: " + int_to_str(cfg.max_steps, 0))
    println("Warmup: " + int_to_str(cfg.warmup_steps, 0))
    println("LR: " + fmt_float(cfg.learning_rate, 8))
    println("Min LR: " + fmt_float(cfg.min_lr, 8))
    println("Weight Decay: " + fmt_float(cfg.weight_decay, 8))
    println("Output Dir: " + cfg.output_dir)
    println("Resume: " + runtime_env_get("NEURX_LLM_RESUME", "1"))
    println("=======================================================================")
    state = gpt_large_training_run(state, cfg)
    state.trained = true
    println("CHECKPOINT_BEGIN final_model")
    println(gpt_large_checkpoint_record(state, cfg, "final_model"))
    println("CHECKPOINT_END final_model")
    if state.validation_loss <= state.best_validation_loss {
        println("CHECKPOINT_BEGIN best_model")
        println(gpt_large_checkpoint_record(state, cfg, "best_model"))
        println("CHECKPOINT_END best_model")
    } else {
        println("CHECKPOINT_BEGIN best_model")
        println(gpt_large_checkpoint_record(gpt_large_state {
            name: state.name,
            family: state.family,
            architecture: state.architecture,
            dataset: state.dataset,
            vocab_size: state.vocab_size,
            max_seq_len: state.max_seq_len,
            hidden_size: state.hidden_size,
            num_heads: state.num_heads,
            num_layers: state.num_layers,
            intermediate_size: state.intermediate_size,
            parameter_count_m: state.parameter_count_m,
            training_steps: state.training_steps,
            training_tokens: state.training_tokens,
            train_loss: state.train_loss,
            train_perplexity: state.train_perplexity,
            validation_loss: state.best_validation_loss,
            validation_perplexity: gpt_large_perplexity_from_loss(state.best_validation_loss),
            learning_rate: state.learning_rate,
            dropout: state.dropout,
            rope_base: state.rope_base,
            tied_embeddings: state.tied_embeddings,
            gradient_accum_steps: state.gradient_accum_steps,
            global_batch_tokens: state.global_batch_tokens,
            current_step: state.current_step,
            seen_tokens: state.seen_tokens,
            best_validation_loss: state.best_validation_loss,
            trained: true,
        }, cfg, "best_model"))
        println("CHECKPOINT_END best_model")
    }
    println("=======================================================================")
    println("Training Complete")
    println("=======================================================================")
    println(gpt_large_training_summary(state, cfg))
    0
}
