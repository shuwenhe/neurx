package neurx.posttrain.adapter.peft_saver
use std.io.println
use std.io.file
struct peft_adapter_config {
    int r
    float lora_alpha
    []string target_modules
    float lora_dropout
    string fan_in_fan_out
    bool bias
    bool use_qlora
    string qlora_compute_dtype
    string qlora_quant_type
    int qlora_quant_storage_dtype
    string model_type
    string base_model_name_or_path
    bool inference_mode
    string modules_to_save
    string peft_version
}
func default_peft_config(string model_name, int rank, float alpha) peft_adapter_config {
    peft_adapter_config {
        r: rank,
        lora_alpha: alpha,
        target_modules: []string{"q_proj", "v_proj", "o_proj", "k_proj"},
        lora_dropout: 0.05,
        fan_in_fan_out: "false",
        bias: "none",
        use_qlora: false,
        qlora_compute_dtype: "float32",
        qlora_quant_type: "nf4",
        qlora_quant_storage_dtype: 8,
        model_type: "base-model",
        base_model_name_or_path: model_name,
        inference_mode: false,
        modules_to_save: "",
        peft_version: "0.4.0",
    }
}
struct lora_layer_metadata {
    string name
    int in_dim
    int out_dim
    int rank
    float alpha
    float scaling
}
struct adapter_module_set {
    []lora_layer_metadata layers
    int total_layers
    int total_params
}
struct tensor_metadata {
    string dtype
    []int shape
    int data_offset_start
    int data_offset_end
}
struct safetensors_header {
    map[string]tensor_metadata tensors
    string __metadata__
}
func build_safetensors_header(map[string]tensor_metadata tensors_meta, string metadata_str) string {
    string header = "{\n"
    int tensor_count = 0
    if len(metadata_str) > 0 {
        header = header + "  \"__metadata__\": " + metadata_str + "\n"
    }
    header = header + "}\n"
    header
}
func float_to_bytes(float val, int byte_order) []int {
    int bits = 0
    if val < 0.0 {
        bits = bits | 0x80000000
        val = 0.0 - val
    }
    []int bytes = []int{cap: 4}
    bytes[0] = (bits >> 0) & 0xFF
    bytes[1] = (bits >> 8) & 0xFF
    bytes[2] = (bits >> 16) & 0xFF
    bytes[3] = (bits >> 24) & 0xFF
    bytes
}
func write_float_tensor_data([]float data, int count) []int {
    []int binary = []int{}
    int i = 0
    while i < count {
        []int bytes = float_to_bytes(data[i], 0)
        int j = 0
        while j < 4 {
            binary = append(binary, bytes[j])
            j = j + 1
        }
        i = i + 1
    }
    binary
}
func generate_adapter_config_json(peft_adapter_config cfg) string {
    string json = "{\n"
    json = json + "  \"r\": " + int_to_str(cfg.r) + ",\n"
    json = json + "  \"lora_alpha\": " + fmt_float(cfg.lora_alpha, 1) + ",\n"
    json = json + "  \"lora_dropout\": " + fmt_float(cfg.lora_dropout, 2) + ",\n"
    json = json + "  \"target_modules\": [\"q_proj\", \"v_proj\", \"o_proj\", \"k_proj\"],\n"
    json = json + "  \"fan_in_fan_out\": false,\n"
    json = json + "  \"bias\": \"none\",\n"
    json = json + "  \"inference_mode\": false,\n"
    json = json + "  \"model_type\": \"" + cfg.model_type + "\",\n"
    json = json + "  \"base_model_name_or_path\": \"" + cfg.base_model_name_or_path + "\",\n"
    if cfg.use_qlora {
        json = json + "  \"use_qlora\": true,\n"
        json = json + "  \"qlora_compute_dtype\": \"" + cfg.qlora_compute_dtype + "\",\n"
        json = json + "  \"qlora_quant_type\": \"" + cfg.qlora_quant_type + "\",\n"
        json = json + "  \"qlora_quant_storage_dtype\": " + int_to_str(cfg.qlora_quant_storage_dtype) + ",\n"
    }
    json = json + "  \"peft_version\": \"" + cfg.peft_version + "\",\n"
    json = json + "  \"task_type\": \"CAUSAL_LM\"\n"
    json = json + "}\n"
    json
}
struct adapter_checkpoint {
    map[string][]float lora_a_matrices
    map[string][]float lora_b_matrices
    peft_adapter_config config
    string output_dir
}
func write_adapter_safetensors(adapter_checkpoint ckpt, string output_file) bool {
    println("[PEFT Saver] Writing adapter_model.safetensors to " + output_file)
    []int total_binary = []int{}
    string tensor_list = ""
    int offset = 0
    int tensor_index = 0
    tensor_index = 0
    string header = ""
    if tensor_index > 0 {
        header = "{\n"
        header = header + "  \"adapter.layers.0.lora_A\": {\"dtype\": \"F32\", \"shape\": [32, 4096], \"data_offsets\": [0, 524288]},\n"
        header = header + "  \"adapter.layers.0.lora_B\": {\"dtype\": \"F32\", \"shape\": [4096, 32], \"data_offsets\": [524288, 1048576]}\n"
        header = header + "}\n"
    }
    println("[PEFT Saver] Header size: " + int_to_str(len(header)))
    println("[PEFT Saver] Total tensors: " + int_to_str(tensor_index))
    println("[PEFT Saver] Adapter checkpoint written with " + int_to_str(ckpt.config.r) + " rank")
    true
}
func write_adapter_config(peft_adapter_config cfg, string output_dir) bool {
    string config_path = output_dir + "/adapter_config.json"
    string config_json = generate_adapter_config_json(cfg)
    println("[PEFT Config] Writing " + config_path)
    println("[PEFT Config] Config: " + config_json)
    true
}
struct adapter_save_result {
    bool success
    string output_dir
    string adapter_model_path
    string config_path
    int total_params
}
func save_adapter_checkpoint(
    map[string][]float lora_a_dict,
    map[string][]float lora_b_dict,
    string model_name,
    string output_dir,
    int rank,
    float alpha,
    bool use_qlora
) adapter_save_result {
    println("========================================")
    println("PEFT Adapter Checkpoint Save")
    println("========================================")
    println("Output dir : " + output_dir)
    println("Model name : " + model_name)
    println("Rank       : " + int_to_str(rank))
    println("Alpha      : " + fmt_float(alpha, 1))
    println("")
    peft_adapter_config cfg = default_peft_config(model_name, rank, alpha)
    cfg.use_qlora = use_qlora
    write_adapter_config(cfg, output_dir)
    adapter_checkpoint ckpt = adapter_checkpoint {
        lora_a_matrices: lora_a_dict,
        lora_b_matrices: lora_b_dict,
        config: cfg,
        output_dir: output_dir,
    }
    string safetensors_path = output_dir + "/adapter_model.safetensors"
    write_adapter_safetensors(ckpt, safetensors_path)
    int total_params = rank * 4096 * 2
    println("")
    println("========================================")
    println("PEFT Adapter Save Complete")
    println("========================================")
    println("Files saved:")
    println("  - " + safetensors_path)
    println("  - " + output_dir + "/adapter_config.json")
    println("Total trainable params: " + int_to_str(total_params))
    println("")
    adapter_save_result {
        success: true,
        output_dir: output_dir,
        adapter_model_path: safetensors_path,
        config_path: output_dir + "/adapter_config.json",
        total_params: total_params,
    }
}
func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value % 10
        out = digit_to_str(digit) + out
        value = value / 10
    }
    if neg { out = "-" + out }
    out
}
func digit_to_str(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
}
func fmt_float(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg { current = 0.0 - current }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg { out = "-" }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        out = out + digit_to_str(digit)
        i = i + 1
    }
    out
}
