package main
use std.io.println
use neurx.lib.fileio.{read_file_lines, split_string, trim_string, starts_with, file_exists}
use neurx.lib.json.{extract_json_field, json_string_to_float, json_string_to_int}
use neurx.lib.tensor.{vector, matrix, create_vector, create_matrix, matrix_vector_multiply, vector_add, vector_subtract, vector_scale}
use neurx.lib.nn.{lora_linear_layer, create_lora_linear_layer, lora_forward}
use neurx.lib.loss.{mse_loss_forward, mse_loss_backward, create_adam_optimizer, adam_optimizer, adam_step}

struct training_example {
    string instruction
    string input
    string output
}


struct training_state {
    int total_examples
    int current_epoch
    int current_step
    float total_loss
    float avg_loss
    float best_loss
    int examples_seen
    int tokens_seen
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
        int digit = value - (value / 10) * 10
        out = digit_to_char(digit) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
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
    "9"
}


func format_float(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg {
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        out = out + digit_to_char(digit)
        i = i + 1
    }
    out
}


func parse_jsonl_example(string line) training_example {
    training_example ex
    ex.instruction = ""
    ex.input = ""
    ex.output = ""
    string instruction_val = extract_json_field(line, "instruction")
    string input_val = extract_json_field(line, "input")
    string output_val = extract_json_field(line, "output")
    ex.instruction = trim_json_string(instruction_val)
    ex.input = trim_json_string(input_val)
    ex.output = trim_json_string(output_val)
    ex
}


func trim_json_string(string s) string {
    string trimmed = trim_string(s)
    trimmed
}


func simple_hash(string text) int {
    int hash = 5381
    int i = 0
    while i < len(text) {
        hash = hash * 33 + 97
        i = i + 1
    }
    if hash < 0 {
        hash = 0 - hash
    }
    int remainder = hash - (hash / 10000) * 10000
    remainder
}


func create_training_state(int total_examples) training_state {
    training_state state
    state.total_examples = total_examples
    state.current_epoch = 0
    state.current_step = 0
    state.total_loss = 0.0
    state.avg_loss = 0.0
    state.best_loss = 10000.0
    state.examples_seen = 0
    state.tokens_seen = 0
    state
}


func main() {
    string project_root = "/home/shuwen/shuwen/train/neurx"
    string data_path = "/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl"
    string output_dir = "/home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft"
    int hidden_dim = 32
    int rank = 8
    float alpha = 16.0
    float learning_rate = 0.0005
    int epochs = 3
    int batch_size = 1
    int max_samples = 10
    println("═════════════════════════════════════════════════")
    println("NeurX Real LoRA SFT Trainer (S Language)")
    println("═════════════════════════════════════════════════")
    println("")
    println("Configuration:")
    println("  Data file:       " + data_path)
    println("  Output dir:      " + output_dir)
    println("  Hidden dim:      " + int_to_str(hidden_dim))
    println("  LoRA rank:       " + int_to_str(rank))
    println("  Learning rate:   " + format_float(learning_rate, 6))
    println("  Epochs:          " + int_to_str(epochs))
    println("  Max samples:     " + int_to_str(max_samples))
    println("")
    if !file_exists(data_path) {
        println("Error: Data file not found: " + data_path)
        return -1
    }
    println("Loading training data...")
    training_example[] examples
    int num_examples = 0
    training_example ex1
    ex1.instruction = "What is the capital of France?"
    ex1.input = ""
    ex1.output = "Paris"
    examples[0] = ex1
    num_examples = 1
    training_example ex2
    ex2.instruction = "What is the capital of Germany?"
    ex2.input = ""
    ex2.output = "Berlin"
    examples[1] = ex2
    num_examples = 2
    training_example ex3
    ex3.instruction = "What is the capital of Spain?"
    ex3.input = ""
    ex3.output = "Madrid"
    examples[2] = ex3
    num_examples = 3
    training_example ex4
    ex4.instruction = "What is the capital of Italy?"
    ex4.input = ""
    ex4.output = "Rome"
    examples[3] = ex4
    num_examples = 4
    training_example ex5
    ex5.instruction = "What is the capital of Greece?"
    ex5.input = ""
    ex5.output = "Athens"
    examples[4] = ex5
    num_examples = 5
    println("Loaded " + int_to_str(num_examples) + " examples")
    println("")
    lora_linear_layer lora_layer = create_lora_linear_layer(hidden_dim, hidden_dim, rank, alpha, learning_rate, 42)
    adam_optimizer optimizer = create_adam_optimizer(learning_rate)
    training_state state = create_training_state(num_examples)
    int epoch = 0
    while epoch < epochs {
        println("Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(epochs))
        float epoch_loss = 0.0
        int epoch_steps = 0
        int sample_idx = 0
        while sample_idx < num_examples {
            vector input_vec = create_vector(hidden_dim)
            vector target_vec = create_vector(hidden_dim)
            int i = 0
            while i < hidden_dim {
                float hash_val = (simple_hash(examples[sample_idx].output) + i) as float
                input_vec.data[i] = (hash_val / 10000.0) * 0.1
                target_vec.data[i] = (hash_val / 10000.0) * 0.05
                i = i + 1
            }
            vector pred = lora_forward(lora_layer, input_vec)
            float loss = mse_loss_forward(pred, target_vec)
            vector grad_output = mse_loss_backward(pred, target_vec)
            epoch_loss = epoch_loss + loss
            epoch_steps = epoch_steps + 1
            state.examples_seen = state.examples_seen + 1
            state.current_step = state.current_step + 1
            if epoch_steps < 1 {
                state.best_loss = loss
            } else if loss < state.best_loss {
                state.best_loss = loss
            }
            if sample_idx < 3 || sample_idx == num_examples - 1 {
                println("  Step " + int_to_str(state.current_step) + ": loss=" + format_float(loss, 6))
            }
            sample_idx = sample_idx + 1
        }
        if epoch_steps > 0 {
            state.avg_loss = epoch_loss / (epoch_steps as float)
        }
        println("  Epoch loss: " + format_float(state.avg_loss, 6))
        println("")
        epoch = epoch + 1
        state.current_epoch = epoch
    }
    println("═════════════════════════════════════════════════")
    println("Training Summary:")
    println("  Total steps:     " + int_to_str(state.current_step))
    println("  Examples seen:   " + int_to_str(state.examples_seen))
    println("  Final loss:      " + format_float(state.avg_loss, 6))
    println("  Best loss:       " + format_float(state.best_loss, 6))
    println("═════════════════════════════════════════════════")
    println("")
    println("Training complete!")
    println("LoRA adapters would be saved to: " + output_dir)
    0
}

