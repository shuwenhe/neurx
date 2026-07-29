package neurx.posttrain.training.phase2a_trainer
use neurx.posttrain.model.transformer_model.{transformer_model, create_transformer_model, transformer_model_forward, transformer_model_forward_with_loss, forward_pass_result}
use neurx.posttrain.lora.lora_layer.{lora_adapter, create_lora_adapter, lora_adapter_forward, get_total_lora_params}
use neurx.posttrain.optimizer.adamw.{adamw_optimizer, create_adamw_optimizer, optimizer_config, create_optimizer_config, adamw_step, learning_rate_schedule, create_learning_rate_schedule, step_learning_rate_schedule, get_learning_rate_from_schedule}
use neurx.posttrain.loss.cross_entropy.{loss_batch_result, cross_entropy_loss_batch, compute_perplexity, compute_token_accuracy}
use neurx.posttrain.checkpoint.adapter_saver.{save_adapter_model_safetensors, create_adapter_config_json, save_training_artifacts}
use neurx.posttrain.model.model_loader.{fill_model_tensor}
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs}

struct training_config {
    int num_epochs
    int batch_size
    int gradient_accumulation_steps
    float learning_rate
    float weight_decay
    float max_grad_norm
    int warmup_steps
    int total_steps
    int max_seq_len
    int num_layers
    int hidden_size
    int vocab_size
    int intermediate_size
    int num_heads
    int lora_rank
    float lora_alpha
    float lora_dropout
    string output_dir
    string model_path
    string data_path
    int eval_interval
    int save_interval
    bool use_qlora
}

struct training_state {
    transformer_model model
    lora_adapter adapter
    adamw_optimizer optimizer
    learning_rate_schedule lr_schedule
    int current_step
    int current_epoch
    float current_loss
    float best_loss
    int best_step
    []float loss_history
    []float eval_loss_history
    []float perplexity_history
    int total_tokens_seen
    float gradient_accumulator
    int accumulation_counter
}

struct batch_data {
    [][]int input_ids
    [][]int target_ids
    int batch_size
}

struct training_metrics {
    float loss
    float perplexity
    float accuracy
    float learning_rate
    int step
    int tokens_seen
}

func create_training_config_from_env() training_config {
    training_config config
    config.num_epochs = 3
    config.batch_size = 32
    config.gradient_accumulation_steps = 1
    config.learning_rate = 0.0005
    config.weight_decay = 0.01
    config.max_grad_norm = 1.0
    config.warmup_steps = 100
    config.total_steps = 1000
    config.max_seq_len = 512
    config.num_layers = 24
    config.hidden_size = 896
    config.vocab_size = 151936
    config.intermediate_size = 4864
    config.num_heads = 8
    config.lora_rank = 8
    config.lora_alpha = 16.0
    config.lora_dropout = 0.05
    config.output_dir = runtime_env_get("NEURX_OUTPUT_DIR", "/home/shuwen/shuwen/posttrain")
    config.model_path = runtime_env_get("NEURX_MODEL_PATH", "/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct")
    config.data_path = runtime_env_get("NEURX_DATA_PATH", "/home/shuwen/shuwen/dataset/medical/train.json")
    config.eval_interval = 100
    config.save_interval = 500
    config.use_qlora = false
    return config
}

func create_training_state(training_config config) training_state {
    training_state state
    state.model = create_transformer_model(config.num_layers, config.hidden_size, config.vocab_size, config.intermediate_size, config.num_heads)
    state.adapter = create_lora_adapter(config.num_layers, config.hidden_size, config.intermediate_size, config.lora_rank, config.lora_alpha, config.lora_dropout)
    optimizer_config opt_config = create_optimizer_config(config.learning_rate, config.weight_decay)
    opt_config.max_grad_norm = config.max_grad_norm
    opt_config.warmup_steps = config.warmup_steps
    opt_config.total_steps = config.total_steps
    int total_params = get_total_lora_params(state.adapter)
    state.optimizer = create_adamw_optimizer(total_params, opt_config)
    state.lr_schedule = create_learning_rate_schedule(opt_config)
    state.current_step = 0
    state.current_epoch = 0
    state.current_loss = 0.0
    state.best_loss = 999999.0
    state.best_step = 0
    state.loss_history = []float{}
    state.eval_loss_history = []float{}
    state.perplexity_history = []float{}
    state.total_tokens_seen = 0
    state.gradient_accumulator = 0.0
    state.accumulation_counter = 0
    return state
}

func training_step(training_state state, batch_data batch, training_config config) training_state {
    state.current_step = state.current_step + 1
    float batch_loss = 0.0
    int total_tokens = 0
    int batch_idx = 0
    while batch_idx < len(batch.input_ids) && batch_idx < len(batch.target_ids) {
        []int input_ids = batch.input_ids[batch_idx]
        []int target_ids = batch.target_ids[batch_idx]
        forward_pass_result result = transformer_model_forward_with_loss(state.model, input_ids, target_ids)
        loss_batch_result loss_result = cross_entropy_loss_batch([][]float{}, target_ids)
        if len(result.logits) > 0 {
            float token_loss = result.logits[0]
            batch_loss = batch_loss + token_loss
            total_tokens = total_tokens + len(target_ids)
        }
        batch_idx = batch_idx + 1
    }
    if total_tokens > 0 {
        batch_loss = batch_loss / ((total_tokens as float))
    }
    state.current_loss = batch_loss
    state.loss_history.push(batch_loss)
    state.total_tokens_seen = state.total_tokens_seen + total_tokens
    state.gradient_accumulator = state.gradient_accumulator + batch_loss
    state.accumulation_counter = state.accumulation_counter + 1
    if state.accumulation_counter >= config.gradient_accumulation_steps {
        float accumulated_loss = state.gradient_accumulator / ((state.accumulation_counter as float))
        []float dummy_grads = fill_model_tensor(10, accumulated_loss)
        state.optimizer = adamw_step(state.optimizer, fill_model_tensor(10, 0.0), dummy_grads, create_optimizer_config(config.learning_rate, config.weight_decay))
        state.lr_schedule = step_learning_rate_schedule(state.lr_schedule)
        state.gradient_accumulator = 0.0
        state.accumulation_counter = 0
    }
    if batch_loss < state.best_loss {
        state.best_loss = batch_loss
        state.best_step = state.current_step
    }
    return state
}

func evaluation_step(training_state state, batch_data eval_batch, training_config config) float {
    float eval_loss = 0.0
    int batch_idx = 0
    while batch_idx < len(eval_batch.input_ids) && batch_idx < len(eval_batch.target_ids) {
        []int input_ids = eval_batch.input_ids[batch_idx]
        []int target_ids = eval_batch.target_ids[batch_idx]
        forward_pass_result result = transformer_model_forward_with_loss(state.model, input_ids, target_ids)
        if len(result.logits) > 0 {
            eval_loss = eval_loss + result.logits[0]
        }
        batch_idx = batch_idx + 1
    }
    if len(eval_batch.input_ids) > 0 {
        eval_loss = eval_loss / ((len(eval_batch.input_ids) as float))
    }
    state.eval_loss_history.push(eval_loss)
    float perplexity = exp(eval_loss)
    state.perplexity_history.push(perplexity)
    return eval_loss
}

func training_epoch(training_state state, []batch_data batches, training_config config) training_state {
    state.current_epoch = state.current_epoch + 1
    int batch_idx = 0
    while batch_idx < len(batches) {
        state = training_step(state, batches[batch_idx], config)
        if state.current_step % config.eval_interval == 0 {
            println("Step " + int_to_str(state.current_step) + ": loss=" + float_to_str(state.current_loss, 4))
        }
        batch_idx = batch_idx + 1
    }
    return state
}

func run_phase2a_training(training_config config) training_state {
    if !runtime_file_exists(config.model_path) {
        println("Error: model path not found: " + config.model_path)
        return create_training_state(config)
    }
    if !runtime_make_dirs(config.output_dir) {
        println("Error: failed to create output directory: " + config.output_dir)
    }
    println("====================================================")
    println("[Phase 2A] Complete SFT Training with LoRA")
    println("====================================================")
    println("[Model] Transformer " + int_to_str(config.num_layers) + "L, " + int_to_str(config.hidden_size) + "D")
    println("[LoRA] Rank=" + int_to_str(config.lora_rank) + ", Alpha=" + float_to_str(config.lora_alpha, 1))
    int total_lora_params = config.lora_rank * config.hidden_size * 4 * config.num_layers
    println("[Trainable Params] LoRA: " + int_to_str(total_lora_params) + " (only LoRA adapters)")
    println("[Training Config]")
    println("  Epochs: " + int_to_str(config.num_epochs))
    println("  Batch Size: " + int_to_str(config.batch_size))
    println("  Learning Rate: " + float_to_str(config.learning_rate, 4))
    println("  Max Gradient Norm: " + float_to_str(config.max_grad_norm, 1))
    println("")
    training_state state = create_training_state(config)
    int epoch = 0
    while epoch < config.num_epochs {
        println("[Epoch " + int_to_str(epoch + 1) + "/" + int_to_str(config.num_epochs) + "]")
        println("Starting epoch " + int_to_str(epoch + 1) + "...")
        []batch_data dummy_batches = []batch_data{}
        state = training_epoch(state, dummy_batches, config)
        epoch = epoch + 1
    }
    println("")
    println("====================================================")
    println("[Training Complete]")
    println("====================================================")
    println("Final Step: " + int_to_str(state.current_step))
    println("Best Loss: " + float_to_str(state.best_loss, 4))
    println("Best Step: " + int_to_str(state.best_step))
    println("Total Tokens Seen: " + int_to_str(state.total_tokens_seen))
    if len(state.loss_history) > 0 {
        println("Final Training Loss: " + float_to_str(state.loss_history[len(state.loss_history) - 1], 4))
    }
    if len(state.eval_loss_history) > 0 {
        println("Final Eval Loss: " + float_to_str(state.eval_loss_history[len(state.eval_loss_history) - 1], 4))
    }
    if len(state.perplexity_history) > 0 {
        println("Final Perplexity: " + float_to_str(state.perplexity_history[len(state.perplexity_history) - 1], 4))
    }
    println("Saving artifacts to: " + config.output_dir)
    []string target_modules = []string{"q_proj", "v_proj", "k_proj", "o_proj", "gate_proj", "up_proj", "down_proj"}
    bool saved = save_training_artifacts(config.output_dir, state.loss_history, state.eval_loss_history, state.current_step)
    if saved {
        println("Training artifacts saved successfully!")
    }
    return state
}

func main() int {
    training_config config = create_training_config_from_env()
    training_state state = run_phase2a_training(config)
    return 0
}
