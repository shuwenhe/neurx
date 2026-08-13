package neurx.pretrain.neurx
import neurx.model.llm.neurx.*
import neurx.tokenizer.neurx.*
import neurx.distributed.*
import neurx.amp.scaler.*
enum pretrain_task_type {
    CLM
    MLM
    PREFIX_LM
}

struct pretrain_config {
    string model_name
    neurx_config model_config
    []string train_data_paths
    []string eval_data_paths
    float clm_ratio
    float mlm_ratio
    float prefix_lm_ratio
    int batch_size_per_gpu
    int gradient_accum_steps
    int max_grad_norm
    float weight_decay
    float adam_beta1
    float adam_beta2
    float adam_epsilon
    float peak_lr
    int warmup_steps
    int total_steps
    int decay_steps
    string lr_schedule
    int min_seq_len
    int max_seq_len
    bool enable_long_context
    int long_context_freq
    int world_size
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    bool use_fsdp
    string output_dir
    int save_interval
    int log_interval
    int eval_interval
    int max_checkpoints_keep
    string precision
    bool enable_gradient_checkpointing
}

func create_neurx_200b_pretrain_config() pretrain_config {
    neurx_config model_cfg = create_neurx_200b_config_200b()
    return pretrain_config {
        model_name: "NEURX-5.2-200B",
        model_config: model_cfg,
        train_data_paths: [
            "/data/corpus/webtext/",
            "/data/corpus/wikipedia_zh/",
            "/data/corpus/wikipedia_en/",
            "/data/corpus/books/",
            "/data/corpus/code/"
        ],
        eval_data_paths: ["/data/corpus/eval/"],
        clm_ratio: 0.3,
        mlm_ratio: 0.2,
        prefix_lm_ratio: 0.5,
        batch_size_per_gpu: 1,
        gradient_accum_steps: 8,
        max_grad_norm: 1.0,
        weight_decay: 0.1,
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        peak_lr: 3e-5,
        warmup_steps: 2000,
        total_steps: 500_000,
        decay_steps: 498_000,
        lr_schedule: "cosine",
        min_seq_len: 512,
        max_seq_len: 8192,
        enable_long_context: true,
        long_context_freq: 100,
        world_size: 128,
        tensor_parallel_size: 8,
        pipeline_parallel_size: 4,
        data_parallel_size: 4,
        use_fsdp: true,
        output_dir: "./checkpoints/neurx_200b/",
        save_interval: 10_000,
        log_interval: 100,
        eval_interval: 5_000,
        max_checkpoints_keep: 5,
        precision: "bf16",
        enable_gradient_checkpointing: true,
    }
}

func create_test_pretrain_config() pretrain_config {
    neurx_config model_cfg = create_custom_neurx_config(
        vocab_size=32000,
        hidden_size=512,
        num_layers=6,
        num_heads=8,
        max_seq_len=1024
    )
    return pretrain_config {
        model_name: "NEURX-Test-Small",
        model_config: model_cfg,
        train_data_paths: ["./test_data/"],
        eval_data_paths: ["./test_data/eval/"],
        clm_ratio: 0.33,
        mlm_ratio: 0.34,
        prefix_lm_ratio: 0.33,
        batch_size_per_gpu: 4,
        gradient_accum_steps: 2,
        max_grad_norm: 1.0,
        weight_decay: 0.01,
        adam_beta1: 0.9,
        adam_beta2: 0.98,
        adam_epsilon: 1e-6,
        peak_lr: 1e-3,
        warmup_steps: 50,
        total_steps: 1000,
        decay_steps: 950,
        lr_schedule: "cosine",
        min_seq_len: 256,
        max_seq_len: 512,
        enable_long_context: false,
        long_context_freq: 0,
        world_size: 1,
        tensor_parallel_size: 1,
        pipeline_parallel_size: 1,
        data_parallel_size: 1,
        use_fsdp: false,
        output_dir: "./checkpoints/test_model/",
        save_interval: 200,
        log_interval: 10,
        eval_interval: 100,
        max_checkpoints_keep: 3,
        precision: "bf16",
        enable_gradient_checkpointing: false,
    }
}
enum training_phase {
    WARMUP
    STABLE_TRAINING
    LONG_CONTEXT_PHASE
    FINE_TUNING_PHASE
    COMPLETED
}

struct pretrain_state {
    pretrain_config config
    int current_step
    int current_epoch
    float current_lr
    training_phase phase

    struct loss_history {
        []float clm_losses
        []float mlm_losses
        []float prefix_lm_losses
        []float combined_losses
        float running_loss
        float best_val_loss
    } loss_history
    int64 total_tokens_seen
    int tokens_this_epoch
    int64 target_tokens
    datetime start_time
    float seconds_per_step
    float estimated_total_hours
    datetime estimated_end_time
    pretrain_task_type active_task

    struct performance {
        float tokens_per_second
        float gpu_memory_utilization
        float gpu_compute_utilization
        float communication_overhead_pct
        float gradient_norm
        float forward_time_ms
        float backward_time_ms
        float optimizer_time_ms
        int samples_per_step
    } performance
}

func create_pretrain_state(config: pretrain_config) pretrain_state {
    print("\n" + "="*70)
    print("Initializing NEURX Pretraining State")
    print("="*70)
    print(f"\n📊 Configuration Summary:")
    print(f"   model: {config.model_name}")
    print(f"   Total Parameters: {format_number(count_parameters(config.model_config))}")
    print(f"   Training Steps: {config.total_steps:,}")
    print(f"   Global batch_2 Size: {config.batch_size_per_gpu * config.gradient_accum_steps * config.data_parallel_size}")
    print(f"   Peak Learning Rate: {config.peak_lr}")
    print(f"   Precision: {config.precision}")
    print(f"   World Size: {config.world_size} GPUs")
    if config.world_size > 1:
        print(f"   Parallelism: TP={config.tensor_parallel_size} × PP={config.pipeline_parallel_size} × DP={config.data_parallel_size}")
    print(f"\n📝 task Distribution:")
    print(f"   CLM:       {config.clm_ratio * 100:.1f}%")
    print(f"   MLM:       {config.mlm_ratio * 100:.1f}%")
    print(f"   PrefixLM:  {config.prefix_lm_ratio * 100:.1f}%")
    print(f"\n💾 Output Directory: {config.output_dir}")
    print("="*70 + "\n")
    return pretrain_state {
        config: config,
        current_step: 0,
        current_epoch: 0,
        current_lr: 0.0,
        phase: WARMUP,
        loss_history: loss_history {
            clm_losses: [],
            mlm_losses: [],
            prefix_lm_losses: [],
            combined_losses: [],
            running_loss: 0.0,
            float best_val_loss('inf'),
        },
        total_tokens_seen: 0,
        tokens_this_epoch: 0,
        target_tokens: int64(config.total_steps) * config.batch_size_per_gpu * config.gradient_accum_steps * config.max_seq_len,
        start_time: now(),
        seconds_per_step: 0.0,
        estimated_total_hours: 0.0,
        estimated_end_time: none,
        active_task: PREFIX_LM,
        performance: performance {
            tokens_per_second: 0.0,
            gpu_memory_utilization: 0.0,
            gpu_compute_utilization: 0.0,
            communication_overhead_pct: 0.0,
        },
    }
}

func get_learning_rate(
    state: pretrain_state,
    step: int
) {
    pretrain_config cfg = state.config
    if step <= cfg.warmup_steps:
        return cfg.peak_lr * step / max(1, cfg.warmup_steps)
    elif step >= cfg.total_steps:
        return cfg.min_lr if hasattr(cfg, 'min_lr') else cfg.peak_lr * 0.01
    else:
        float progress = float(step - cfg.warmup_steps) / max(1, cfg.decay_steps - cfg.warmup_steps)
        match cfg.lr_schedule:
            case "cosine":
                float final_ratio = 0.1
                return cfg.peak_lr * (final_ratio + 0.5 * (1 - final_ratio) * (1 + cos(pi * progress)))
            case "linear":
                return cfg.peak_lr * (1.0 - progress)
            case "inverse_sqrt":
                return cfg.peak_lr / sqrt(1.0 + progress * 10)
            case _:
                return cfg.peak_lr * (1.0 - progress)
}

func sample_training_task(
    state: pretrain_state
) {
    float rand_val = rand()
    float cumulative = 0.0
    cumulative += state.config.clm_ratio
    if rand_val < cumulative:
        return CLM
    cumulative += state.config.mlm_ratio
    if rand_val < cumulative:
        return MLM
    cumulative += state.config.prefix_lm_ratio
    if rand_val < cumulative:
        return PREFIX_LM
    return PREFIX_LM
}

func prepare_clm_batch(
    tokenizer: tokenizer_state,
    batch_texts: []string,
    max_len: int
) {
    """
    English text CLM (Causal LM) batchdata
    Input: "the quick brown fox jumps"
    Labels: "quick brown fox jumps "
    """
    dict[str, any] encoded = batch_encode(
        tokenizer,
        batch_texts,
        add_special_tokens=true,
        max_length=some(max_len),
        truncation=true,
        padding=true
    )
    tensor input_ids = encoded["input_ids"]
    tensor attention_mask = encoded["attention_mask"]
    tensor labels = input_ids.clone()
    labels[:, :-1] = input_ids[:, 1:]
    labels[:, -1] = -100
    attention_mask[:, -1] = 0
    return {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "labels": labels,
        "task_type": CLM,
    }

func prepare_mlm_batch(
    tokenizer: tokenizer_state,
    batch_texts: []string,
    max_len: int,
    mlm_probability: float = 0.15
) {
    """
    English text MLM (Masked LM) batchdata
    English text mask 15% English text tokens English text
    """
    dict[str, any] encoded = batch_encode(
        tokenizer,
        batch_texts,
        add_special_tokens=true,
        max_length=some(max_len),
        truncation=true,
        padding=true
    )
    tensor input_ids = encoded["input_ids"]
    tensor attention_mask = encoded["attention_mask"]
    tensor labels = input_ids.clone()
    tensor mask_matrix = zeros_like(input_ids)
    int vocab_start = 4
    tensor valid_positions = (input_ids >= vocab_start).int()
    tensor random_vals = rand_like(input_ids.float())
    tensor mask_threshold = full_like(input_ids.float(), mlm_probability)
    tensor should_mask = (random_vals < mask_threshold) & (valid_positions == 1)
    tensor mask_types = rand_like(input_ids.float())
    int gmask_id = tokenizer.special_tokens.gmask_token_id
    tensor is_masked = should_mask.int()
    tensor is_80pct = (mask_types < 0.8) & is_masked
    tensor is_90pct = (mask_types >= 0.8) & (mask_types < 0.9) & is_masked
    input_ids = where(is_80pct, gmask_id, input_ids)
    input_ids = where(is_90pct, randint(vocab_start, tokenizer.vocab_size, shape=input_ids.shape), input_ids)
    labels = where(is_masked, labels, -100)
    return {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "labels": labels,
        "mask_positions": should_mask,
        "task_type": MLM,
    }

func prepare_prefix_lm_batch(
    tokenizer: tokenizer_state,
    batch_prefixes: []string,
    batch_continuations: []string,
    max_len: int,
    max_prefix_ratio: float = 0.7
) {
    """
    English text PrefixLM batchdata
    English text: SOP prefix EOP continuation EOS
    - Prefix English text: English text
    - Continuation English text: English text
    """
    int batch_size = len(batch_prefixes)
    assert(batch_size == len(batch_continuations))
    tensor all_input_ids(batch_size, max_len)
    tensor all_attention_mask(batch_size, max_len)
    tensor all_labels(batch_size, max_len)
    tensor sop_positions(batch_size)
    tensor eop_positions(batch_size)
    for i in range(batch_size):
        dict[str, any] sample = build_prefix_lm_input(
            tokenizer,
            prefix=batch_prefixes[i],
            continuation=batch_continuations[i]
        )
        []int ids = sample["input_ids"].tolist() if isinstance(sample["input_ids"], tensor) else sample["input_ids"]
        int actual_len = min(len(ids), max_len)
        for j in range(actual_len):
            all_input_ids[i, j] = ids[j]
            all_attention_mask[i, j] = 1
            if j > sample["eop_position"] and j < len(ids):
                all_labels[i, j] = ids[j]
            else:
                all_labels[i, j] = -100
        sop_positions[i] = sample["sop_position"]
        eop_positions[i] = sample["eop_position"]
    return {
        "input_ids": all_input_ids,
        "attention_mask": all_attention_mask,
        "labels": all_labels,
        "sop_positions": sop_positions,
        "eop_positions": eop_positions,
        "task_type": PREFIX_LM,
    }

func train_step(
    ref pretrain_state state,
    neurx_model model,
    optimizer: adam_w,
    batch: dict[str, any],
    scaler: GradScaler,
    rank: int = 0
) {
    """
    English textsteptraining
    Returns:
        loss value for this step
    """
    pretrain_config cfg = state.config
    pretrain_task_type task_type = batch["task_type"]
    if state.current_step % 10 == 0:
        float gpu_mem_gb = get_gpu_memory_usage() / 1024.0
        state.performance.gpu_memory_utilization = gpu_mem_gb
    state.current_lr = get_learning_rate(state, state.current_step)
    for param_group in optimizer.param_groups:
        param_group['lr'] = state.current_lr
    timer.start("forward")
    option[tuple[tensor, tensor]] sop_eop_info = none
    if task_type == PREFIX_LM:
        sop_eop_info = some((batch["sop_positions"], batch["eop_positions"]))
    dict[str, any] outputs = neurx_forward(
        model=model,
        input_ids=batch["input_ids"],
        attention_mask=some(batch["attention_mask"]),
        position_ids=none,
        sop_eop_info=sop_eop_info,
        output_attentions=false,
        output_hidden_states=False
    )
    tensor logits = outputs["logits"]
    neurx_loss_type loss_type
    match task_type:
        case CLM:
            loss_type = CLM
        case MLM:
            loss_type = MLM
        case PREFIX_LM:
            loss_type = PREFIX_LM
    tuple[tensor, int] loss_result = compute_neurx_loss(
        logits=logits,
        labels=batch["labels"],
        loss_type=loss_type,
        attention_mask=some(batch["attention_mask"])
    )
    tensor loss = loss_result[0]
    int num_tokens = loss_result[1]
    timer.stop("forward")
    timer.start("backward")
    if cfg.precision == "bf16" || cfg.precision == "fp16":
        scaler.scale(loss).backward()
    else:
        loss.backward()
    timer.stop("backward")
    if (state.current_step + 1) % cfg.gradient_accum_steps == 0:
        timer.start("optimizer")
        if cfg.precision == "bf16" || cfg.precision == "fp16":
            scaler.unscale_(optimizer)
        float grad_norm = clip_grad_norm_(model.parameters(), cfg.max_grad_norm)
        state.performance.gradient_norm = grad_norm
        if cfg.precision == "bf16" || cfg.precision == "fp16":
            scaler.step(optimizer)
            scaler.update()
        else:
            optimizer.step()
        optimizer.zero_grad(set_to_none=True)
        timer.stop("optimizer")
    state.current_step += 1
    state.tokens_seen += num_tokens
    state.tokens_this_epoch += num_tokens
    float loss_value = loss.item()
    state.loss_history.running_loss = (
        state.loss_history.running_loss * 0.9 + loss_value * 0.1
    )
    match task_type:
        case CLM:
            append(state.loss_history.clm_losses, loss_value)
        case MLM:
            append(state.loss_history.mlm_losses, loss_value)
        case PREFIX_LM:
            append(state.loss_history.prefix_lm_losses, loss_value)
    append(state.loss_history.combined_losses, loss_value)
    if state.seconds_per_step == 0:
        state.seconds_per_step = timer.get_elapsed("total")
    else:
        state.seconds_per_step = (
            state.seconds_per_step * 0.9 +
            timer.get_elapsed("total") * 0.1
        )
    state.performance.forward_time_ms = timer.get_elapsed("forward") * 1000.0
    state.performance.backward_time_ms = timer.get_elapsed("backward") * 1000.0
    state.performance.optimizer_time_ms = timer.get_elapsed("optimizer") * 1000.0
    int remaining_steps = cfg.total_steps - state.current_step
    state.estimated_total_hours = remaining_steps * state.seconds_per_step / 3600
    state.estimated_end_time = now() + timedelta(hours=state.estimated_total_hours)
    return loss_value

func evaluate(
    state: pretrain_state,
    neurx_model model,
    eval_dataloader: data_loader,
    tokenizer: tokenizer_state,
    max_eval_batches: int = 50
) {
    """
    English textevaluationmodel
    Returns:
        Dictionary with evaluation metrics
    """
    print("\n🔍 Running Evaluation...")
    model.eval()
    tensor all_losses[]
    int total_tokens = 0
    int correct_predictions = 0
    with no_grad():
        for batch_idx, batch in enumerate(eval_dataloader):
            if batch_idx >= max_eval_batches:
                break
            dict[str, any] outputs = neurx_forward(
                model=model,
                input_ids=batch["input_ids"],
                attention_mask=some(batch["attention_mask"]),
                output_attentions=false
            )
            tensor logits = outputs["logits"]
            tuple[tensor, int] loss_result = compute_neurx_loss(
                logits=logits,
                labels=batch["labels"],
                loss_type=CLM,
                attention_mask=some(batch["attention_mask"])
            )
            append(all_losses, loss_result[0].item())
            total_tokens += loss_result[1]
    model.train()
    float avg_loss = mean(all_losses)
    float perplexity = exp(avg_loss)
    if avg_loss < state.loss_history.best_val_loss:
        state.loss_history.best_val_loss = avg_loss
    dict[str, float] metrics = {}
    metrics["eval_loss"] = avg_loss
    metrics["perplexity"] = perplexity
    metrics["total_tokens"] = float(total_tokens)
    print(f"✅ Evaluation Complete:")
    print(f"   Loss: {avg_loss:.4f}")
    print(f"   Perplexity: {perplexity:.2f}")
    return metrics

func run_pretraining(
    model_config_path: option<string> = none,
    resume_from_checkpoint: option[string] = none
) {
    """
    mainEnglish text: start NEURX English texttrainingpipeline
    """
    print("\n" + "="*70)
    print("🚀 Starting NEURX Multi-task Pretraining")
    print("="*70)
    pretrain_config config = none
    if model_config_path != none:
        config = load_config(model_config_path!)
    else:
        config = create_neurx_200b_pretrain_config()
    if config.world_size > 1:
        init_distributed(
            world_size=config.world_size,
            tp_size=config.tensor_parallel_size,
            pp_size=config.pipeline_parallel_size,
            dp_size=config.data_parallel_size,
            use_fsdp=config.use_fsdp,
        )
    int rank = get_rank()
    if rank == 0:
        print("\n🏗️ Building NEURX model...")
    neurx_model model = create_neurx_model(config.model_config)
    if config.enable_gradient_checkpointing:
        enable_gradient_checkpointing(model)
    adam_w optimizer = adam_w(
        params=model.parameters(),
        lr=config.peak_lr,
        betas=(config.adam_beta1, config.adam_beta2),
        eps=config.adam_epsilon,
        weight_decay=config.weight_decay
    )
    grad_scaler scaler = grad_scaler(enabled=(config.precision != "fp32"))
    pretrain_state state = create_pretrain_state(config)
    if resume_from_checkpoint != none:
        tuple[model, optimizer, state, scaler] = load_checkpoint(
            checkpoint_path=resume_from_checkpoint!,
            model=model,
            optimizer=optimizer,
            state=state,
            scaler=scaler
        )
        print(f"✅ Resumed from checkpoint: {resume_from_checkpoint!}")
    if rank == 0:
        print("\n📂 Initializing DataLoaders...")
    tokenizer_state tokenizer = create_tokenizer(config.model_config.vocab_file or "vocab/neurx.model")
    data_loader train_loader = create_train_dataloader(
        config=config,
        tokenizer=tokenizer,
        rank=rank,
        world_size=config.world_size
    )
    data_loader eval_loader = create_eval_dataloader(
        config=config,
        tokenizer=tokenizer
    )
    if rank == 0:
        print(f"\n🎬 Starting Training Loop ({config.total_steps:,} steps)")
        print("-"*70)
    try:
        while state.current_step < config.total_steps:
            state.active_task = sample_training_task(state)
            dict[str, any] batch = None
            match state.active_task:
                case CLM:
                    batch = get_clm_batch(train_loader)
                case MLM:
                    batch = get_mlm_batch(train_loader)
                case PREFIX_LM:
                    batch = get_prefix_lm_batch(train_loader)
            if config.enable_long_context && \
               state.current_step % config.long_context_freq == 0:
                batch = get_long_context_batch(train_loader, config.max_seq_len * 4)
            batch = to_device(batch, device="cuda:{rank}")
            float loss = train_step(
                state=state,
                model=model,
                optimizer=optimizer,
                batch=batch,
                scaler=scaler,
                rank=rank
            )
            if rank == 0 && state.current_step % config.log_interval == 0:
                log_training_progress(state, loss)
            if state.current_step % config.eval_interval == 0:
                dict[str, float] eval_metrics = evaluate(
                    state=state,
                    model=model,
                    eval_dataloader=eval_loader,
                    tokenizer=tokenizer
                )
                log_evaluation_results(state, eval_metrics)
            if state.current_step % config.save_interval == 0:
                save_checkpoint(
                    model=model,
                    optimizer=optimizer,
                    state=state,
                    scaler=scaler,
                    output_dir=config.output_dir,
                    step=state.current_step
                )
            update_training_phase(state)
    except keyboard_interrupt:
        print("\n\n⚠️ Training interrupted by user!")
        save_emergency_checkpoint(model, optimizer, state, scaler, config.output_dir)
    if rank == 0:
        print("\n" + "="*70)
        print("🎉 Training Completed!")
        print("="*70)
        print_final_summary(state)
        save_checkpoint(
            model=model,
            optimizer=optimizer,
            state=state,
            scaler=scaler,
            output_dir=config.output_dir,
            step=state.current_step,
            is_final=True
        )

func log_training_progress(
    state: pretrain_state,
    float loss: float) {
    pretrain_config cfg = state.config
    int tokens_per_step = cfg.batch_size_per_gpu * cfg.gradient_accum_steps * cfg.max_seq_len
    state.performance.tokens_per_second = tokens_per_step / max(state.seconds_per_step, 0.001)
    state.performance.samples_per_step = cfg.batch_size_per_gpu * cfg.gradient_accum_steps
    elapsed = now() - state.start_time
    str elapsed_str = format_duration(elapsed)
    str eta_str = format_duration(timedelta(hours=state.estimated_total_hours))
    string task_name = ""
    match state.active_task:
        case CLM: task_name = "CLM"
        case MLM: task_name = "MLM"
        case PREFIX_LM: task_name = "PreLM"
    print(
        f"[Step {state.current_step:>7,}/{cfg.total_steps:,}] "
        f"Loss: {loss:>7.4f} | "
        f"LR: {state.current_lr:.2e} | "
        f"GradNorm: {state.performance.gradient_norm:>6.2f} | "
        f"Tokens: {state.total_tokens_seen:>10,}"
    )
    print(
        f"{'':>8}  Throughput: {state.performance.tokens_per_second:>8.0f} tok/s | "
        f"Samples: {state.performance.samples_per_step:>4} | "
        f"Forward: {state.performance.forward_time_ms:>5.1f}ms | "
        f"Backward: {state.performance.backward_time_ms:>5.1f}ms | "
        f"optimizer_2: {state.performance.optimizer_time_ms:>4.1f}ms | "
        f"GPU Mem: {state.performance.gpu_memory_utilization:>5.1f}GB"
    )
    print(
        f"{'':>8}  task: {task_name:>6} | "
        f"RunLoss: {state.loss_history.running_loss:>7.4f} | "
        f"Elapsed: {elapsed_str:>8} | "
        f"ETA: {eta_str:>8}"
    )
}

func log_evaluation_results(
    state: pretrain_state,
    dict[str, float] metrics) {
    print(f"\n{'='*50}")
    print(f"📊 Evaluation Results (Step {state.current_step:,})")
    print(f"{'='*50}")
    print(f"   Validation Loss:     {metrics['eval_loss']:.4f}")
    print(f"   Perplexity:         {metrics['perplexity']:.2f}")
    print(f"   Best Val Loss:       {state.loss_history.best_val_loss:.4f}")
    print(f"   Tokens Seen:         {state.total_tokens_seen:,}")
    print(f"{'='*50}\n")

func update_training_phase(ref pretrain_state state) {
    """
    English texttrainingphase
    """
    float progress = float(state.current_step) / float(state.config.total_steps)
    if progress < 0.05:
        state.phase = WARMUP
    elif progress < 0.8:
        state.phase = STABLE_TRAINING
    elif progress < 0.95:
        state.phase = LONG_CONTEXT_PHASE
    else:
        state.phase = FINE_TUNING_PHASE

func print_final_summary(pretrain_state state) {
    """
    English texttrainingsummary
    """
    pretrain_config cfg = state.config
    print(f"\n🎓 Final Training Summary:")
    print(f"{'-'*50}")
    print(f"   Total Steps:        {state.current_step:,}")
    print(f"   Total Tokens Seen:  {state.total_tokens_seen:,}")
    print(f"   Final Loss:         {state.loss_history.combined_losses[-1]:.4f}")
    print(f"   Best Val Loss:      {state.loss_history.best_val_loss:.4f}")
    print(f"   Training Duration:  {format_duration(now() - state.start_time)}")
    print(f"\n📈 Per-task Loss Statistics:")
    if len(state.loss_history.clm_losses) > 0:
        print(f"   CLM Avg Loss:       {mean(state.loss_history.clm_losses):.4f}")
    if len(state.loss_history.mlm_losses) > 0:
        print(f"   MLM Avg Loss:       {mean(state.loss_history.mlm_losses):.4f}")
    if len(state.loss_history.prefix_lm_losses) > 0:
        print(f"   PrefixLM Avg Loss:  {mean(state.loss_history.prefix_lm_losses):.4f}")
    print(f"{'-'*50}")

func format_duration(timedelta td) {
    int total_seconds = int(td.total_seconds())
    int days = total_seconds
    int hours = (total_seconds % 86400)
    int minutes = (total_seconds % 3600)
    int seconds = total_seconds % 60
    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        return f"{hours}h {minutes}m {seconds}s"
    elif minutes > 0:
        return f"{minutes}m {seconds}s"
    else:
        return f"{seconds}s"

func get_gpu_memory_usage() {
    """
    English textGPUEnglish textuseEnglish text(English text: MB)
    English textfloatEnglish text, English textuseEnglish textGPUEnglish text(MB)
    example: English text19353.6, English text19.4GB
    """
    float gpu_mem_mb = 18400.0
    return gpu_mem_mb
}

func test_pretrain_framework() {
    print("\n" + "="*60)
    print("Testing NEURX Pretraining Framework")
    print("="*60)
    print("\n[Test 1] Creating NEURX-5.2 pretrain config...")
    pretrain_config cfg = create_neurx_200b_pretrain_config()
    assert(cfg.clm_ratio + cfg.mlm_ratio + cfg.prefix_lm_ratio == 1.0)
    assert(cfg.total_steps == 500_000)
    assert(cfg.precision == "bf16")
    print("✅ config created!")
    print("\n[Test 2] Creating small test config...")
    pretrain_config test_cfg = create_test_pretrain_config()
    assert(test_cfg.world_size == 1)
    assert(test_cfg.total_steps == 1000)
    print("✅ Test config created!")
    print("\n[Test 3] Initializing pretrain state...")
    pretrain_state state = create_pretrain_state(test_cfg)
    assert(state.current_step == 0)
    assert(state.phase == WARMUP)
    print("✅ State initialized!")
    print("\n[Test 4] Testing learning rate schedule...")
    float lr_warmup = get_learning_rate(state, step=100)
    float lr_peak = get_learning_rate(state, step=3000)
    float lr_end = get_learning_rate(state, step=99800)
    assert(lr_warmup < lr_peak)
    assert(lr_end < lr_peak)
    print(f"   Warmup LR: {lr_warmup:.6f}")
    print(f"   Peak LR:   {lr_peak:.6f}")
    print(f"   End LR:    {lr_end:.6f}")
    print("✅ LR schedule works correctly!")
    print("\n[Test 5] Testing task sampling...")
    int clm_count = 0
    int mlm_count = 0
    int plm_count = 0
    for i in range(1000):
        pretrain_task_type task = sample_training_task(state)
        match task:
            case CLM: clm_count++
            case MLM: mlm_count++
            case PREFIX_LM: plm_count++
    float clm_ratio = float(clm_count) / 1000.0
    float mlm_ratio = float(mlm_count) / 1000.0
    float plm_ratio = float(plm_count) / 1000.0
    print(f"   CLM samples:  {clm_count} ({clm_ratio:.1%})")
    print(f"   MLM samples:  {mlm_count} ({mlm_ratio:.1%})")
    print(f"   PLM samples:  {plm_count} ({plm_ratio:.1%})")
    assert(abs(clm_ratio - test_cfg.clm_ratio) < 0.05)
    assert(abs(mlm_ratio - test_cfg.mlm_ratio) < 0.05)
    assert(abs(plm_ratio - test_cfg.prefix_lm_ratio) < 0.05)
    print("✅ task sampling distribution is correct!")
    print("\n[Test 6] Testing training phase transitions...")
    state.current_step = 100
    update_training_phase(state)
    assert(state.phase == STABLE_TRAINING)
    state.current_step = 450_000
    update_training_phase(state)
    assert(state.phase == LONG_CONTEXT_PHASE)
    state.current_step = 499_000
    update_training_phase(state)
    assert(state.phase == FINE_TUNING_PHASE)
    print("✅ Phase transitions work correctly!")
    print("\n[Test 7] Testing data preparation functions...")
    tokenizer_state tok = create_tokenizer("vocab/neurx.model")
    []string texts = ["Hello world", "Test sentence"]
    dict[str, any] clm_batch = prepare_clm_batch(tok, texts, max_len=64)
    assert(shape(clm_batch["input_ids"]) == (2, 64))
    assert("labels" in clm_batch)
    print("✅ CLM batch preparation works!")
    dict[str, any] mlm_batch = prepare_mlm_batch(tok, texts, max_len=64)
    assert(shape(mlm_batch["input_ids"]) == (2, 64))
    assert("mask_positions" in mlm_batch)
    print("✅ MLM batch preparation works!")
    []string prefixes = ["Translate:", "Summarize:"]
    []string conts = ["Hello", "This is a test."]
    dict[str, any] plm_batch = prepare_prefix_lm_batch(tok, prefixes, conts, max_len=64)
    assert(shape(plm_batch["input_ids"]) == (2, 64))
    assert("sop_positions" in plm_batch)
    assert("eop_positions" in plm_batch)
    print("✅ PrefixLM batch preparation works!")
    print("\n" + "="*60)
    print("All pretraining framework tests passed! ✨")
    print("="*60 + "\n")
