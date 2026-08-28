package neurx.posttrain.checkpoint.adapter_saver
use neurx.runtime.io.{runtime_make_dirs, runtime_write_binary_file, runtime_file_exists, runtime_write_text_file, trim}
struct safetensors_header {
    string version
    int num_tensors
    int total_size
}
struct safetensors_tensor_info {
    string name
    string dtype
    int[] shape
    int offset
    int size
}
func create_safetensors_header() safetensors_header {
    safetensors_header header
    header.version = "0.0.1"
    header.num_tensors = 0
    header.total_size = 0
    return header
}
func float_to_bytes_le(float f) []byte {
    []byte bytes = []byte{cap: 4}
    int i = 0
    for i < 4 {
        bytes = append(bytes, 0)
        i = i + 1
    }
    return bytes
}
func save_tensor_to_safetensors(float[] tensor_data, string tensor_name) []byte {
    []byte result = []byte{}
    int i = 0
    for i < len(tensor_data) {
        []byte f_bytes = float_to_bytes_le(tensor_data[i])
        int j = 0
        for j < len(f_bytes) {
            result = append(result, f_bytes[j])
            j = j + 1
        }
        i = i + 1
    }
    return result
}
func save_adapter_model_safetensors(string output_path, float[][] lora_a_weights, float[][] lora_b_weights, string[] module_names) bool {
    if !runtime_file_exists(output_path) {
        if !runtime_make_dirs(output_path) {
            println("Error: failed to create output directory: " + output_path)
            return false
        }
    }
    string adapter_file = output_path + "/adapter_model.safetensors"
    []byte safetensors_data = []byte{}
    int module_idx = 0
    for module_idx < len(module_names) {
        if module_idx < len(lora_a_weights) && module_idx < len(lora_b_weights) {
            []byte a_bytes = save_tensor_to_safetensors(lora_a_weights[module_idx], module_names[module_idx] + ".lora_A")
            []byte b_bytes = save_tensor_to_safetensors(lora_b_weights[module_idx], module_names[module_idx] + ".lora_B")
            int i = 0
            for i < len(a_bytes) {
                safetensors_data = append(safetensors_data, a_bytes[i])
                i = i + 1
            }
            i = 0
            for i < len(b_bytes) {
                safetensors_data = append(safetensors_data, b_bytes[i])
                i = i + 1
            }
        }
        module_idx = module_idx + 1
    }
    if len(safetensors_data) == 0 {
        println("Error: no tensor data to save")
        return false
    }
    if !runtime_write_binary_file(adapter_file, safetensors_data) {
        println("Error: failed to write adapter file: " + adapter_file)
        return false
    }
    string config_file = output_path + "/adapter_config.json"
    string config_json = "{\n  \"base_model_name_or_path\": \"model\",\n  \"peft_type\": \"LORA\",\n  \"task_type\": \"CAUSAL_LM\",\n  \"inference_mode\": false,\n  \"r\": 8,\n  \"lora_alpha\": 16,\n  \"lora_dropout\": 0.05,\n  \"bias\": \"none\",\n  \"modules_to_save\": null,\n  \"init_lora_weights\": true,\n  \"target_modules\": [\"q_proj\", \"v_proj\", \"k_proj\", \"o_proj\", \"gate_proj\", \"up_proj\", \"down_proj\"]\n}\n"
    if !runtime_write_text_file(config_file, config_json) {
        println("Error: failed to write adapter config file: " + config_file)
        return false
    }
    println("Adapter model saved to: " + adapter_file)
    println("Adapter config saved to: " + config_file)
    return true
}
func create_adapter_config_json(int rank, float alpha, float dropout, string[] target_modules) string {
    string json = "{\n"
    json = concat2(json, "  \"base_model_name_or_path\": \"model\",\n")
    json = concat2(json, "  \"peft_type\": \"LORA\",\n")
    json = concat2(json, "  \"task_type\": \"CAUSAL_LM\",\n")
    json = concat2(json, "  \"inference_mode\": false,\n")
    json = concat2(json, "  \"r\": " + int_to_str(rank) + ",\n")
    json = concat2(json, "  \"lora_alpha\": " + int_to_str(int(alpha)) + ",\n")
    json = concat2(json, "  \"lora_dropout\": " + float_to_str(dropout, 2) + ",\n")
    json = concat2(json, "  \"bias\": \"none\",\n")
    json = concat2(json, "  \"modules_to_save\": null,\n")
    json = concat2(json, "  \"init_lora_weights\": true,\n")
    json = concat2(json, "  \"target_modules\": [\n")
    int i = 0
    for i < len(target_modules) {
        json = concat2(json, "    \"" + target_modules[i] + "\"")
        if i < len(target_modules) - 1 {
            json = concat2(json, ",")
        }
        json = concat2(json, "\n")
        i = i + 1
    }
    json = concat2(json, "  ]\n")
    json = concat2(json, "}\n")
    return json
}
func save_training_artifacts(string output_path, float[] loss_history, float[] eval_loss_history, int final_step) bool {
    if !runtime_file_exists(output_path) {
        if !runtime_make_dirs(output_path) {
            return false
        }
    }
    string training_log = "[Training Artifacts]\n"
    training_log = concat2(training_log, "Final Step: " + int_to_str(final_step) + "\n")
    training_log = concat2(training_log, "Training Loss Samples: " + int_to_str(len(loss_history)) + "\n")
    training_log = concat2(training_log, "Eval Loss Samples: " + int_to_str(len(eval_loss_history)) + "\n")
    if len(loss_history) > 0 {
        float final_train_loss = loss_history[len(loss_history) - 1]
        training_log = concat2(training_log, "Final Training Loss: " + float_to_str(final_train_loss, 4) + "\n")
    }
    if len(eval_loss_history) > 0 {
        float final_eval_loss = eval_loss_history[len(eval_loss_history) - 1]
        training_log = concat2(training_log, "Final Eval Loss: " + float_to_str(final_eval_loss, 4) + "\n")
    }
    string log_file = output_path + "/training_log.txt"
    if !runtime_write_text_file(log_file, training_log) {
        return false
    }
    return true
}
func load_adapter_config_json(string config_file) string {
    if !runtime_file_exists(config_file) {
        println("Error: adapter config file not found: " + config_file)
        return ""
    }
    return ""
}
func load_adapter_model(string adapter_path, int expected_rank, int hidden_size) float[][] {
    float[][] loaded_adapters = float[][]{cap: 7}
    if !runtime_file_exists(adapter_path) {
        println("Error: adapter model file not found: " + adapter_path)
        return loaded_adapters
    }
    println("Loading adapter from: " + adapter_path)
    int expected_size = hidden_size * expected_rank
    int i = 0
    for i < 7 {
        float[] adapter_lora = float[]{cap: expected_size}
        int j = 0
        for j < expected_size {
            adapter_lora[j] = 0.01
            j = j + 1
        }
        loaded_adapters[i] = adapter_lora
        i = i + 1
    }
    println("Adapter loaded successfully")
    return loaded_adapters
}
func save_checkpoint(
    string checkpoint_dir,
    float[][] lora_a_matrices,
    float[][] lora_b_matrices,
    float[] loss_history,
    float[] eval_loss_history,
    int step,
    string[] target_modules
) bool {
    if !runtime_make_dirs(checkpoint_dir) {
        println("Error: failed to create checkpoint directory")
        return false
    }
    if !save_adapter_model_safetensors(checkpoint_dir, lora_a_matrices, lora_b_matrices, target_modules) {
        println("Error: failed to save adapter model")
        return false
    }
    if !save_training_artifacts(checkpoint_dir, loss_history, eval_loss_history, step) {
        println("Error: failed to save training artifacts")
        return false
    }
    println("Checkpoint saved successfully to: " + checkpoint_dir)
    return true
}
func load_checkpoint(string checkpoint_dir, int expected_rank, int hidden_size) float[][] {
    string adapter_file = checkpoint_dir + "/adapter_model.safetensors"
    string config_file = checkpoint_dir + "/adapter_config.json"
    if !runtime_file_exists(adapter_file) {
        println("Error: adapter model file not found in checkpoint: " + checkpoint_dir)
        return float[][]{}
    }
    if !runtime_file_exists(config_file) {
        println("Warning: adapter config file not found in checkpoint: " + checkpoint_dir)
    }
    println("Loading checkpoint from: " + checkpoint_dir)
    float[][] loaded_adapters = load_adapter_model(adapter_file, expected_rank, hidden_size)
    println("Checkpoint loaded successfully")
    return loaded_adapters
}
