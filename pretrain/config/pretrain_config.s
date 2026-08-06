package neurx.pretrain.config

struct pretrain_config {
    int global_batch_size
    int micro_batch_size
    int seq_len
    int max_steps
    int warmup_steps
    float lr
    float min_lr
    float weight_decay
    int log_interval
    int eval_interval
    int save_interval
    bool bf16
    bool grad_checkpoint
    string optimizer
    string scheduler
    string backend
}

func new_pretrain_config() pretrain_config {
    pretrain_config {
        global_batch_size: 256,
        micro_batch_size: 8,
        seq_len: 2048,
        max_steps: 100000,
        warmup_steps: 2000,
        lr: 0.0003,
        min_lr: 0.00003,
        weight_decay: 0.1,
        log_interval: 10,
        eval_interval: 500,
        save_interval: 1000,
        bf16: true,
        grad_checkpoint: true,
        optimizer: "adamw",
        scheduler: "cosine",
        backend: "cuda",
    }
}

func with_max_steps(pretrain_config cfg, int max_steps) pretrain_config {
    pretrain_config {
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: cfg.micro_batch_size,
        seq_len: cfg.seq_len,
        max_steps: max_steps,
        warmup_steps: cfg.warmup_steps,
        lr: cfg.lr,
        min_lr: cfg.min_lr,
        weight_decay: cfg.weight_decay,
        log_interval: cfg.log_interval,
        eval_interval: cfg.eval_interval,
        save_interval: cfg.save_interval,
        bf16: cfg.bf16,
        grad_checkpoint: cfg.grad_checkpoint,
        optimizer: cfg.optimizer,
        scheduler: cfg.scheduler,
        backend: cfg.backend,
    }
}

func with_lr(pretrain_config cfg, float lr) pretrain_config {
    pretrain_config {
        global_batch_size: cfg.global_batch_size,
        micro_batch_size: cfg.micro_batch_size,
        seq_len: cfg.seq_len,
        max_steps: cfg.max_steps,
        warmup_steps: cfg.warmup_steps,
        lr: lr,
        min_lr: cfg.min_lr,
        weight_decay: cfg.weight_decay,
        log_interval: cfg.log_interval,
        eval_interval: cfg.eval_interval,
        save_interval: cfg.save_interval,
        bf16: cfg.bf16,
        grad_checkpoint: cfg.grad_checkpoint,
        optimizer: cfg.optimizer,
        scheduler: cfg.scheduler,
        backend: cfg.backend,
    }
}

func pretrain_config_state_dict(pretrain_config cfg) pretrain_config {
    cfg
}

func pretrain_config_load_state_dict(pretrain_config cfg, pretrain_config other) pretrain_config {
    other
}

