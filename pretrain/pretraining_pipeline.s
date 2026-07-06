// ============================================================
// NEURX Multi-Task Pretraining Framework
// 支持三种预训练目标:
//   1. Causal Language Modeling (CLM) - 标准自回归
//   2. Masked Language Modeling (MLM) - 类 BERT 填空
//   3. Prefix Language Modeling (PrefixLM) - NEURX 特色,双向+因果混合
//
// 特点:
//   - 多任务混合采样
//   - 动态 loss 权重调整
//   - 支持 FSDP / TP / PP 并行
//   - 长上下文训练支持 (Ring Attention)
// ============================================================

package neurx.pretrain.neurx

import neurx.model.llm.neurx.*
import neurx.tokenizer.neurx.*
import neurx.distributed.*
import neurx.training.mixed_precision.*

// ============================================================
// 预训练任务类型
// ============================================================
enum pretrain_task_type {
    CLM          // 自回归语言建模 (GPT 风格)
    MLM          // 掩码语言建模 (BERT/NEURX-130B 风格)
    PREFIX_LM    // 前缀语言建模 (NEURX-4/5 风格)
}

// ============================================================
// 预训练配置
// ============================================================
struct pretrain_config {
    // === 模型配置 ===
    string model_name              // "neurx_9b" | "neurx_200b" | custom path
    neurx_config model_config        // 模型架构配置
    
    // === 数据配置 ===
    string[] train_data_paths      // 训练数据路径列表
    string[] eval_data_paths       // 验证数据路径列表
    
    // === 任务比例 (概率分布, 总和应为 1.0) ===
    float clm_ratio               // CLM 任务占比
    float mlm_ratio               // MLM 任务占比  
    float prefix_lm_ratio         // PrefixLM 任务占比
    
    // === 训练超参数 ===
    int batch_size_per_gpu         // 每个 GPU 的 batch size
    int gradient_accum_steps      // 梯度累积步数
    int max_grad_norm             // 梯度裁剪阈值
    float weight_decay            // 权重衰减
    float adam_beta1             // Adam beta1
    float adam_beta2             // Adam beta2
    float adam_epsilon           // Adam epsilon
    
    // === 学习率调度 ===
    float peak_lr                 // 峰值学习率
    int warmup_steps             // 预热步数
    int total_steps              // 总训练步数
    int decay_steps              // 衰减步数 (用于 cosine decay)
    string lr_schedule           // "cosine" | "linear" | "inverse_sqrt"
    
    // === 序列长度 ===
    int min_seq_len              // 最短序列长度
    int max_seq_len              // 最长序列长度
    bool enable_long_context     // 是否启用长上下文训练
    int long_context_freq        // 每 N 步插入一次长序列
    
    // === 分布式 ===
    int world_size               // 总 GPU 数量
    int tensor_parallel_size      // TP 大小
    int pipeline_parallel_size    // PP 大小
    int data_parallel_size        // DP/PP 大小 (FSDP)
    bool use_fsdp                // 是否使用 FSDP
    
    // === Checkpoint & Logging ===
    string output_dir            // 输出目录
    int save_interval            // 保存间隔 (步数)
    int log_interval             // 日志间隔 (步数)
    int eval_interval            // 评估间隔 (步数)
    int max_checkpoints_keep     // 最多保留 checkpoint 数量
    
    // === 精度 ===
    string precision             // "bf16" | "fp16" | "fp32"
    bool enable_gradient_checkpointing // 梯度检查点 (节省显存)
}

// 默认 NEURX-5.2 预训练配置 (~200B 参数)
func create_neurx_200b_pretrain_config() pretrain_config {
    
    neurx_config model_cfg = create_neurx_200b_config_200b()
    
    return pretrain_config {
        model_name: "NEURX-5.2-200B",
        model_config: model_cfg,
        
        // 数据 (示例路径)
        train_data_paths: [
            "/data/corpus/webtext/",
            "/data/corpus/wikipedia_zh/",
            "/data/corpus/wikipedia_en/",
            "/data/corpus/books/",
            "/data/corpus/code/"
        ],
        eval_data_paths: ["/data/corpus/eval/"],
        
        // NEURX 推荐的任务比例 (参考论文)
        clm_ratio: 0.3,        // 30% 纯自回归
        mlm_ratio: 0.2,         // 20% MLM
        prefix_lm_ratio: 0.5,    // 50% PrefixLM (NEURX 核心能力)
        
        // 训练参数 (参考 LLaMA/GPT-3 训练设置)
        batch_size_per_gpu: 1,    // 200B 模型每卡 batch=1
        gradient_accum_steps: 8,  // 全局 batch = 64 * 8 = 512
        max_grad_norm: 1.0,
        weight_decay: 0.1,
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        
        // 学习率调度 (参考 Chinchilla scaling laws)
        peak_lr: 3e-5,
        warmup_steps: 2000,
        total_steps: 500_000,     // ~2T tokens @ 4M tokens/batch
        decay_steps: 498_000,
        lr_schedule: "cosine",
        
        // 序列长度
        min_seq_len: 512,
        max_seq_len: 8192,        // 从短到长逐步增加
        enable_long_context: true,
        long_context_freq: 100,   // 每100步一次长上下文
        
        // 分布式 (假设 128 卡 H100)
        world_size: 128,
        tensor_parallel_size: 8,
        pipeline_parallel_size: 4,
        data_parallel_size: 4,    # 8 * 4 * 4 = 128
        use_fsdp: true,
        
        // Checkpoint & 日志
        output_dir: "./checkpoints/neurx_200b/",
        save_interval: 10_000,
        log_interval: 100,
        eval_interval: 5_000,
        max_checkpoints_keep: 5,
        
        // 精度
        precision: "bf16",
        enable_gradient_checkpointing: true,
    }
}

// 小规模测试配置
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

// ============================================================
// 预训练状态机
// ============================================================
enum training_phase {
    WARMUP                  // 预热阶段
    STABLE_TRAINING         // 稳定训练阶段
    LONG_CONTEXT_PHASE      // 长上下文训练阶段
    FINE_TUNING_PHASE       // 微调阶段 (可选)
    COMPLETED              // 训练完成
}

struct pretrain_state {
    pretrain_config config
    
    // 当前状态
    int current_step
    int current_epoch
    float current_lr
    training_phase phase
    
    // Loss 历史
    struct loss_history {
        float[] clm_losses
        float[] mlm_losses
        float[] prefix_lm_losses
        float[] combined_losses
        float running_loss
        float best_val_loss
    } loss_history
    
    // Token 统计
    int64 total_tokens_seen
    int tokens_this_epoch
    int64 target_tokens
    
    // 时间统计
    datetime start_time
    float seconds_per_step
    float estimated_total_hours
    datetime estimated_end_time
    
    // 当前任务类型 (动态切换)
    pretrain_task_type active_task
    
    // 性能指标
    struct performance {
        float tokens_per_second
        float gpu_memory_utilization
        float gpu_compute_utilization
        float communication_overhead_pct
    } performance
}

// 初始化预训练状态
func create_pretrain_state(config: pretrain_config) pretrain_state {
    
    print("\n" + "="*70)
    print("Initializing NEURX Pretraining State")
    print("="*70)
    print(f"\n📊 Configuration Summary:")
    print(f"   Model: {config.model_name}")
    print(f"   Total Parameters: {format_number(count_parameters(config.model_config))}")
    print(f"   Training Steps: {config.total_steps:,}")
    print(f"   Global Batch Size: {config.batch_size_per_gpu * config.gradient_accum_steps * config.data_parallel_size}")
    print(f"   Peak Learning Rate: {config.peak_lr}")
    print(f"   Precision: {config.precision}")
    print(f"   World Size: {config.world_size} GPUs")
    if config.world_size > 1:
        print(f"   Parallelism: TP={config.tensor_parallel_size} × PP={config.pipeline_parallel_size} × DP={config.data_parallel_size}")
    print(f"\n📝 Task Distribution:")
    print(f"   CLM:       {config.clm_ratio * 100:.1f}%")
    print(f"   MLM:       {config.mlm_ratio * 100:.1f}%")
    print(f"   PrefixLM:  {config.prefix_lm_ratio * 100:.1f}%")
    print(f"\n💾 Output Directory: {config.output_dir}")
    print("="*70 + "\n")
    
    return pretrain_state {
        config: config,
        current_step: 0,
        current_epoch: 0,
        current_lr: 0.0,  # 将在第一步更新
        phase: WARMUP,
        loss_history: loss_history {
            clm_losses: [],
            mlm_losses: [],
            prefix_lm_losses: [],
            combined_losses: [],
            running_loss: 0.0,
            best_val_loss: float('inf'),
        },
        total_tokens_seen: 0,
        tokens_this_epoch: 0,
        target_tokens: int64(config.total_steps) * config.batch_size_per_gpu * config.gradient_accum_steps * config.max_seq_len,
        start_time: now(),
        seconds_per_step: 0.0,
        estimated_total_hours: 0.0,
        estimated_end_time: none,
        active_task: PREFIX_LM,  # 默认从 PrefixLM 开始
        performance: performance {
            tokens_per_second: 0.0,
            gpu_memory_utilization: 0.0,
            gpu_compute_utilization: 0.0,
            communication_overhead_pct: 0.0,
        },
    }
}

// ============================================================
// 学习率调度器
// ============================================================

func get_learning_rate(
    state: pretrain_state,
    step: int
) -> float {
    
    pretrain_config cfg = state.config
    
    if step <= cfg.warmup_steps:
        # Linear warmup
        return cfg.peak_lr * step / max(1, cfg.warmup_steps)
    elif step >= cfg.total_steps:
        return cfg.min_lr if hasattr(cfg, 'min_lr') else cfg.peak_lr * 0.01
    else:
        # Decay phase
        float progress = float(step - cfg.warmup_steps) / max(1, cfg.decay_steps - cfg.warmup_steps)
        
        match cfg.lr_schedule:
            case "cosine":
                # Cosine annealing with final ratio
                float final_ratio = 0.1
                return cfg.peak_lr * (final_ratio + 0.5 * (1 - final_ratio) * (1 + cos(pi * progress)))
            
            case "linear":
                return cfg.peak_lr * (1.0 - progress)
            
            case "inverse_sqrt":
                # Inverse square root decay (used in some models like PaLM)
                return cfg.peak_lr / sqrt(1.0 + progress * 10)
            
            case _:
                return cfg.peak_lr * (1.0 - progress)
}

// ============================================================
// 任务采样器 (根据比例随机选择任务)
// ============================================================

func sample_training_task(
    state: pretrain_state
) -> pretrain_task_type {
    
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
    
    # Fallback (shouldn't happen if ratios sum to 1.0)
    return PREFIX_LM
}

// ============================================================
// 数据准备函数 (针对不同任务类型)
// ============================================================

func prepare_clm_batch(
    tokenizer: tokenizer_state,
    batch_texts: string[],
    max_len: int
) -> dict[str, any] {
    """
    准备 CLM (Causal LM) 批次数据
    
    Input: "The quick brown fox jumps"
    Labels: "quick brown fox jumps "
    """
    
    # 编码所有文本
    dict[str, any] encoded = batch_encode(
        tokenizer, 
        batch_texts,
        add_special_tokens=true,
        max_length=some(max_len),
        truncation=true,
        padding=true
    )
    
    tensor input_ids = encoded["input_ids"]  # [batch, seq]
    tensor attention_mask = encoded["attention_mask"]
    
    # Shift for next-token prediction
    tensor labels = input_ids.clone()
    labels[:, :-1] = input_ids[:, 1:]
    labels[:, -1] = -100  # 最后一个位置没有 label
    attention_mask[:, -1] = 0  # mask 最后一个位置
    
    return {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "labels": labels,
        "task_type": CLM,
    }

func prepare_mlm_batch(
    tokenizer: tokenizer_state,
    batch_texts: string[],
    max_len: int,
    mlm_probability: float = 0.15
) -> dict[str, any] {
    """
    准备 MLM (Masked LM) 批次数据
    
    随机 mask 15% 的 tokens 用于填空预测
    """
    
    dict[str, any] encoded = batch_encode(
        tokenizer,
        batch_texts,
        add_special_tokens=true,
        max_length=some(max_len),
        truncation=true,
        padding=true
    )
    
    tensor input_ids = encoded["input_ids"]  # [batch, seq]
    tensor attention_mask = encoded["attention_mask"]
    tensor labels = input_ids.clone()  # labels = original tokens
    
    # 创建 mask (排除特殊 token 位置)
    tensor mask_matrix = zeros_like(input_ids)  # 1 表示被 mask 的位置
    
    int vocab_start = 4  # PAD, BOS, EOS, UNK 是特殊 token
    tensor valid_positions = (input_ids >= vocab_start).int()
    
    # 随机选择要 mask 的位置
    tensor random_vals = rand_like(input_ids.float())
    tensor mask_threshold = full_like(input_ids.float(), mlm_probability)
    
    tensor should_mask = (random_vals < mask_threshold) & (valid_positions == 1)
    
    # 执行 masking: 80% [MASK], 10% random, 10% keep
    tensor mask_types = rand_like(input_ids.float())  # 用于决定 mask 类型
    
    # gMASK token id
    int gmask_id = tokenizer.special_tokens.gmask_token_id
    
    # Apply masks
    tensor is_masked = should_mask.int()
    tensor is_80pct = (mask_types < 0.8) & is_masked
    tensor is_90pct = (mask_types >= 0.8) & (mask_types < 0.9) & is_masked
    # remaining 10% keep original
    
    input_ids = where(is_80pct, gmask_id, input_ids)
    input_ids = where(is_90pct, randint(vocab_start, tokenizer.vocab_size, shape=input_ids.shape), input_ids)
    
    # Set labels to -100 for non-masked positions (don't compute loss there)
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
    batch_prefixes: string[],     # prefix 部分 (双向注意力)
    batch_continuations: string[], # continuation 部分 (因果注意力)
    max_len: int,
    max_prefix_ratio: float = 0.7  # prefix 最大占比
) -> dict[str, any] {
    """
    准备 PrefixLM 批次数据
    
    格式: SOP prefix EOP continuation EOS
    - Prefix 区域: 双向注意力
    - Continuation 区域: 因果自回归
    """
    
    int batch_size = len(batch_prefixes)
    assert(batch_size == len(batch_continuations))
    
    tensor all_input_ids(batch_size, max_len)
    tensor all_attention_mask(batch_size, max_len)
    tensor all_labels(batch_size, max_len)
    tensor sop_positions(batch_size)
    tensor eop_positions(batch_size)
    
    for i in range(batch_size):
        # 构建单个样本
        dict[str, any] sample = build_prefix_lm_input(
            tokenizer,
            prefix=batch_prefixes[i],
            continuation=batch_continuations[i]
        )
        
        int[] ids = sample["input_ids"].tolist() if isinstance(sample["input_ids"], tensor) else sample["input_ids"]
        int actual_len = min(len(ids), max_len)
        
        # 填充
        for j in range(actual_len):
            all_input_ids[i, j] = ids[j]
            all_attention_mask[i, j] = 1
            
            # Labels: 只在 continuation 部分计算 loss
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

// ============================================================
// 单步训练逻辑
// ============================================================

func train_step(
    ref pretrain_state state,
    neurx_model model,
    optimizer: AdamW,
    batch: dict[str, any],
    scaler: GradScaler,
    rank: int = 0
) -> float {
    """
    执行单步训练
    
    Returns:
        loss value for this step
    """
    
    pretrain_config cfg = state.config
    pretrain_task_type task_type = batch["task_type"]
    
    # 更新学习率
    state.current_lr = get_learning_rate(state, state.current_step)
    for param_group in optimizer.param_groups:
        param_group['lr'] = state.current_lr
    
    # ===== Forward Pass =====
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
    
    # Compute Loss based on task type
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
    
    # ===== Backward Pass =====
    timer.start("backward")
    
    if cfg.precision == "bf16" || cfg.precision == "fp16":
        # Mixed precision backward
        scaler.scale(loss).backward()
    else:
        loss.backward()
    
    timer.stop("backward")
    
    # ===== Gradient Accumulation & Update =====
    if (state.current_step + 1) % cfg.gradient_accum_steps == 0:
        timer.start("optimizer")
        
        # Gradient clipping
        if cfg.precision == "bf16" || cfg.precision == "fp16":
            scaler.unscale_(optimizer)
        clip_grad_norm_(model.parameters(), cfg.max_grad_norm)
        
        # Optimizer step
        if cfg.precision == "bf16" || cfg.precision == "fp16":
            scaler.step(optimizer)
            scaler.update()
        else:
            optimizer.step()
        
        optimizer.zero_grad(set_to_none=True)
        
        timer.stop("optimizer")
    
    # ===== Update State =====
    state.current_step += 1
    state.tokens_seen += num_tokens
    state.tokens_this_epoch += num_tokens
    
    float loss_value = loss.item()
    state.loss_history.running_loss = (
        state.loss_history.running_loss * 0.9 + loss_value * 0.1
    )  # EMA smoothing
    
    # Record per-task loss
    match task_type:
        case CLM:
            append(state.loss_history.clm_losses, loss_value)
        case MLM:
            append(state.loss_history.mlm_losses, loss_value)
        case PREFIX_LM:
            append(state.loss_history.prefix_lm_losses, loss_value)
    append(state.loss_history.combined_losses, loss_value)
    
    # Update timing
    if state.seconds_per_step == 0:
        state.seconds_per_step = timer.get_elapsed("total")
    else:
        state.seconds_per_step = (
            state.seconds_per_step * 0.9 + 
            timer.get_elapsed("total") * 0.1
        )
    
    # Estimate completion time
    int remaining_steps = cfg.total_steps - state.current_step
    state.estimated_total_hours = remaining_steps * state.seconds_per_step / 3600
    state.estimated_end_time = now() + timedelta(hours=state.estimated_total_hours)
    
    return loss_value

// ============================================================
// 评估逻辑
// ============================================================

func evaluate(
    state: pretrain_state,
    neurx_model model,
    eval_dataloader: DataLoader,
    tokenizer: tokenizer_state,
    max_eval_batches: int = 50
) -> dict[str, float] {
    """
    在验证集上评估模型
    
    Returns:
        Dictionary with evaluation metrics
    """
    
    print("\n🔍 Running Evaluation...")
    
    model.eval()  # 设置为评估模式
    tensor all_losses[]
    int total_tokens = 0
    int correct_predictions = 0  # For accuracy metric (optional)
    
    with no_grad():
        for batch_idx, batch in enumerate(eval_dataloader):
            if batch_idx >= max_eval_batches:
                break
            
            # Forward pass
            dict[str, any] outputs = neurx_forward(
                model=model,
                input_ids=batch["input_ids"],
                attention_mask=some(batch["attention_mask"]),
                output_attentions=false
            )
            
            tensor logits = outputs["logits"]
            
            # Compute loss
            tuple[tensor, int] loss_result = compute_neurx_loss(
                logits=logits,
                labels=batch["labels"],
                loss_type=CLM,
                attention_mask=some(batch["attention_mask"])
            )
            
            append(all_losses, loss_result[0].item())
            total_tokens += loss_result[1]
            
            # Compute accuracy (top-1 prediction at masked positions)
            # ... optional implementation ...
    
    model.train()  # 回到训练模式
    
    # Aggregate metrics
    float avg_loss = mean(all_losses)
    float perplexity = exp(avg_loss)
    
    # Update best validation loss
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

// ============================================================
// 主训练循环
// ============================================================

func run_pretraining(
    model_config_path: option<string> = none,
    resume_from_checkpoint: option[string] = none
) {
    """
    主入口: 启动 NEURX 预训练流程
    """
    
    print("\n" + "="*70)
    print("🚀 Starting NEURX Multi-Task Pretraining")
    print("="*70)
    
    // ===== Step 1: Load Configuration =====
    pretrain_config config = none
    if model_config_path != none:
        config = load_config(model_config_path!)
    else:
        config = create_neurx_200b_pretrain_config()
    
    // ===== Step 2: Initialize Distributed Training =====
    if config.world_size > 1:
        init_distributed(
            world_size=config.world_size,
            tp_size=config.tensor_parallel_size,
            pp_size=config.pipeline_parallel_size,
            dp_size=config.data_parallel_size,
            use_fsdp=config.use_fsdp,
        )
    
    int rank = get_rank()
    
    # ===== Step 3: Initialize Model =====
    if rank == 0:
        print("\n🏗️ Building NEURX Model...")
    
    neurx_model model = create_neurx_model(config.model_config)
    
    # Apply gradient checkpointing if enabled
    if config.enable_gradient_checkpointing:
        enable_gradient_checkpointing(model)
    
    # ===== Step 4: Initialize Optimizer =====
    AdamW optimizer = AdamW(
        params=model.parameters(),
        lr=config.peak_lr,
        betas=(config.adam_beta1, config.adam_beta2),
        eps=config.adam_epsilon,
        weight_decay=config.weight_decay
    )
    
    # ===== Step 5: Initialize Scaler (Mixed Precision) =====
    GradScaler scaler = GradScaler(enabled=(config.precision != "fp32"))
    
    # ===== Step 6: Load Checkpoint (if resuming) =====
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
    
    # ===== Step 7: Initialize DataLoaders =====
    if rank == 0:
        print("\n📂 Initializing DataLoaders...")
    
    tokenizer_state tokenizer = create_tokenizer(config.model_config.vocab_file or "vocab/neurx.model")
    
    DataLoader train_loader = create_train_dataloader(
        config=config,
        tokenizer=tokenizer,
        rank=rank,
        world_size=config.world_size
    )
    
    DataLoader eval_loader = create_eval_dataloader(
        config=config,
        tokenizer=tokenizer
    )
    
    # ===== Step 8: Main Training Loop =====
    if rank == 0:
        print(f"\n🎬 Starting Training Loop ({config.total_steps:,} steps)")
        print("-"*70)
    
    try:
        while state.current_step < config.total_steps:
            
            # ===== Sample Task Type =====
            state.active_task = sample_training_task(state)
            
            # ===== Get Next Batch =====
            dict[str, any] batch = None
            
            match state.active_task:
                case CLM:
                    batch = get_clm_batch(train_loader)
                case MLM:
                    batch = get_mlm_batch(train_loader)
                case PREFIX_LM:
                    batch = get_prefix_lm_batch(train_loader)
                
            # Long context injection
            if config.enable_long_context && \
               state.current_step % config.long_context_freq == 0:
                batch = get_long_context_batch(train_loader, config.max_seq_len * 4)
            
            # Move to device (GPU)
            batch = to_device(batch, device="cuda:{rank}")
            
            # ===== Train Step =====
            float loss = train_step(
                state=state,
                model=model,
                optimizer=optimizer,
                batch=batch,
                scaler=scaler,
                rank=rank
            )
            
            # ===== Logging =====
            if rank == 0 && state.current_step % config.log_interval == 0:
                log_training_progress(state, loss)
            
            # ===== Evaluation =====
            if state.current_step % config.eval_interval == 0:
                dict[str, float] eval_metrics = evaluate(
                    state=state,
                    model=model,
                    eval_dataloader=eval_loader,
                    tokenizer=tokenizer
                )
                log_evaluation_results(state, eval_metrics)
            
            # ===== Save Checkpoint =====
            if state.current_step % config.save_interval == 0:
                save_checkpoint(
                    model=model,
                    optimizer=optimizer,
                    state=state,
                    scaler=scaler,
                    output_dir=config.output_dir,
                    step=state.current_step
                )
            
            # ===== Phase Transitions =====
            update_training_phase(state)
    
    except KeyboardInterrupt:
        print("\n\n⚠️ Training interrupted by user!")
        save_emergency_checkpoint(model, optimizer, state, scaler, config.output_dir)
    
    # ===== Training Complete =====
    if rank == 0:
        print("\n" + "="*70)
        print("🎉 Training Completed!")
        print("="*70)
        print_final_summary(state)
        
        # Final save
        save_checkpoint(
            model=model,
            optimizer=optimizer,
            state=state,
            scaler=scaler,
            output_dir=config.output_dir,
            step=state.current_step,
            is_final=True
        )

// ============================================================
// 日志和监控
// ============================================================

func log_training_progress(
    state: pretrain_state,
    float loss: float) {
    
    pretrain_config cfg = state.config
    
    # Calculate throughput
    int tokens_per_step = cfg.batch_size_per_gpu * cfg.gradient_accum_steps * cfg.max_seq_len
    state.performance.tokens_per_second = tokens_per_step / max(state.seconds_per_step, 0.001)
    
    # Format time
    elapsed = now() - state.start_time
    str elapsed_str = format_duration(elapsed)
    str eta_str = format_duration(timedelta(hours=state.estimated_total_hours))
    
    # Get task name
    string task_name = ""
    match state.active_task:
        case CLM: task_name = "CLM"
        case MLM: task_name = "MLM"
        case PREFIX_LM: task_name = "PreLM"
    
    print(
        f"[Step {state.current_step:>7,}/{cfg.total_steps:,}] "
        f"Loss: {loss:>7.4f} | "
        f"RunLoss: {state.loss_history.running_loss:>7.4f} | "
        f"LR: {state.current_lr:.2e} | "
        f"Task: {task_name:>5} | "
        f"Tokens/sec: {state.performance.tokens_per_second:>8.0f} | "
        f"Elapsed: {elapsed_str} | "
        f"ETA: {eta_str}"
    )

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
    自动更新训练阶段
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
    打印最终训练摘要
    """
    
    pretrain_config cfg = state.config
    
    print(f"\n🎓 Final Training Summary:")
    print(f"{'-'*50}")
    print(f"   Total Steps:        {state.current_step:,}")
    print(f"   Total Tokens Seen:  {state.total_tokens_seen:,}")
    print(f"   Final Loss:         {state.loss_history.combined_losses[-1]:.4f}")
    print(f"   Best Val Loss:      {state.loss_history.best_val_loss:.4f}")
    print(f"   Training Duration:  {format_duration(now() - state.start_time)}")
    print(f"\n📈 Per-Task Loss Statistics:")
    
    if len(state.loss_history.clm_losses) > 0:
        print(f"   CLM Avg Loss:       {mean(state.loss_history.clm_losses):.4f}")
    if len(state.loss_history.mlm_losses) > 0:
        print(f"   MLM Avg Loss:       {mean(state.loss_history.mlm_losses):.4f}")
    if len(state.loss_history.prefix_lm_losses) > 0:
        print(f"   PrefixLM Avg Loss:  {mean(state.loss_history.prefix_lm_losses):.4f}")
    
    print(f"{'-'*50}")

// ============================================================
// 工具函数
// ============================================================
func format_duration(timedelta td) -> string {
    int total_seconds = int(td.total_seconds())
    int days = total_seconds // 86400
    int hours = (total_seconds % 86400) // 3600
    int minutes = (total_seconds % 3600) // 60
    int seconds = total_seconds % 60
    
    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    elif hours > 0:
        return f"{hours}h {minutes}m {seconds}s"
    elif minutes > 0:
        return f"{minutes}m {seconds}s"
    else:
        return f"{seconds}s"

// ============================================================
// 测试函数
// ============================================================
func test_pretrain_framework() {
    print("\n" + "="*60)
    print("Testing NEURX Pretraining Framework")
    print("="*60)
    
    // Test 1: Create default config
    print("\n[Test 1] Creating NEURX-5.2 pretrain config...")
    pretrain_config cfg = create_neurx_200b_pretrain_config()
    assert(cfg.clm_ratio + cfg.mlm_ratio + cfg.prefix_lm_ratio == 1.0)
    assert(cfg.total_steps == 500_000)
    assert(cfg.precision == "bf16")
    print("✅ Config created!")
    
    // Test 2: Create test config
    print("\n[Test 2] Creating small test config...")
    pretrain_config test_cfg = create_test_pretrain_config()
    assert(test_cfg.world_size == 1)
    assert(test_cfg.total_steps == 1000)
    print("✅ Test config created!")
    
    // Test 3: Init pretrain state
    print("\n[Test 3] Initializing pretrain state...")
    pretrain_state state = create_pretrain_state(test_cfg)
    assert(state.current_step == 0)
    assert(state.phase == WARMUP)
    print("✅ State initialized!")
    
    // Test 4: LR scheduling
    print("\n[Test 4] Testing learning rate schedule...")
    float lr_warmup = get_learning_rate(state, step=100)  # during warmup
    float lr_peak = get_learning_rate(state, step=3000)    # after warmup
    float lr_end = get_learning_rate(state, step=99800)    # near end
    assert(lr_warmup < lr_peak)
    assert(lr_end < lr_peak)
    print(f"   Warmup LR: {lr_warmup:.6f}")
    print(f"   Peak LR:   {lr_peak:.6f}")
    print(f"   End LR:    {lr_end:.6f}")
    print("✅ LR schedule works correctly!")
    
    // Test 5: Task sampling
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
    # 允许一定误差 (±5%)
    assert(abs(clm_ratio - test_cfg.clm_ratio) < 0.05)
    assert(abs(mlm_ratio - test_cfg.mlm_ratio) < 0.05)
    assert(abs(plm_ratio - test_cfg.prefix_lm_ratio) < 0.05)
    print("✅ Task sampling distribution is correct!")
    
    // Test 6: Phase transitions
    print("\n[Test 6] Testing training phase transitions...")
    state.current_step = 100    # 10% → stable
    update_training_phase(state)
    assert(state.phase == STABLE_TRAINING)
    
    state.current_step = 450_000  # 90% → long context
    update_training_phase(state)
    assert(state.phase == LONG_CONTEXT_PHASE)
    
    state.current_step = 499_000  # 99.8% → fine-tuning
    update_training_phase(state)
    assert(state.phase == FINE_TUNING_PHASE)
    print("✅ Phase transitions work correctly!")
    
    // Test 7: Data preparation
    print("\n[Test 7] Testing data preparation functions...")
    tokenizer_state tok = create_tokenizer("vocab/neurx.model")
    
    # CLM batch
    string[] texts = ["Hello world", "Test sentence"]
    dict[str, any] clm_batch = prepare_clm_batch(tok, texts, max_len=64)
    assert(shape(clm_batch["input_ids"]) == (2, 64))
    assert("labels" in clm_batch)
    print("✅ CLM batch preparation works!")
    
    # MLM batch
    dict[str, any] mlm_batch = prepare_mlm_batch(tok, texts, max_len=64)
    assert(shape(mlm_batch["input_ids"]) == (2, 64))
    assert("mask_positions" in mlm_batch)
    print("✅ MLM batch preparation works!")
    
    # PrefixLM batch
    string[] prefixes = ["Translate:", "Summarize:"]
    string[] conts = ["Hello", "This is a test."]
    dict[str, any] plm_batch = prepare_prefix_lm_batch(tok, prefixes, conts, max_len=64)
    assert(shape(plm_batch["input_ids"]) == (2, 64))
    assert("sop_positions" in plm_batch)
    assert("eop_positions" in plm_batch)
    print("✅ PrefixLM batch preparation works!")
    
    print("\n" + "="*60)
    print("All pretraining framework tests passed! ✨")
    print("="*60 + "\n")
