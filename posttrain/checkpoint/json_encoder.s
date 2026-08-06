package neurx.posttrain.checkpoint.json_encoder
func trainer_state_to_json(
    int version,
    int step,
    int epoch,
    int global_tokens,
    int samples_seen,
    float best_loss,
    float last_loss,
    float wall_time,
    int last_checkpoint_step
) string {
    string json = "{\n"
    json = json + "  \"version\": " + int_to_str(version) + ",\n"
    json = json + "  \"step\": " + int_to_str(step) + ",\n"
    json = json + "  \"epoch\": " + int_to_str(epoch) + ",\n"
    json = json + "  \"global_tokens\": " + int_to_str(global_tokens) + ",\n"
    json = json + "  \"samples_seen\": " + int_to_str(samples_seen) + ",\n"
    json = json + "  \"best_loss\": " + float_to_str(best_loss) + ",\n"
    json = json + "  \"last_loss\": " + float_to_str(last_loss) + ",\n"
    json = json + "  \"wall_time\": " + float_to_str(wall_time) + ",\n"
    json = json + "  \"last_checkpoint_step\": " + int_to_str(last_checkpoint_step) + "\n"
    json = json + "}"
    return json
}
func scheduler_state_to_json(
    int version,
    int step,
    int warmup_steps,
    float max_lr,
    float min_lr,
    string schedule_type
) string {
    string json = "{\n"
    json = json + "  \"version\": " + int_to_str(version) + ",\n"
    json = json + "  \"step\": " + int_to_str(step) + ",\n"
    json = json + "  \"warmup_steps\": " + int_to_str(warmup_steps) + ",\n"
    json = json + "  \"max_lr\": " + float_to_str(max_lr) + ",\n"
    json = json + "  \"min_lr\": " + float_to_str(min_lr) + ",\n"
    json = json + "  \"schedule_type\": \"" + schedule_type + "\"\n"
    json = json + "}"
    return json
}
func optimizer_state_to_json(
    int version,
    string optimizer_type,
    int step,
    int num_layers,
    int params_per_layer
) string {
    string json = "{\n"
    json = json + "  \"version\": " + int_to_str(version) + ",\n"
    json = json + "  \"optimizer_type\": \"" + optimizer_type + "\",\n"
    json = json + "  \"step\": " + int_to_str(step) + ",\n"
    json = json + "  \"num_layers\": " + int_to_str(num_layers) + ",\n"
    json = json + "  \"params_per_layer\": " + int_to_str(params_per_layer) + "\n"
    json = json + "}"
    return json
}
func training_config_to_json(
    string model_name,
    string dataset,
    int batch_size,
    float learning_rate,
    int num_epochs,
    int lora_rank,
    float lora_alpha
) string {
    string json = "{\n"
    json = json + "  \"model_name\": \"" + model_name + "\",\n"
    json = json + "  \"dataset\": \"" + dataset + "\",\n"
    json = json + "  \"batch_size\": " + int_to_str(batch_size) + ",\n"
    json = json + "  \"learning_rate\": " + float_to_str(learning_rate) + ",\n"
    json = json + "  \"num_epochs\": " + int_to_str(num_epochs) + ",\n"
    json = json + "  \"lora_rank\": " + int_to_str(lora_rank) + ",\n"
    json = json + "  \"lora_alpha\": " + float_to_str(lora_alpha) + "\n"
    json = json + "}"
    return json
}
func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    string out = ""
    if value < 0 {
        negative = true
        value = 0 - value
    }
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
    if negative { out = "-" + out }
    return out
}
func float_to_str(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string result = int_to_str(whole)
    result = result + "."
    int i = 0
    while i < 8 {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }
    if negative { result = "-" + result }
    return result
}
