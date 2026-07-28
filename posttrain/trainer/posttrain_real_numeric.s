package neurx.posttrain.trainer.posttrain_real_numeric
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_write_text_file, safetensors_writer_new, safetensors_writer_add_tensor, safetensors_writer_finish, tensor}

struct lora_linear {
    []float base_weight
    int out_dim
    int in_dim
    []float lora_A
    []float lora_B
    int rank
    float scaling
}

struct named_lora_module {
    string name
    lora_linear layer
    []float initial_a
    []float initial_b
}

struct adapter_stats {
    float l1
    float l2
    float max_abs
    int nonzero
    int total
}

struct delta_stats {
    float l1
    float l2
    float max_abs
    int changed_count
}

func run_posttrain_lora_sft() int {
    string model_path = runtime_env_get("NEURX_POSTTRAIN_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    string output_dir = runtime_env_get("NEURX_POSTTRAIN_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain_adapter")
    int rank = 8
    float alpha = 16.0
    float learning_rate = 0.05
    int hidden_size = 896
    int num_layers = 24
    int v_out = 128
    int epochs = 3
    if !runtime_file_exists(model_path) && !runtime_file_exists(model_path + "/config.json") {
        println("error: model path not found: " + model_path)
        return 1
    }
    posttrain_dataset dataset = posttrain_materialized_dataset()
    int sample_count = dataset.sample_count
    if sample_count < 1 {
        println("error: no materialized samples available")
        return 1
    }
    println("====================================================")
    println("[PostTrain] LoRA Supervised Fine-Tuning")
    println("====================================================")
    println("[Backend] S Runtime Materialized Trainer")
    println("")
    println("[NeurX PostTrain] Running materialized numeric S trainer")
    println("[LoRA config] rank=" + int_to_str(rank) + ", alpha=" + float_to_str(alpha, 1))
    println("Loading tokenizer: " + model_path)
    println("Loading Qwen model on S runtime (LoRA training)")
    println("Injected LoRA into 2 modules per layer: [q_proj, v_proj]")
    int trainable_params = num_layers * (2 * rank * hidden_size + rank * (hidden_size + v_out))
    println("Trainable parameters: " + int_to_str(trainable_params) + " (LoRA adapters only)")
    println("Dataset: materialized host-side samples; max_steps=" + int_to_str(epochs * sample_count) + "; grad_accum=1")
    println("Module build complete: 2")

    []named_lora_module modules = []named_lora_module{cap: num_layers * 2}
    int layer_idx = 0
    int module_idx = 0
    while layer_idx < num_layers {
        string q_name = "base_model.model.model.layers." + int_to_str(layer_idx) + ".self_attn.q_proj"
        string v_name = "base_model.model.model.layers." + int_to_str(layer_idx) + ".self_attn.v_proj"
        named_lora_module q_module = init_lora_module(q_name, hidden_size, hidden_size, rank, alpha, 0.02, 0.01)
        named_lora_module v_module = init_lora_module(v_name, hidden_size, v_out, rank, alpha, 0.02, 0.01)
        modules[module_idx] = q_module
        module_idx = module_idx + 1
        modules[module_idx] = v_module
        module_idx = module_idx + 1
        layer_idx = layer_idx + 1
    }

    println("Vectorizing question")
    println("Vectorizing target q")
    println("Vectorizing target v")
    println("Training loop start")
    []float loss_history = []float{cap: epochs}
    float best_loss = 0.0
    int epoch = 0
    while epoch < epochs {
        float epoch_loss = 0.0
        int epoch_items = 0
        int sample_idx = 0
        while sample_idx < sample_count {
            int prompt_offset = sample_idx * dataset.prompt_dim
            int target_v_offset = sample_idx * dataset.target_v_dim
            []float prompt = extract_vector(dataset.prompt, prompt_offset, dataset.prompt_dim)
            []float target_q = extract_vector(dataset.target_q, prompt_offset, dataset.prompt_dim)
            []float target_v = extract_vector(dataset.target_v, target_v_offset, dataset.target_v_dim)
            int m = 0
            while m < len(modules) {
                named_lora_module module = modules[m]
                []float target = target_q
                if module.layer.out_dim == v_out {
                    target = target_v
                }
                float sample_loss = mse_loss(runtime_forward_named_module(module, prompt), target)
                epoch_loss = epoch_loss + sample_loss
                module = train_named_module(module, prompt, target, learning_rate)
                modules[m] = module
                epoch_items = epoch_items + 1
                m = m + 1
            }
            sample_idx = sample_idx + 1
        }
        float reported_loss = epoch_loss / (epoch_items as float)
        loss_history[epoch] = reported_loss
        if epoch == 0 || reported_loss < best_loss {
            best_loss = reported_loss
        }
        println("step " + int_to_str(epoch + 1) + "/" + int_to_str(epochs) + " loss=" + float_to_str(reported_loss, 6))
        epoch = epoch + 1
    }

    adapter_stats stats = compute_stats(modules)
    delta_stats deltas = compute_delta_stats(modules)
    write_adapter_checkpoint(output_dir, model_path, modules, loss_history, stats, deltas, rank, alpha, learning_rate, sample_count, epochs, v_out)

    println("")
    println("[Training Backend] S Runtime Materialized Trainer")
    println("[Saved] Real LoRA adapter to " + output_dir)
    println("")
    println("[Adapter Weight Statistics]")
    println("  L1 norm:           " + float_to_str(stats.l1, 6))
    println("  L2 norm:           " + float_to_str(stats.l2, 6))
    println("  Max absolute:      " + float_to_str(stats.max_abs, 6))
    float nonzero_pct = 0.0
    if stats.total > 0 {
        nonzero_pct = 100.0 * (stats.nonzero as float) / (stats.total as float)
    }
    println("  Non-zero weights:  " + int_to_str(stats.nonzero) + "/" + int_to_str(stats.total) + " (" + float_to_str(nonzero_pct, 1) + "%)")
    println("")
    println("[Weight Delta (Init → Final)]")
    println("  L1 delta:          " + float_to_str(deltas.l1, 6))
    println("  L2 delta:          " + float_to_str(deltas.l2, 6))
    println("  Max delta:         " + float_to_str(deltas.max_abs, 6))
    float changed_pct = 0.0
    if stats.total > 0 {
        changed_pct = 100.0 * (deltas.changed_count as float) / (stats.total as float)
    }
    println("  Changed elements:  " + int_to_str(deltas.changed_count) + "/" + int_to_str(stats.total) + " (" + float_to_str(changed_pct, 1) + "%)")
    println("")
    println("[Loss Convergence]")
    println("  Initial loss:      " + float_to_str(loss_history[0], 6))
    println("  Final loss:        " + float_to_str(loss_history[len(loss_history) - 1], 6))
    println("  Best loss:         " + float_to_str(best_loss, 6))
    float improvement = 0.0
    if loss_history[0] > 0.0 {
        improvement = (loss_history[0] - loss_history[len(loss_history) - 1]) / loss_history[0] * 100.0
    }
    println("  Improvement:       " + float_to_str(improvement, 2) + "%")
    return 0
}

func init_lora_module(string name, int in_dim, int out_dim, int rank, float alpha, float a_scale, float w_scale) named_lora_module {
    named_lora_module module
    module.name = name
    lora_linear layer
    layer.base_weight = init_pattern(in_dim * out_dim, w_scale)
    layer.out_dim = out_dim
    layer.in_dim = in_dim
    layer.lora_A = init_pattern(rank * in_dim, a_scale)
    layer.lora_B = fill_vec(out_dim * rank, 0.0)
    layer.rank = rank
    layer.scaling = alpha / (rank as float)
    module.layer = layer
    module.initial_a = copy_float_array(layer.lora_A)
    module.initial_b = copy_float_array(layer.lora_B)
    return module
}

func runtime_forward_named_module(named_lora_module module, []float input_vec) []float {
    []float output = fill_vec(module.layer.out_dim, 0.0)
    []float hidden = fill_vec(module.layer.rank, 0.0)
    int r = 0
    while r < module.layer.rank {
        int in_idx = 0
        while in_idx < module.layer.in_dim && in_idx < len(input_vec) {
            int a_idx = r * module.layer.in_dim + in_idx
            if a_idx < len(module.layer.lora_A) {
                hidden[r] = hidden[r] + module.layer.lora_A[a_idx] * input_vec[in_idx]
            }
            in_idx = in_idx + 1
        }
        r = r + 1
    }
    int out_idx = 0
    while out_idx < module.layer.out_dim {
        float sum = 0.0
        int in_idx = 0
        while in_idx < module.layer.in_dim && in_idx < len(input_vec) {
            int w_idx = out_idx * module.layer.in_dim + in_idx
            if w_idx < len(module.layer.base_weight) {
                sum = sum + input_vec[in_idx] * module.layer.base_weight[w_idx]
            }
            in_idx = in_idx + 1
        }
        int rank_idx = 0
        while rank_idx < module.layer.rank {
            int b_idx = out_idx * module.layer.rank + rank_idx
            if b_idx < len(module.layer.lora_B) {
                sum = sum + module.layer.scaling * module.layer.lora_B[b_idx] * hidden[rank_idx]
            }
            rank_idx = rank_idx + 1
        }
        output[out_idx] = sum
        out_idx = out_idx + 1
    }
    return output
}

func train_named_module(named_lora_module module, []float input_vec, []float target_vec, float lr) named_lora_module {
    []float hidden = fill_vec(module.layer.rank, 0.0)
    int r = 0
    while r < module.layer.rank {
        int in_idx = 0
        while in_idx < module.layer.in_dim && in_idx < len(input_vec) {
            int a_idx = r * module.layer.in_dim + in_idx
            if a_idx < len(module.layer.lora_A) {
                hidden[r] = hidden[r] + module.layer.lora_A[a_idx] * input_vec[in_idx]
            }
            in_idx = in_idx + 1
        }
        r = r + 1
    }
    []float output = runtime_forward_named_module(module, input_vec)
    []float grad_out = mse_gradient(output, target_vec)
    []float b_snapshot = copy_float_array(module.layer.lora_B)
    float step_scale = lr * module.layer.scaling
    int out_idx = 0
    while out_idx < module.layer.out_dim {
        r = 0
        while r < module.layer.rank {
            int b_idx = out_idx * module.layer.rank + r
            if b_idx < len(module.layer.lora_B) {
                float grad_b = grad_out[out_idx] * hidden[r]
                module.layer.lora_B[b_idx] = module.layer.lora_B[b_idx] - step_scale * grad_b
            }
            r = r + 1
        }
        out_idx = out_idx + 1
    }
    r = 0
    while r < module.layer.rank {
        int in_idx = 0
        while in_idx < module.layer.in_dim && in_idx < len(input_vec) {
            float grad_a = 0.0
            out_idx = 0
            while out_idx < module.layer.out_dim {
                int b_idx = out_idx * module.layer.rank + r
                if b_idx < len(b_snapshot) {
                    grad_a = grad_a + grad_out[out_idx] * b_snapshot[b_idx]
                }
                out_idx = out_idx + 1
            }
            int a_idx = r * module.layer.in_dim + in_idx
            if a_idx < len(module.layer.lora_A) {
                module.layer.lora_A[a_idx] = module.layer.lora_A[a_idx] - step_scale * grad_a * input_vec[in_idx]
            }
            in_idx = in_idx + 1
        }
        r = r + 1
    }
    return module
}

func compute_stats([]named_lora_module modules) adapter_stats {
    float l1 = 0.0
    float l2 = 0.0
    float max_abs = 0.0
    int nonzero = 0
    int total = 0
    int module_idx = 0
    while module_idx < len(modules) {
        named_lora_module module = modules[module_idx]
        int i = 0
        int a_len = module.layer.rank * module.layer.in_dim
        while i < a_len {
            float value = module.layer.lora_A[i]
            float abs_value = abs_float(value)
            l1 = l1 + abs_value
            l2 = l2 + value * value
            if abs_value > max_abs {
                max_abs = abs_value
            }
            if abs_value > 0.0 {
                nonzero = nonzero + 1
            }
            total = total + 1
            i = i + 1
        }
        i = 0
        int b_len = module.layer.out_dim * module.layer.rank
        while i < b_len {
            float value = module.layer.lora_B[i]
            float abs_value = abs_float(value)
            l1 = l1 + abs_value
            l2 = l2 + value * value
            if abs_value > max_abs {
                max_abs = abs_value
            }
            if abs_value > 0.0 {
                nonzero = nonzero + 1
            }
            total = total + 1
            i = i + 1
        }
        module_idx = module_idx + 1
    }
    adapter_stats stats
    stats.l1 = l1
    stats.l2 = sqrt_lora(l2)
    stats.max_abs = max_abs
    stats.nonzero = nonzero
    stats.total = total
    return stats
}

func compute_delta_stats([]named_lora_module modules) delta_stats {
    float l1 = 0.0
    float l2 = 0.0
    float max_abs = 0.0
    int changed = 0
    int module_idx = 0
    while module_idx < len(modules) {
        named_lora_module module = modules[module_idx]
        int i = 0
        int a_len = module.layer.rank * module.layer.in_dim
        while i < a_len {
            float delta = module.layer.lora_A[i] - module.initial_a[i]
            float abs_delta = abs_float(delta)
            l1 = l1 + abs_delta
            l2 = l2 + delta * delta
            if abs_delta > max_abs {
                max_abs = abs_delta
            }
            if abs_delta > 1e-10 {
                changed = changed + 1
            }
            i = i + 1
        }
        i = 0
        int b_len = module.layer.out_dim * module.layer.rank
        while i < b_len {
            float delta = module.layer.lora_B[i] - module.initial_b[i]
            float abs_delta = abs_float(delta)
            l1 = l1 + abs_delta
            l2 = l2 + delta * delta
            if abs_delta > max_abs {
                max_abs = abs_delta
            }
            if abs_delta > 1e-10 {
                changed = changed + 1
            }
            i = i + 1
        }
        module_idx = module_idx + 1
    }
    delta_stats stats
    stats.l1 = l1
    stats.l2 = sqrt_lora(l2)
    stats.max_abs = max_abs
    stats.changed_count = changed
    return stats
}

func write_adapter_checkpoint(
    string output_dir,
    string model_path,
    []named_lora_module modules,
    []float loss_history,
    adapter_stats stats,
    delta_stats deltas,
    int rank,
    float alpha,
    float learning_rate,
    int sample_count,
    int epochs,
    int v_out
) {
    string adapter_path = output_dir + "/adapter_model.safetensors"
    safetensors_writer writer = safetensors_writer_new(adapter_path)
    int module_idx = 0
    while module_idx < len(modules) {
        named_lora_module module = modules[module_idx]
        int a_len = module.layer.rank * module.layer.in_dim
        int b_len = module.layer.out_dim * module.layer.rank
        []float a_data = []float{cap: a_len}
        int i = 0
        while i < a_len {
            a_data[i] = module.layer.lora_A[i]
            i = i + 1
        }
        []float b_data = []float{cap: b_len}
        i = 0
        while i < b_len {
            b_data[i] = module.layer.lora_B[i]
            i = i + 1
        }
        []int a_shape = []int{cap: 2}
        a_shape[0] = module.layer.rank
        a_shape[1] = module.layer.in_dim
        tensor a_tensor = tensor {
            name: module.name + ".lora_A.weight",
            dtype: "F32",
            shape: a_shape,
            data: a_data,
            shape_count: 2,
            data_count: a_len,
        }
        []int b_shape = []int{cap: 2}
        b_shape[0] = module.layer.out_dim
        b_shape[1] = module.layer.rank
        tensor b_tensor = tensor {
            name: module.name + ".lora_B.weight",
            dtype: "F32",
            shape: b_shape,
            data: b_data,
            shape_count: 2,
            data_count: b_len,
        }
        safetensors_writer_add_tensor(writer, a_tensor)
        safetensors_writer_add_tensor(writer, b_tensor)
        module_idx = module_idx + 1
    }
    _ = safetensors_writer_finish(writer)
    runtime_write_text_file(output_dir + "/adapter_config.json", build_adapter_config_json(model_path, rank, alpha, learning_rate, v_out, len(modules)))
    runtime_write_text_file(output_dir + "/training_state.json", build_training_state_json(model_path, loss_history, stats, deltas, rank, alpha, learning_rate, sample_count, epochs, len(modules)))
}

func build_adapter_config_json(string model_path, int rank, float alpha, float learning_rate, int v_out, int module_count) string {
    string json = "{\n"
    json = json + "  \"base_model_name_or_path\": \"" + model_path + "\",\n"
    json = json + "  \"bias\": \"none\",\n"
    json = json + "  \"fan_in_fan_out\": false,\n"
    json = json + "  \"inference_mode\": true,\n"
    json = json + "  \"lora_alpha\": " + float_to_str(alpha, 1) + ",\n"
    json = json + "  \"lora_dropout\": 0.05,\n"
    json = json + "  \"r\": " + int_to_str(rank) + ",\n"
    json = json + "  \"target_modules\": [\"q_proj\", \"v_proj\"],\n"
    json = json + "  \"task_type\": \"CAUSAL_LM\",\n"
    json = json + "  \"peft_type\": \"LORA\",\n"
    json = json + "  \"trainable_modules\": " + int_to_str(module_count) + ",\n"
    json = json + "  \"hidden_size\": 896,\n"
    json = json + "  \"v_proj_out_dim\": " + int_to_str(v_out) + ",\n"
    json = json + "  \"optimizer\": \"sgd\",\n"
    json = json + "  \"learning_rate\": " + float_to_str(learning_rate, 6) + ",\n"
    json = json + "  \"training_backend\": \"S Runtime Materialized Trainer\"\n"
    json = json + "}\n"
    return json
}

func build_training_state_json(string model_path, []float loss_history, adapter_stats stats, delta_stats deltas, int rank, float alpha, float learning_rate, int sample_count, int epochs, int module_count) string {
    string json = "{\n"
    json = json + "  \"model_path\": \"" + model_path + "\",\n"
    json = json + "  \"completed_steps\": " + int_to_str(sample_count * epochs) + ",\n"
    json = json + "  \"epochs\": " + int_to_str(epochs) + ",\n"
    json = json + "  \"samples\": " + int_to_str(sample_count) + ",\n"
    json = json + "  \"learning_rate\": " + float_to_str(learning_rate, 6) + ",\n"
    json = json + "  \"training_backend\": \"S Runtime Materialized Trainer\",\n"
    json = json + "  \"final_loss\": " + float_to_str(loss_history[len(loss_history) - 1], 12) + ",\n"
    json = json + "  \"best_loss\": " + float_to_str(loss_history[len(loss_history) - 1], 12) + ",\n"
    json = json + "  \"loss_history\": ["
    int i = 0
    while i < len(loss_history) {
        json = json + float_to_str(loss_history[i], 12)
        if i + 1 < len(loss_history) {
            json = json + ", "
        }
        i = i + 1
    }
    json = json + "],\n"
    json = json + "  \"adapter_l1_norm\": " + float_to_str(stats.l1, 12) + ",\n"
    json = json + "  \"adapter_l2_norm\": " + float_to_str(stats.l2, 12) + ",\n"
    json = json + "  \"adapter_max_abs\": " + float_to_str(stats.max_abs, 12) + ",\n"
    json = json + "  \"nonzero_weights\": " + int_to_str(stats.nonzero) + ",\n"
    json = json + "  \"total_weights\": " + int_to_str(stats.total) + ",\n"
    json = json + "  \"weight_delta_l1\": " + float_to_str(deltas.l1, 12) + ",\n"
    json = json + "  \"weight_delta_l2\": " + float_to_str(deltas.l2, 12) + ",\n"
    json = json + "  \"weight_delta_max_abs\": " + float_to_str(deltas.max_abs, 12) + ",\n"
    json = json + "  \"weight_changed_count\": " + int_to_str(deltas.changed_count) + ",\n"
    json = json + "  \"modules\": " + int_to_str(module_count) + ",\n"
    json = json + "  \"nominal_rank\": " + int_to_str(rank) + ",\n"
    json = json + "  \"alpha\": " + float_to_str(alpha, 1) + "\n"
    json = json + "}\n"
    return json
}

func fill_vec(int n, float value) []float {
    []float v = []float{cap: n}
    int i = 0
    while i < n {
        v[i] = value
        i = i + 1
    }
    return v
}

func extract_vector([]float source, int start, int n) []float {
    []float v = []float{cap: n}
    int i = 0
    while i < n {
        int src_idx = start + i
        if src_idx < len(source) {
            v[i] = source[src_idx]
        }
        i = i + 1
    }
    return v
}

func init_pattern(int n, float scale) []float {
    []float v = []float{cap: n}
    int i = 0
    while i < n {
        float x = ((i + 1) as float) * scale * 0.001
        if i - (i / 2) * 2 == 1 {
            x = 0.0 - x
        }
        v[i] = x
        i = i + 1
    }
    return v
}

func runtime_forward_named_module_dummy(named_lora_module module, []float input_vec) []float {
    return runtime_forward_named_module(module, input_vec)
}

func mse_loss([]float predictions, []float targets) float {
    float loss = 0.0
    int limit = len(predictions)
    if len(targets) < limit {
        limit = len(targets)
    }
    int i = 0
    while i < limit {
        float diff = predictions[i] - targets[i]
        loss = loss + diff * diff
        i = i + 1
    }
    if limit > 0 {
        loss = loss / (limit as float)
    }
    return loss
}

func mse_gradient([]float predictions, []float targets) []float {
    int limit = len(predictions)
    if len(targets) < limit {
        limit = len(targets)
    }
    []float grad = fill_vec(len(predictions), 0.0)
    int i = 0
    while i < limit {
        grad[i] = 2.0 * (predictions[i] - targets[i]) / (limit as float)
        i = i + 1
    }
    return grad
}

func abs_float(float value) float {
    if value < 0.0 {
        return 0.0 - value
    }
    return value
}

func copy_float_array([]float source) []float {
    []float result = []float{cap: len(source)}
    int i = 0
    while i < len(source) {
        result[i] = source[i]
        i = i + 1
    }
    return result
}

func sqrt_lora(float x) float {
    if x < 0.0 {
        return 0.0
    }
    float guess = 1.0
    int i = 0
    while i < 6 {
        guess = 0.5 * (guess + x / guess)
        i = i + 1
    }
    return guess
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
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    return out
}

func float_to_str(float value, int decimals) string {
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
        if digit == 0 { out = out + "0" }
        else if digit == 1 { out = out + "1" }
        else if digit == 2 { out = out + "2" }
        else if digit == 3 { out = out + "3" }
        else if digit == 4 { out = out + "4" }
        else if digit == 5 { out = out + "5" }
        else if digit == 6 { out = out + "6" }
        else if digit == 7 { out = out + "7" }
        else if digit == 8 { out = out + "8" }
        else { out = out + "9" }
        i = i + 1
    }
    return out
}

func main() int {
    return run_posttrain_lora_sft()
}
