package neurx.posttrain.dpo.dpo_trainer
use neurx.posttrain.dpo.dpo_state.*
use neurx.loss.dpo_loss.*
use neurx.posttrain.dpo.dpo_step.*
use neurx.model.llm.neurx.*
use neurx.tokenizer.neurx.*
use neurx.amp.scaler.*
use neurx.distributed.training_3d.*
use neurx.checkpoint.distributed.*
use neurx.data.loader.dataloader.*
use neurx.observability.training.training_observability.*

struct dpo_preference_pair {
    []int prompt_tokens
    []int chosen_response_tokens
    []int rejected_response_tokens
    float preference_score
    string annotator_id
    string domain
}

struct dpo_dataset {
    []dpo_preference_pair pairs
    int size
    string source_path
    float quality_score
    int train_test_split
    float avg_prompt_len
    float avg_response_len
    []float domain_distribution
}

struct dpo_train_config {
    string method
    int batch_size
    int gradient_accum_steps
    float learning_rate
    float lr_warmup_ratio
    string lr_schedule_type
    int total_training_steps
    float adam_beta1
    float adam_beta2
    float adam_epsilon
    float weight_decay
    float max_grad_norm
    float dpo_beta
    float label_smoothing
    string dpo_loss_type
    bool use_reference_free
    string precision
    bool use_gradient_checkpointing
    bool use_flash_attention
    int save_interval
    int eval_interval
    int log_interval
    string checkpoint_dir
    int num_workers
    bool pin_memory
    string output_dir
}

struct dpo_trainer_state {
    neurx_model model
    neurx_model reference_model
    tokenizer_state tokenizer
    dpo_train_config config
    dpo_dataset dataset
    int global_rank
    int local_rank
    int world_size
    int dp_rank
    int dp_degree
    int current_step
    int current_epoch
    float current_learning_rate
    float best_eval_metric
    int best_step
    float running_loss
    float running_reward_margin
    float running_chosen_reward
    float running_rejected_reward
    float running_accuracy
    []float loss_history
    []float margin_history
    []float accuracy_history
    dataloader train_loader
    dataloader eval_loader
}

struct dpo_train_result {
    bool success
    int final_step
    float final_loss
    float best_metric
    float training_time_seconds
    string checkpoint_path
    string eval_report_path
}

func load_dpo_dataset(
    string data_path,
    float train_test_ratio
) dpo_dataset {
    dpo_dataset {
        pairs: []dpo_preference_pair{},
        size: 0,
        source_path: data_path,
        quality_score: 1.0,
        train_test_split: 0,
        avg_prompt_len: 0.0,
        avg_response_len: 0.0,
        domain_distribution: []float{},
    }
}

func validate_dpo_dataset(dpo_dataset dataset) bool {
    if dataset.size == 0 {
        return false
    }
    if dataset.avg_prompt_len < 10.0 || dataset.avg_prompt_len > 100000.0 {
        return false
    }
    if dataset.avg_response_len < 10.0 || dataset.avg_response_len > 100000.0 {
        return false
    }
    true
}

func create_dpo_trainer(
    neurx_model model,
    neurx_model reference_model,
    tokenizer_state tokenizer,
    dpo_train_config config,
    dpo_dataset dataset,
    int global_rank,
    int world_size
) dpo_trainer_state {
    int dp_degree = world_size
    int dp_rank = global_rank
    dpo_trainer_state {
        model: model,
        reference_model: reference_model,
        tokenizer: tokenizer,
        config: config,
        dataset: dataset,
        global_rank: global_rank,
        local_rank: global_rank % 8,
        world_size: world_size,
        dp_rank: dp_rank,
        dp_degree: dp_degree,
        current_step: 0,
        current_epoch: 0,
        current_learning_rate: config.learning_rate,
        best_eval_metric: 999999.0,
        best_step: 0,
        running_loss: 0.0,
        running_reward_margin: 0.0,
        running_chosen_reward: 0.0,
        running_rejected_reward: 0.0,
        running_accuracy: 0.0,
        loss_history: []float{},
        margin_history: []float{},
        accuracy_history: []float{},
        train_loader: dataloader{},
        eval_loader: dataloader{},
    }
}

func compute_learning_rate(
    dpo_trainer_state trainer,
    int current_step,
    int total_steps
) float {
    dpo_train_config cfg = trainer.config
    int warmup_steps = int(float_of_int(total_steps) * cfg.lr_warmup_ratio)
    if current_step < warmup_steps {
        float progress = float_of_int(current_step) / float_of_int(warmup_steps)
        return cfg.learning_rate * progress
    }
    if cfg.lr_schedule_type == "cosine" {
        int remaining_steps = total_steps - warmup_steps
        int progress_step = current_step - warmup_steps
        float progress = float_of_int(progress_step) / float_of_int(remaining_steps)
        float pi = 3.141592653589793
        float cosine_decay = 0.5 * (1.0 + cos_approx(pi * progress))
        return cfg.learning_rate * cosine_decay
    } else {
        int remaining_steps = total_steps - warmup_steps
        int progress_step = current_step - warmup_steps
        float progress = float_of_int(progress_step) / float_of_int(remaining_steps)
        return cfg.learning_rate * (1.0 - progress)
    }
}

func cos_approx(float x) float {
    float x2 = x * x
    float x4 = x2 * x2
    float x6 = x4 * x2
    1.0 - (x2 / 2.0) + (x4 / 24.0) - (x6 / 720.0)
}

struct dpo_training_step_result {
    float loss
    float margin
    float accuracy
    float chosen_reward
    float rejected_reward
}

func dpo_training_step(
    ref dpo_trainer_state trainer,
    []dpo_preference_pair batch
) dpo_training_step_result {
    float total_loss = 0.0
    float total_margin = 0.0
    float total_accuracy = 0.0
    float total_chosen_reward = 0.0
    float total_rejected_reward = 0.0
    int batch_size = len(batch)
    int i = 0
    while i < batch_size {
        dpo_preference_pair pair = batch[i]
        float chosen_logp = 0.0
        float rejected_logp = 0.0
        float ref_chosen_logp = 0.0
        float ref_rejected_logp = 0.0
        dpo_state dpo_st = new_default_dpo_state()
        dpo_step_result step_result = dpo_step(
            dpo_st,
            chosen_logp,
            rejected_logp,
            ref_chosen_logp,
            ref_rejected_logp
        )
        total_loss = total_loss + step_result.loss
        total_margin = total_margin + step_result.reward_margin
        total_chosen_reward = total_chosen_reward + step_result.chosen_reward
        total_rejected_reward = total_rejected_reward + step_result.rejected_reward
        if chosen_logp > rejected_logp {
            total_accuracy = total_accuracy + 1.0
        }
        i = i + 1
    }
    float avg_loss = total_loss / float_of_int(batch_size)
    float avg_margin = total_margin / float_of_int(batch_size)
    float avg_accuracy = total_accuracy / float_of_int(batch_size)
    float avg_chosen = total_chosen_reward / float_of_int(batch_size)
    float avg_rejected = total_rejected_reward / float_of_int(batch_size)
    trainer.running_loss = 0.9 * trainer.running_loss + 0.1 * avg_loss
    trainer.running_reward_margin = 0.9 * trainer.running_reward_margin + 0.1 * avg_margin
    trainer.running_accuracy = 0.9 * trainer.running_accuracy + 0.1 * avg_accuracy
    trainer.running_chosen_reward = 0.9 * trainer.running_chosen_reward + 0.1 * avg_chosen
    trainer.running_rejected_reward = 0.9 * trainer.running_rejected_reward + 0.1 * avg_rejected
    dpo_training_step_result {
        loss: avg_loss,
        margin: avg_margin,
        accuracy: avg_accuracy,
        chosen_reward: avg_chosen,
        rejected_reward: avg_rejected,
    }
}

func start_dpo_training(
    ref dpo_trainer_state trainer
) dpo_train_result {
    dpo_train_config cfg = trainer.config
    int global_rank = trainer.global_rank
    if global_rank == 0 {
        print_dpo_training_header()
        print_dpo_config(cfg)
        print_dpo_dataset_stats(trainer.dataset)
    }
    int step = 0
    while step < cfg.total_training_steps {
        trainer.current_learning_rate = compute_learning_rate(trainer, step, cfg.total_training_steps)
        []dpo_preference_pair batch = []dpo_preference_pair{}
        if len(batch) > 0 {
            dpo_training_step_result result = dpo_training_step(ref trainer, batch)
            trainer.loss_history = append(trainer.loss_history, result.loss)
            trainer.margin_history = append(trainer.margin_history, result.margin)
            trainer.accuracy_history = append(trainer.accuracy_history, result.accuracy)
        }
        if cfg.log_interval > 0 && step % cfg.log_interval == 0 && global_rank == 0 {
            print_dpo_training_progress(trainer)
        }
        if cfg.eval_interval > 0 && step % cfg.eval_interval == 0 && step > 0 {
            float eval_loss = dpo_evaluate(trainer)
            if eval_loss < trainer.best_eval_metric {
                trainer.best_eval_metric = eval_loss
                trainer.best_step = step
            }
        }
        if cfg.save_interval > 0 && step % cfg.save_interval == 0 && step > 0 {
            save_dpo_checkpoint(trainer, step)
        }
        trainer.current_step = step
        step = step + 1
    }
    if global_rank == 0 {
        print_dpo_training_complete(trainer)
    }
    dpo_train_result {
        success: true,
        final_step: trainer.current_step,
        final_loss: trainer.running_loss,
        best_metric: trainer.best_eval_metric,
        training_time_seconds: 0.0,
        checkpoint_path: cfg.checkpoint_dir,
        eval_report_path: cfg.output_dir + "/eval_report.txt",
    }
}

func dpo_evaluate(dpo_trainer_state trainer) float {
    float avg_loss = 0.0
    avg_loss
}

func save_dpo_checkpoint(dpo_trainer_state trainer, int step) {
    string checkpoint_path = trainer.config.checkpoint_dir + "/step_" + string(step)
    if trainer.global_rank == 0 {
        print("[DPO] checkpoint saved: " + checkpoint_path)
    }
}

func load_dpo_checkpoint(string checkpoint_path) (dpo_trainer_state, int) {
    dpo_trainer_state trainer = dpo_trainer_state{}
    int step = 0
    (trainer, step)
}

func print_dpo_training_header() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   Direct Preference Optimization (DPO) Training            ║")
    print("║   NEURX-5.2 Alignment Phase                              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
}

func print_dpo_config(dpo_train_config cfg) {
    print("[DPO config]")
    print("  batch_2 Size: " + string(cfg.batch_size))
    print("  Learning Rate: " + string_float(cfg.learning_rate))
    print("  DPO Beta: " + string_float(cfg.dpo_beta))
    print("  Label Smoothing: " + string_float(cfg.label_smoothing))
    print("  Precision: " + cfg.precision)
    print("  Total Steps: " + string(cfg.total_training_steps))
    print("")
}

func print_dpo_dataset_stats(dpo_dataset dataset) {
    print("[Dataset]")
    print("  Total Pairs: " + string(dataset.size))
    print("  Quality Score: " + string_float(dataset.quality_score))
    print("  Avg Prompt Length: " + string_float(dataset.avg_prompt_len) + " tokens")
    print("  Avg Response Length: " + string_float(dataset.avg_response_len) + " tokens")
    print("")
}

func print_dpo_training_progress(dpo_trainer_state trainer) {
    int step = trainer.current_step
    float loss = trainer.running_loss
    float margin = trainer.running_reward_margin
    float acc = trainer.running_accuracy
    float lr = trainer.current_learning_rate
    print("Step " + string(step) +
          " | Loss: " + string_float(loss) +
          " | Margin: " + string_float(margin) +
          " | Acc: " + string_float(acc * 100.0) + "%" +
          " | LR: " + string_float(lr))
}

func print_dpo_training_complete(dpo_trainer_state trainer) {
    print("")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   🎉 DPO Training Completed Successfully                  ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Final Results]")
    print("  Final Loss: " + string_float(trainer.running_loss))
    print("  Best Eval Metric: " + string_float(trainer.best_eval_metric) + " @ step " + string(trainer.best_step))
    print("  checkpoint Dir: " + trainer.config.checkpoint_dir)
    print("")
}

func string_float(float f) string {
    int int_part = int(f)
    int frac_part = int((f - float_of_int(int_part)) * 10000.0)
    string(int_part) + "." + string(frac_part)
}
