package neurx.posttrain.trainer
use neurx.runtime.io.{runtime_env_get, trim}

struct trainer_factory {
    trainer_type selected_type
}

func create_trainer_factory(trainer_type ttype) trainer_factory {
    trainer_factory factory
    factory.selected_type = ttype
    return factory
}

func factory_get_trainer_type(trainer_factory factory) trainer_type {
    return factory.selected_type
}

func factory_is_reference(trainer_factory factory) bool {
    return factory.selected_type == 0
}

func factory_is_runtime(trainer_factory factory) bool {
    return factory.selected_type == 1
}

func select_trainer_for_config(trainer_config config) trainer_type {
    string forced_backend = trim(runtime_env_get("NEURX_POSTTRAIN_BACKEND", "runtime"))
    if forced_backend == "reference" || forced_backend == "sim" || forced_backend == "simulation" {
        return 0
    }
    return 1
}

func validate_trainer_config(trainer_config config) int {
    if len(config.model_path) == 0 {
        println("error: model_path is required")
        return 1
    }
    if len(config.data_file) == 0 {
        println("error: data_file is required")
        return 2
    }
    if len(config.output_dir) == 0 {
        println("error: output_dir is required")
        return 3
    }
    if config.rank <= 0 || config.rank > 256 {
        println("error: rank must be in range (0, 256]")
        return 4
    }
    if config.alpha <= 0.0 {
        println("error: alpha must be positive")
        return 5
    }
    if config.learning_rate <= 0.0 {
        println("error: learning_rate must be positive")
        return 6
    }
    if config.total_steps <= 0 {
        println("error: total_steps must be positive")
        return 7
    }
    return 0
}

func create_config(
    string model_path,
    string data_file,
    string output_dir,
    int rank,
    float alpha,
    float learning_rate,
    int total_steps
) trainer_config {
    trainer_config config
    config.model_path = model_path
    config.data_file = data_file
    config.output_dir = output_dir
    config.seq_len = 128
    config.hidden_size = 896
    config.vocab_size = 151936
    config.num_layers = 24
    config.rank = rank
    config.alpha = alpha
    config.dropout_rate = 0.05
    config.target_modules = "q_proj,v_proj"
    config.learning_rate = learning_rate
    config.weight_decay = 0.01
    config.max_grad_norm = 1.0
    config.batch_size = 1
    config.num_epochs = 3
    config.warmup_steps = 0
    config.total_steps = total_steps
    config.global_rank = 0
    config.world_size = 1
    config.dp_degree = 1
    config.use_qlora = false
    config.qlora_dtype = "nf4"
    return config
}

func describe_config(trainer_config config) int {
    println("====================================================")
    println("[Trainer Configuration]")
    println("====================================================")
    println("[Paths]")
    println("  Model:        " + config.model_path)
    println("  Data:         " + config.data_file)
    println("  Output:       " + config.output_dir)
    println("")
    println("[LoRA]")
    println("  Rank:         " + int_to_str(config.rank))
    println("  Alpha:        " + float_to_str(config.alpha, 1))
    println("  Modules:      " + config.target_modules)
    println("  Dropout:      " + float_to_str(config.dropout_rate, 2))
    println("")
    println("[Model]")
    println("  Hidden size:  " + int_to_str(config.hidden_size))
    println("  Num layers:   " + int_to_str(config.num_layers))
    println("  Vocab size:   " + int_to_str(config.vocab_size))
    println("  Seq len:      " + int_to_str(config.seq_len))
    println("")
    println("[Training]")
    println("  Learning rate:" + float_to_str(config.learning_rate, 6))
    println("  Weight decay: " + float_to_str(config.weight_decay, 2))
    println("  Max grad norm:" + float_to_str(config.max_grad_norm, 1))
    println("  Batch size:   " + int_to_str(config.batch_size))
    println("  Num epochs:   " + int_to_str(config.num_epochs))
    println("  Total steps:  " + int_to_str(config.total_steps))
    println("")
    return 0
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    string result = ""
    bool negative = false
    if n < 0 {
        negative = true
        n = 0 - n
    }
    []string digits = []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
    for n > 0 {
        int digit = n - (n / 10) * 10
        result = digits[digit] + result
        n = n / 10
    }
    if negative {
        result = "-" + result
    }
    return result
}

func float_to_str(float f, int precision) string {
    int int_part = f as int
    float frac_part = f - (int_part as float)
    if frac_part < 0.0 {
        frac_part = 0.0 - frac_part
    }
    string result = int_to_str(int_part) + "."
    int i = 0
    for i < precision {
        frac_part = frac_part * 10.0
        int digit = frac_part as int
        result = result + int_to_str(digit)
        frac_part = frac_part - (digit as float)
        i = i + 1
    }
    return result
}
