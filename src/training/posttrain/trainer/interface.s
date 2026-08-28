package neurx.posttrain.trainer
struct trainer_config {
    string model_path
    string data_file
    string output_dir
    int seq_len
    int hidden_size
    int vocab_size
    int num_layers
    int rank
    float alpha
    float dropout_rate
    string target_modules
    float learning_rate
    float weight_decay
    float max_grad_norm
    int batch_size
    int num_epochs
    int warmup_steps
    int total_steps
    int global_rank
    int world_size
    int dp_degree
    bool use_qlora
    string qlora_dtype
}

struct trainer_state {
    int step
    int epoch
    float current_loss
    float best_loss
    float[] lora_q_a
    float[] lora_q_b
    float[] lora_v_a
    float[] lora_v_b
    int q_a_len
    int q_b_len
    int v_a_len
    int v_b_len
}

struct adapter_stats {
    float l1_norm
    float l2_norm
    float max_absolute
    int nonzero_weights
    int total_weights
}

struct weight_delta_stats {
    float l1_delta
    float l2_delta
    float max_delta
    int changed_elements
    int total_elements
}

struct loss_stats {
    float initial_loss
    float final_loss
    float best_loss
    float improvement_percent
}

struct trainer_report {
    adapter_stats adapter
    weight_delta_stats delta
    loss_stats loss
}
interface trainer {
    func step(trainer_config config, trainer_state state, string[] batch_data) trainer_state
    func save_adapter(trainer_state state, string output_dir) int
    func get_stats(trainer_state state) trainer_report
    func initialize(trainer_config config) trainer_state
}
    REFERENCE
    RUNTIME
}

func create_trainer(trainer_type ttype) int {
    return 0
}
