package neurx.posttrain.config
struct posttrain_config {
    string stage
    int global_batch_size
    int micro_batch_size
    int max_steps
    float lr
    float kl_coef
    float clip_range
    int log_interval
    int eval_interval
    int save_interval
    bool bf16
    string optimizer
    string scheduler
    string backend
}

func new_posttrain_config() posttrain_config {
    posttrain_config {
        stage: "sft",
        global_batch_size: 128,
        micro_batch_size: 8,
        max_steps: 20000,
        lr: 0.00001,
        kl_coef: 0.02,
        clip_range: 0.2,
        log_interval: 10,
        eval_interval: 200,
        save_interval: 500,
        bf16: true,
        optimizer: "adamw",
        scheduler: "cosine",
        backend: "cuda",
    }
}

func with_stage(posttrain_config cfg, string stage) posttrain_config {
    posttrain_config {
        stage: stage,
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: cfg.micro_batch_size,
        max_steps: cfg.max_steps,
        lr: cfg.lr,
        kl_coef: cfg.kl_coef,
        clip_range: cfg.clip_range,
        log_interval: cfg.log_interval,
        eval_interval: cfg.eval_interval,
        save_interval: cfg.save_interval,
        bf16: cfg.bf16,
        optimizer: cfg.optimizer,
        scheduler: cfg.scheduler,
        backend: cfg.backend,
    }
}

func with_lr(posttrain_config cfg, float lr) posttrain_config {
    posttrain_config {
        stage: cfg.stage,
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: cfg.micro_batch_size,
        max_steps: cfg.max_steps,
        lr: lr,
        kl_coef: cfg.kl_coef,
        clip_range: cfg.clip_range,
        log_interval: cfg.log_interval,
        eval_interval: cfg.eval_interval,
        save_interval: cfg.save_interval,
        bf16: cfg.bf16,
        optimizer: cfg.optimizer,
        scheduler: cfg.scheduler,
        backend: cfg.backend,
    }
}

func posttrain_config_state_dict(posttrain_config cfg) posttrain_config {
    cfg
}

func posttrain_config_load_state_dict(posttrain_config cfg, posttrain_config other) posttrain_config {
    other
}

