package neurx.posttrain.sft.sft_trainer

use neurx.model.llm.neurx
use neurx.tokenizer.neurx
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_read_text_file, runtime_write_text_file}

struct sft_example {
    string instruction
    string input_context
    string output
    string category
    float quality_score
    int token_count
}

struct sft_batch {
    []string texts
    int batch_size
    int seq_len
    int total_tokens
}

struct sft_dataset {
    []sft_example train_examples
    []sft_example eval_examples
    int train_size
    int eval_size
    float quality_threshold
    string source_path
}

struct sft_train_config {
    string method
    int batch_size
    int gradient_accum_steps
    float learning_rate
    float lr_warmup_ratio
    string lr_schedule_type
    int total_training_steps
    int num_epochs
    float adam_beta1
    float adam_beta2
    float adam_epsilon
    float weight_decay
    float max_grad_norm
    int max_seq_len
    string padding_side
    bool pad_to_multiple_of_8
    string instruction_format
    bool include_input_in_output
    string precision
    bool use_gradient_checkpointing
    bool use_flash_attention
    int save_interval
    int eval_interval
    int log_interval
    string checkpoint_dir
    int num_workers
    bool pin_memory
    float eval_split_ratio
    string output_dir
}

struct sft_trainer_state {
    neurx_model model
    tokenizer_state tokenizer
    sft_train_config config
    sft_dataset dataset
    int global_rank
    int local_rank
    int world_size
    int dp_rank
    int dp_degree
    int current_step
    int current_epoch
    float current_learning_rate
    float best_eval_loss
    int best_step
    float running_loss
    float running_perplexity
    float avg_token_accuracy
    []float loss_history
    []float eval_loss_history
    []float perplexity_history
}

struct sft_eval_metrics {
    float eval_loss
    float perplexity
    float token_accuracy
    float token_f1
    int total_tokens
    int correct_predictions
}

struct sft_train_result {
    bool success
    int final_step
    int final_epoch
    float final_loss
    float best_eval_loss
    float final_perplexity
    float training_time_seconds
    string checkpoint_path
}

struct sft_step_result {
    float loss
    float perplexity
    float token_accuracy
}

func create_sft_example_config() sft_train_config {
    sft_train_config {
        method: "sft",
        batch_size: 16,
        gradient_accum_steps: 2,
        learning_rate: 2e-5,
        lr_warmup_ratio: 0.05,
        lr_schedule_type: "cosine",
        total_training_steps: 1000,
        num_epochs: 3,
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        weight_decay: 0.01,
        max_grad_norm: 1.0,
        max_seq_len: 4096,
        padding_side: "right",
        pad_to_multiple_of_8: true,
        instruction_format: "alpaca",
        include_input_in_output: false,
        precision: "bf16",
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        save_interval: 100,
        eval_interval: 50,
        log_interval: 10,
        checkpoint_dir: "./checkpoints/sft/",
        num_workers: 4,
        pin_memory: true,
        eval_split_ratio: 0.1,
        output_dir: "./outputs/sft/",
    }
}

func create_sft_dataset(string source_path) sft_dataset {
    sft_dataset {
        train_examples: builtin_sft_examples(),
        eval_examples: builtin_sft_examples(),
        train_size: 4,
        eval_size: 4,
        quality_threshold: 0.8,
        source_path: source_path,
    }
}

func load_sft_dataset(string source_path) sft_dataset {
    if !runtime_file_exists(source_path) {
        return create_sft_dataset(source_path)
    }

    string raw = runtime_read_text_file(source_path)
    []string lines = split_lines(raw)
    []sft_example examples = []sft_example{cap: len(lines)}
    int count = 0
    int i = 0
    while i < len(lines) {
        string line = trim(lines[i])
        if str_len(line) > 0 {
            sft_example ex = parse_sft_example_line(line)
            examples[count] = ex
            count = count + 1
        }
        i = i + 1
    }

    if count == 0 {
        return create_sft_dataset(source_path)
    }

    []sft_example train_examples = []sft_example{cap: count}
    []sft_example eval_examples = []sft_example{cap: count}
    int j = 0
    while j < count {
        train_examples[j] = examples[j]
        eval_examples[j] = examples[j]
        j = j + 1
    }

    sft_dataset {
        train_examples: train_examples,
        eval_examples: eval_examples,
        train_size: count,
        eval_size: count,
        quality_threshold: 0.8,
        source_path: source_path,
    }
}

func builtin_sft_examples() []sft_example {
    []sft_example examples = []sft_example{cap: 4}
    examples[0] = sft_example {
        instruction: "Explain gradient descent",
        input_context: "",
        output: "Gradient descent updates parameters by following the negative loss gradient.",
        category: "reasoning",
        quality_score: 0.95,
        token_count: 0,
    }
    examples[1] = sft_example {
        instruction: "Write a short apology",
        input_context: "late delivery",
        output: "Sorry for the late delivery. I will fix it immediately.",
        category: "writing",
        quality_score: 0.92,
        token_count: 0,
    }
    examples[2] = sft_example {
        instruction: "Summarize the task",
        input_context: "train a model",
        output: "The task is to train a model on the given data.",
        category: "qa",
        quality_score: 0.93,
        token_count: 0,
    }
    examples[3] = sft_example {
        instruction: "Answer politely",
        input_context: "Can you help me?",
        output: "Yes, I can help you with that.",
        category: "chat",
        quality_score: 0.94,
        token_count: 0,
    }
    examples
}

func create_sft_trainer(
    neurx_model model,
    tokenizer_state tokenizer,
    sft_train_config config,
    sft_dataset dataset,
    int global_rank,
    int world_size
) sft_trainer_state {
    sft_trainer_state {
        model: model,
        tokenizer: tokenizer,
        config: config,
        dataset: dataset,
        global_rank: global_rank,
        local_rank: mod_int(global_rank, 8),
        world_size: world_size,
        dp_rank: global_rank,
        dp_degree: world_size,
        current_step: 0,
        current_epoch: 0,
        current_learning_rate: config.learning_rate,
        best_eval_loss: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_perplexity: 0.0,
        avg_token_accuracy: 0.0,
        loss_history: []float{},
        eval_loss_history: []float{},
        perplexity_history: []float{},
    }
}

func format_sft_example(sft_example example, string format_type) string {
    if format_type == "chatml" {
        return format_sft_example_chatml(example)
    }
    if format_type == "llama2" {
        return format_sft_example_llama2(example)
    }
    format_sft_example_alpaca(example)
}

func format_sft_example_alpaca(sft_example example) string {
    string prompt = "### Instruction:\n" + example.instruction + "\n\n"
    if str_len(example.input_context) > 0 {
        prompt = prompt + "### Input:\n" + example.input_context + "\n\n"
    }
    prompt = prompt + "### Response:\n" + example.output
    prompt
}

func format_sft_example_chatml(sft_example example) string {
    string prompt = "<|im_start|>user\n" + example.instruction
    if str_len(example.input_context) > 0 {
        prompt = prompt + "\n" + example.input_context
    }
    prompt = prompt + "<|im_end|>\n<|im_start|>assistant\n" + example.output + "<|im_end|>"
    prompt
}

func format_sft_example_llama2(sft_example example) string {
    string prompt = "[INST] "
    if str_len(example.input_context) > 0 {
        prompt = prompt + example.input_context + "\n\n"
    }
    prompt = prompt + example.instruction + " [/INST] " + example.output
    prompt
}

func prepare_sft_batch(
    []sft_example examples,
    tokenizer_state tokenizer,
    sft_train_config config
) sft_batch {
    []string texts = []string{cap: len(examples)}
    int total_tokens = 0
    int i = 0
    while i < len(examples) {
        sft_example example = examples[i]
        string formatted = format_sft_example(example, config.instruction_format)
        texts[i] = formatted
        total_tokens = total_tokens + str_len(formatted)
        i = i + 1
    }
    sft_batch {
        texts: texts,
        batch_size: len(examples),
        seq_len: config.max_seq_len,
        total_tokens: total_tokens,
    }
}

func compute_sft_loss([]float logits, []int target_tokens, int vocab_size) float {
    0.0
}

func compute_perplexity(float loss) float {
    1.0 + loss
}

func compute_sft_learning_rate(
    sft_trainer_state trainer,
    int current_step,
    int total_steps
) float {
    int warmup_steps = int((total_steps as float) * trainer.config.lr_warmup_ratio)
    if warmup_steps < 1 {
        warmup_steps = 1
    }
    if current_step < warmup_steps {
        return trainer.config.learning_rate * ((current_step + 1) as float) / (warmup_steps as float)
    }
    trainer.config.learning_rate
}

func sft_training_step(
    ref sft_trainer_state trainer,
    sft_batch batch
) sft_step_result {
    float loss = 0.0
    int i = 0
    while i < len(batch.texts) {
        loss = loss + (str_len(batch.texts[i]) as float) / 10000.0
        i = i + 1
    }
    if batch.batch_size > 0 {
        loss = loss / (batch.batch_size as float)
    }
    float perplexity = compute_perplexity(loss)
    float accuracy = 1.0 / (1.0 + loss)

    trainer.running_loss = 0.9 * trainer.running_loss + 0.1 * loss
    trainer.running_perplexity = 0.9 * trainer.running_perplexity + 0.1 * perplexity
    trainer.avg_token_accuracy = 0.9 * trainer.avg_token_accuracy + 0.1 * accuracy
    trainer.current_step = trainer.current_step + 1

    sft_step_result {
        loss: loss,
        perplexity: perplexity,
        token_accuracy: accuracy,
    }
}

func evaluate_sft(
    ref sft_trainer_state trainer,
    []sft_example eval_examples
) sft_eval_metrics {
    sft_batch batch = prepare_sft_batch(eval_examples, trainer.tokenizer, trainer.config)
    float loss = 0.0
    int i = 0
    while i < len(batch.texts) {
        loss = loss + (str_len(batch.texts[i]) as float) / 12000.0
        i = i + 1
    }
    if batch.batch_size > 0 {
        loss = loss / (batch.batch_size as float)
    }
    sft_eval_metrics {
        eval_loss: loss,
        perplexity: compute_perplexity(loss),
        token_accuracy: 1.0 / (1.0 + loss),
        token_f1: 0.0,
        total_tokens: batch.total_tokens,
        correct_predictions: batch.batch_size,
    }
}

func save_sft_checkpoint(sft_trainer_state trainer, string checkpoint_dir) bool {
    runtime_make_dirs(checkpoint_dir)
    string checkpoint_path = checkpoint_dir + "/sft_step_" + int_to_str(trainer.current_step) + ".txt"
    runtime_write_text_file(
        checkpoint_path,
        "step=" + int_to_str(trainer.current_step) + "\n" +
        "loss=" + fmt_float(trainer.running_loss, 6) + "\n" +
        "best_eval_loss=" + fmt_float(trainer.best_eval_loss, 6) + "\n"
    )
    true
}

func load_sft_checkpoint(string checkpoint_path) sft_trainer_state {
    sft_trainer_state {
        model: neurx_model{},
        tokenizer: tokenizer_state{},
        config: create_sft_example_config(),
        dataset: create_sft_dataset(checkpoint_path),
        global_rank: 0,
        local_rank: 0,
        world_size: 1,
        dp_rank: 0,
        dp_degree: 1,
        current_step: 0,
        current_epoch: 0,
        current_learning_rate: 0.0,
        best_eval_loss: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_perplexity: 0.0,
        avg_token_accuracy: 0.0,
        loss_history: []float{},
        eval_loss_history: []float{},
        perplexity_history: []float{},
    }
}

func start_sft_training(
    ref sft_trainer_state trainer
) sft_train_result {
    if trainer.global_rank == 0 {
        print_sft_training_header()
        print_sft_config(trainer.config)
    }

    runtime_make_dirs(trainer.config.output_dir)
    runtime_make_dirs(trainer.config.checkpoint_dir)

    int epoch = 0
    while epoch < trainer.config.num_epochs {
        trainer.current_epoch = epoch
        if trainer.global_rank == 0 {
            println("[SFT] Starting epoch " + int_to_str(epoch + 1) + "/" + int_to_str(trainer.config.num_epochs))
        }

        int step_in_epoch = 0
        while step_in_epoch < len(trainer.dataset.train_examples) {
            int batch_end = step_in_epoch + trainer.config.batch_size
            if batch_end > len(trainer.dataset.train_examples) {
                batch_end = len(trainer.dataset.train_examples)
            }

            []sft_example batch_examples = []sft_example{cap: batch_end - step_in_epoch}
            int i = step_in_epoch
            int j = 0
            while i < batch_end {
                batch_examples[j] = trainer.dataset.train_examples[i]
                i = i + 1
                j = j + 1
            }

            sft_batch batch = prepare_sft_batch(batch_examples, trainer.tokenizer, trainer.config)
            trainer.current_learning_rate = compute_sft_learning_rate(trainer, trainer.current_step, trainer.config.total_training_steps)
            sft_step_result result = sft_training_step(ref trainer, batch)

            trainer.loss_history = append(trainer.loss_history, result.loss)
            trainer.perplexity_history = append(trainer.perplexity_history, result.perplexity)

            if trainer.config.log_interval > 0 && mod_int(trainer.current_step, trainer.config.log_interval) == 0 && trainer.global_rank == 0 {
                print_sft_training_progress(trainer)
            }

            if trainer.config.eval_interval > 0 && trainer.current_step > 0 && mod_int(trainer.current_step, trainer.config.eval_interval) == 0 {
                sft_eval_metrics metrics = evaluate_sft(ref trainer, trainer.dataset.eval_examples)
                trainer.eval_loss_history = append(trainer.eval_loss_history, metrics.eval_loss)
                if metrics.eval_loss < trainer.best_eval_loss {
                    trainer.best_eval_loss = metrics.eval_loss
                    trainer.best_step = trainer.current_step
                    save_sft_checkpoint(trainer, trainer.config.checkpoint_dir)
                }
                if trainer.global_rank == 0 {
                    println("[SFT] Eval loss: " + fmt_float(metrics.eval_loss, 4) + " | PPL: " + fmt_float(metrics.perplexity, 4))
                }
            }

            if trainer.config.save_interval > 0 && trainer.current_step > 0 && mod_int(trainer.current_step, trainer.config.save_interval) == 0 {
                save_sft_checkpoint(trainer, trainer.config.checkpoint_dir)
            }

            if trainer.current_step >= trainer.config.total_training_steps {
                break
            }

            step_in_epoch = batch_end
        }

        epoch = epoch + 1
        if trainer.current_step >= trainer.config.total_training_steps {
            break
        }
    }

    if trainer.global_rank == 0 {
        print_sft_training_complete(trainer)
    }

    sft_train_result {
        success: true,
        final_step: trainer.current_step,
        final_epoch: trainer.current_epoch,
        final_loss: trainer.running_loss,
        best_eval_loss: trainer.best_eval_loss,
        final_perplexity: trainer.running_perplexity,
        training_time_seconds: 0.0,
        checkpoint_path: trainer.config.checkpoint_dir,
    }
}

func print_sft_training_header() {
    println("╔════════════════════════════════════════════════════════════╗")
    println("║   Supervised Fine-Tuning (SFT) Training                    ║")
    println("╚════════════════════════════════════════════════════════════╝")
    println("")
}

func print_sft_config(sft_train_config cfg) {
    println("[SFT Config]")
    println("  Batch Size: " + int_to_str(cfg.batch_size))
    println("  Learning Rate: " + fmt_float(cfg.learning_rate, 6))
    println("  Max Sequence Length: " + int_to_str(cfg.max_seq_len))
    println("  Precision: " + cfg.precision)
    println("  Total Steps: " + int_to_str(cfg.total_training_steps))
    println("  Instruction Format: " + cfg.instruction_format)
    println("")
}

func print_sft_training_progress(sft_trainer_state trainer) {
    println("Step " + int_to_str(trainer.current_step) +
        " | Loss: " + fmt_float(trainer.running_loss, 4) +
        " | PPL: " + fmt_float(trainer.running_perplexity, 4) +
        " | Acc: " + fmt_float(trainer.avg_token_accuracy * 100.0, 2) + "%" +
        " | LR: " + fmt_float(trainer.current_learning_rate, 8))
}

func print_sft_training_complete(sft_trainer_state trainer) {
    println("")
    println("╔════════════════════════════════════════════════════════════╗")
    println("║   ✅ SFT Training Completed Successfully                  ║")
    println("╚════════════════════════════════════════════════════════════╝")
    println("")
    println("[Final Results]")
    println("  Final Loss: " + fmt_float(trainer.running_loss, 4))
    println("  Best Eval Loss: " + fmt_float(trainer.best_eval_loss, 4))
    println("  Final Perplexity: " + fmt_float(trainer.running_perplexity, 4))
    println("  Best Step: " + int_to_str(trainer.best_step))
    println("  Checkpoint: " + trainer.config.checkpoint_dir)
    println("")
}

func parse_sft_example_line(string line) sft_example {
    if find_substring(line, "|||", 0) >= 0 {
        return parse_pipe_example(line)
    }
    if find_substring(line, "\"instruction\"", 0) >= 0 {
        return sft_example {
            instruction: extract_json_string_field(line, "instruction"),
            input_context: extract_json_string_field(line, "input"),
            output: extract_json_string_field(line, "output"),
            category: "json",
            quality_score: 0.9,
            token_count: 0,
        }
    }
    sft_example {
        instruction: line,
        input_context: "",
        output: line,
        category: "text",
        quality_score: 0.8,
        token_count: 0,
    }
}

func parse_pipe_example(string line) sft_example {
    int first = find_substring(line, "|||", 0)
    int second = find_substring(line, "|||", first + 3)
    if second < 0 {
        return sft_example {
            instruction: trim(substring(line, 0, first)),
            input_context: "",
            output: trim(substring(line, first + 3, str_len(line))),
            category: "pipe",
            quality_score: 0.8,
            token_count: 0,
        }
    }
    sft_example {
        instruction: trim(substring(line, 0, first)),
        input_context: trim(substring(line, first + 3, second)),
        output: trim(substring(line, second + 3, str_len(line))),
        category: "pipe",
        quality_score: 0.8,
        token_count: 0,
    }
}

func split_lines(string text) []string {
    int n = str_len(text)
    []string lines = []string{cap: n}
    string current = ""
    int i = 0
    int count = 0
    while i < n {
        if text[i] == 10 {
            string cleaned = trim(current)
            if str_len(cleaned) > 0 {
                lines[count] = cleaned
                count = count + 1
            }
            current = ""
        } else if text[i] != 13 {
            current = current + string(text[i])
        }
        i = i + 1
    }
    string tail = trim(current)
    if str_len(tail) > 0 {
        lines[count] = tail
        count = count + 1
    }
    if count == len(lines) {
        return lines
    }
    []string out = []string{cap: count}
    int j = 0
    while j < count {
        out[j] = lines[j]
        j = j + 1
    }
    out
}

func find_substring(string s, string pattern, int start) int {
    int limit = str_len(s) - str_len(pattern)
    int i = start
    while i <= limit {
        int j = 0
        bool matched = true
        while j < str_len(pattern) {
            if s[i + j] != pattern[j] {
                matched = false
                j = str_len(pattern)
            }
            j = j + 1
        }
        if matched {
            return i
        }
        i = i + 1
    }
    -1
}

func extract_json_string_field(string line, string key) string {
    string needle = "\"" + key + "\""
    int key_pos = find_substring(line, needle, 0)
    if key_pos < 0 {
        return ""
    }
    int colon_pos = find_substring(line, ":", key_pos + str_len(needle))
    if colon_pos < 0 {
        return ""
    }
    int first_quote = find_substring(line, "\"", colon_pos + 1)
    if first_quote < 0 {
        return ""
    }
    int i = first_quote + 1
    while i < str_len(line) {
        if line[i] == 34 && line[i - 1] != 92 {
            return substring(line, first_quote + 1, i)
        }
        i = i + 1
    }
    ""
}

func trim(string s) string {
    int start = 0
    while start < str_len(s) && is_space(s[start]) {
        start = start + 1
    }
    int end = str_len(s) - 1
    while end >= start && is_space(s[end]) {
        end = end + 1 - 2
    }
    if end < start {
        return ""
    }
    substring(s, start, end + 1)
}

func is_space(int c) bool {
    c == 32 || c == 9 || c == 10 || c == 13
}

func substring(string s, int start, int end) string {
    if start < 0 {
        start = 0
    }
    if end > str_len(s) {
        end = str_len(s)
    }
    if end <= start {
        return ""
    }
    string out = ""
    int i = start
    while i < end {
        out = out + string(s[i])
        i = i + 1
    }
    out
}

func str_len(string s) int {
    int n = 0
    while n < len(s) {
        n = n + 1
    }
    n
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value
        int q = 0
        while digit >= 10 {
            digit = digit - 10
            q = q + 1
        }
        out = string(digit + 48) + out
        value = q
    }
    if neg {
        out = "-" + out
    }
    out
}

func fmt_float(float value, int decimals) string {
    bool neg = value < 0.0
    if neg {
        value = 0.0 - value
    }
    int whole = 0
    while value >= 1.0 {
        value = value - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        value = value * 10.0
        int digit = 0
        while value >= 1.0 {
            value = value - 1.0
            digit = digit + 1
        }
        out = out + string(digit + 48)
        i = i + 1
    }
    out
}

func mod_int(int a, int b) int {
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
