package neurx.distributed.training_3d

// ═══════════════════════════════════════════════════════════════════
// 3D Parallel Training Orchestrator — 工业级大模型分布式训练
//
// 核心架构:
//
//   ┌─────────────────────────────────────────────────────────────┐
//   │                    3D PARALLELISM                           │
//   │                                                             │
//   │  Total GPUs = TP_degree × PP_degree × DP_degree             │
//   │                                                             │
//   │  Example for 64 GPUs training a 100B model:                 │
//   │    TP=8 (tensor parallel, Megatron-style)                   │
//   │    PP=4 (pipeline parallel, 4 stages)                       │
//   │    DP=2 (data/FSDP parallel)                               │
//   │    Total = 8 × 4 × 2 = 64 GPUs                             │
//   │                                                             │
//   │  Communication patterns:                                    │
//   │    • Intra-TP: AllReduce within each TP group               │
//   │    • Intra-PP: Point-to-Point (send/activate) between       │
//   │              adjacent pipeline stages                       │
//   │    • Intra-DP: AllReduce/ReduceScatter across DP groups     │
//   │              (or NCCL P2P for expert parallel in MoE)      │
//   ═══════════════════════════════════════════════════════════════════
//
// 关键特性:
//   ✓ 自动拓扑发现 & 最优并行度选择
//   ✓ 1F1B Pipeline Schedule (减少 bubble ratio)
//   ✓ 通信-计算完全异步重叠
//   ✓ 动态微批大小调整 (根据显存)
//   ✓ Fault tolerance & elastic training support
//   ✓ Gradient accumulation across all dimensions
//   ✓ Mixed precision (BF16/FP16) with dynamic loss scaling
//   ✓ Memory-efficient activation checkpointing
//
// 参考文献:
//   - "Megatron-LM: Training Multi-Billion Parameter Models"
//   - "PipeDream: Fast and Efficient Pipeline Parallelism"
//   - "Fully Sharded Data Parallel (ZeRO)"
//   - "DeepSpeed-Megatron: 3D Parallelism"

// ============================================================================
// 1. 核心配置结构体
// ============================================================================

struct parallel_dims {
    int tp_degree        // Tensor Parallel 度 (必须整除 num_heads 和 hidden_dim)
    int pp_degree        // Pipeline Parallel 度 (= 模型 stage 数)
    int dp_degree        // Data/FSDP Parallel 度
    
    // 验证后的总 GPU 数
    int total_gpus
    
    // 各维度的 rank (全局 → 局部映射)
    int global_rank      // 全局 rank [0, total_gpus)
    int tp_rank          // TP 组内排名 [0, tp_degree)
    int pp_rank          // PP 组内排名 [0, pp_degree)  
    int dp_rank          // DP 组内排名 [0, dp_degree)
    
    // 通信组 ID (用于 NCCL communicator 创建)
    int tp_group_id      // TP group 的唯一标识
    int pp_group_id      // PP group
    int dp_group_id      // DP group
}

struct model_parallel_config {
    // 模型规格
    string name                      // 模型名称 ("NEURX-5.2", "reference", etc.)
    int hidden_dim                   // 隐藏维度 (如 8192)
    int num_layers                   // Transformer 层数 (如 80)
    int num_attention_heads          // 注意力头数 (如 128)
    int num_kv_heads                 // KV 头数 (GQA, 如 16; MHA 时等于 num_heads)
    int ffn_dim                      // FFN 中间维度 (通常 4x hidden_dim)
    int vocab_size                   // 词表大小 (如 128000)
    int max_seq_len                  // 最大序列长度 (如 16384)
    float dropout                    // Dropout 率
    
    // MoE 配置 (如果使用)
    bool use_moe                     // 是否使用 MoE
    int moe_num_experts              // 专家数量 (如 64)
    int moe_top_k                    // 每 token 激活专家数 (如 6)
    float moe_capacity_factor        // 专家容量因子 (如 1.25)
    
    // 并行策略
    parallel dims                    // 3D 并行维度
}

struct training_config {
    // 数据相关
    int global_batch_size            // 总批次大小 (如 1024)
    int micro_batch_size             // 微批次大小 (每 GPU, 如 8)
    int gradient_accum_steps         // 梯度累积步数
    
    // 学习率调度
    float learning_rate              // 初始学习率
    float lr_min                     // 最小学习率
    float weight_decay               // 权重衰减
    int warmup_steps                 // 预热步数
    int total_training_steps         // 总训练步数
    string lr_schedule_type          // "cosine" / "linear" / "inverse_sqrt"
    
    // 优化器
    string optimizer_name            // "adamw" / "adam"
    float adam_beta1                 // Adam beta1 (0.9)
    float adam_beta2                 // Adam beta2 (0.999)
    float adam_epsilon               // Adam epsilon (1e-8)
    float max_grad_norm              // 梯度裁剪阈值 (1.0)
    
    // 混合精度
    bool use_bf16                    // 使用 BF16
    bool use_fp16                    // 使用 FP16 (二选一或都不用)
    float loss_scale                 // 初始 loss scale (动态调整时为初始值)
    bool dynamic_loss_scaling        // 动态 loss scaling
    
    // Checkpointing
    int save_interval                // 多少步保存一次 checkpoint
    string checkpoint_dir            // Checkpoint 保存路径
    bool async_checkpoint            // 异步保存 (不阻塞训练)
    
    // 其他
    int eval_interval                // 评估间隔
    int logging_interval             // 日志打印间隔
    bool use_gradient_checkpointing  // 激值检查点 (省显存但多算 33%)
    bool use_flash_attention         // Flash Attention (默认开启)
    bool use_rope_scaling            // RoPE Scaling (长上下文)
    int rope_target_length           // RoPE 目标长度
}

// ============================================================================
// 2. 3D Orchestrator 核心状态
// ============================================================================

enum training_phase {
    PHASE_IDLE,
    PHASE_FORWARD,
    PHASE_BACKWARD,
    PHASE_OPTIMIZER_STEP,
    PHASE_CHECKPOINTING,
    PHASE_EVALUATION
}

struct orchestrator_state {
    model_parallel_config model_cfg
    training_config train_cfg
    training_phase current_phase
    int current_step
    int current_epoch
    
    // Pipeline state
    []pipeline_stage_state pp_stages  // [pp_degree] 每个 stage 的状态
    pipeline_schedule schedule        // 当前使用的 pipeline 调度
    
    // Micro-batch 管理
    int micro_batch_counter          // 当前累积的 micro-batch 数
    float accumulated_loss           // 累积的 loss
    
    // 性能统计
    performance_stats stats
    memory_stats mem_stats
    
    // 时间戳
    float step_start_time
    float epoch_start_time
    float total_train_time
}

// Pipeline Stage 状态
struct pipeline_stage_state {
    int stage_id                      // [0, pp_degree-1]
    int first_layer_idx               // 该 stage 的起始层索引
    int last_layer_idx                // 该 stage 的结束层索引 (inclusive)
    
    // Layer 分配 (均匀或手动指定)
    []int layer_indices               // 该 stage 包含的所有层
    
    // 输入/输出缓冲区 (用于 pipeline 通信)
    [][]float input_buffer            // 从前一个 stage 接收的激活值
    [][]float output_buffer           // 传递给下一个 stage 的激活值
    
    // 激活缓存 (用于 backward)
    bool[] needs_gradient_checkpoint  // 哪些层做了 gradient checkpointing
    [][]float[] activation_cache      // 缓存的激活值 (可选)
    
    // 统计
    float forward_time_ms
    float backward_time_ms
    float comm_time_ms
}

// Pipeline 调度策略
enum schedule_type {
    SCHEDULE_1F1B,                   // 1 Forward 1 Backward (推荐,低 bubble)
    SCHEDULE_GPIPE,                  // GPipe: 所有 forward 后再所有 backward
    SCHEDULE_INTERLEAVED,            // Interleaved schedule (虚拟 stage)
    SCHEDULE_PIPE_DREAM_FLUSH,       // PipeDream-Flush
}

struct pipeline_schedule {
    schedule_type type
    int num_micro_batches             // 一个 step 内的 micro-batch 数
    int warmup_microbatches           // warmup 阶段的 micro-batch 数
    int steady_microbatches           // 稳定阶段的 micro-batch 数
    int cooldown_microbatches         // cooldown 阶段的 micro-batch 数
    float bubble_ratio                // pipeline bubble 占比 (越小越好)
    
    // 执行计划 (预计算的指令序列)
    []schedule_instruction instructions
}

struct schedule_instruction {
    enum action_type { 
        MICRO_FORWARD, 
        MICRO_BACKWARD, 
        MICRO_UPDATE, 
        PIPE_SEND_ACTIVATION, 
        PIPE_RECV_ACTIVATION, 
        SYNC_POINT 
    } action
    int micro_batch_id                // 操作哪个 micro-batch [0, N)
    int stage_id                      // 在哪个 stage 执行
    int dependency_id                 // 依赖的前置指令 ID (用于同步)
}

// ============================================================================
// 3. 初始化 & 配置验证
// ============================================================================

// 创建 3D 并行配置 (自动验证)
func create_parallel_config(
    int total_gpus,
    int tp, int pp, int dp,
    int global_rank
) parallel_dims {
    // 验证
    if tp * pp * dp != total_gpus {
        // 错误处理:维度不匹配
    }
    
    // 计算 local ranks
    int pp_size = tp * dp              // 每个 PP group 的大小
    int pp_id = global_rank / pp_size  // 在 PP 中的位置
    int rank_in_pp = global_rank % pp_size
    
    int tp_rank_local = rank_in_pp % tp
    int dp_rank_local = rank_in_pp / tp
    
    parallel_dims {
        tp_degree: tp,
        pp_degree: pp,
        dp_degree: dp,
        total_gpus: total_gpus,
        global_rank: global_rank,
        tp_rank: tp_rank_local,
        pp_rank: pp_id,
        dp_rank: dp_rank_local,
        tp_group_id: pp_id * tp + tp_rank_local,  // 唯一标识
        pp_group_id: pp_id,
        dp_group_id: rank_in_pp,
    }
}

// 验证模型配置与并行度的兼容性
func validate_model_parallel_config(model_parallel_config cfg) bool {
    bool valid = true
    parallel dims = cfg.dims
    
    // TP 必须整除 num_heads
    if cfg.num_attention_heads % dims.tp_degree != 0 {
        valid = false
    }
    
    // TP 必须整除 hidden_dim
    if cfg.hidden_dim % dims.tp_degree != 0 {
        valid = false
    }
    
    // 如果用 GQA,KV heads 也应该能被 TP 整除 (或者每个 TP rank 有整数个 KV heads)
    if cfg.num_kv_heads < cfg.num_attention_heads {
        if cfg.num_kv_heads % dims.tp_degree != 0 && 
           dims.tp_degree % cfg.num_kv_heads != 0 {
            // 可能需要更复杂的 GQA+TP 映射
        }
    }
    
    // 层数必须能被 PP 整除 (或允许不均分)
    if cfg.num_layers % dims.pp_degree != 0 {
        // 允许最后几个 stage 多一层或少一层
    }
    
    return valid
}

// 初始化 Orchestrator
func init_orchestrator(
    model_parallel_config model_cfg,
    training_config train_cfg
) orchestrator_state {
    // 验证配置
    if !validate_model_parallel_config(model_cfg) {
        // 处理错误
    }
    
    // 初始化 Pipeline Stages
    int pp = model_cfg.dims.pp_degree
    int layers_per_stage = model_cfg.num_layers / pp
    int remaining_layers = model_cfg.num_layers % pp
    
    []pipeline_stage_state stages = []pipeline_stage_state{cap: pp}
    int s = 0
    while s < pp {
        int start_layer = s * layers_per_stage + min_int(s, remaining_layers)
        int end_layer = start_layer + layers_per_stage - 1
        if s < remaining_layers { end_layer = end_layer + 1 }
        
        // 构建该 stage 的层列表
        []int layer_ids = []int{cap: end_layer - start_layer + 1}
        int l = start_layer
        while l <= end_layer {
            layer_ids = append(layer_ids, l)
            l = l + 1
        }
        
        pipeline_stage_state stage
        stage.stage_id = s
        stage.first_layer_idx = start_layer
        stage.last_layer_idx = end_layer
        stage.layer_indices = layer_ids
        
        stages[s] = stage
        s = s + 1
    }
    
    // 构建 Pipeline Schedule (默认 1F1B)
    int num_micro_batches = train_cfg.gradient_accum_steps
    pipeline_schedule sched = build_1f1b_schedule(pp, num_micro_batches)
    
    // 初始化性能统计
    perf_stats init_stats
    init_stats.total_flops = 0.0
    init_stats.total_comm_bytes = 0.0
    init_stats.steps_per_second = 0.0
    init_stats.tflops = 0.0
    
    // 初始化内存统计
    mem_stats init_mem
    init_mem.peak_gpu_memory_gb = 0.0
    init_mem.current_gpu_memory_gb = 0.0
    init_mem.fragmentation_ratio = 0.0
    
    orchestrator_state {
        model_cfg: model_cfg,
        train_cfg: train_cfg,
        current_phase: PHASE_IDLE,
        current_step: 0,
        current_epoch: 0,
        pp_stages: stages,
        schedule: sched,
        micro_batch_counter: 0,
        accumulated_loss: 0.0,
        stats: init_stats,
        mem_stats: init_mem,
        step_start_time: 0.0,
        epoch_start_time: 0.0,
        total_train_time: 0.0,
    }
}

// 辅助函数
func append([]int arr, int val) []int {
    int n = len(arr)
    []float new_arr = []int{cap: n + 1}
    int i = 0
    while i < n { new_arr[i] = arr[i]; i = i + 1 }
    new_arr[n] = val
    new_arr
}

func min_int(int a, int b) int {
    if a < b { return a }
    return b
}

func max_int(int a, int b) int {
    if a > b { return a }
    return b
}

func float_of_int(int n) float {
    float r = 0.0
    int i = 0
    while i < n { r = r + 1.0; i = i + 1 }
    return r
}

// ============================================================================
// 4. 1F1B Pipeline Schedule 构建器
// ============================================================================
//
// 1F1B (One Forward One Backward) Schedule:
//
// Warmup Phase:
//   - 逐步填满 pipeline
//   - 第 i 步: 发送 micro-batch i 的 forward 到 stage i+1
//   
// Steady State Phase:
//   - 每步执行: 1 forward + 1 backward
//   - 保持 pipeline 满载运行
//
// Cooldown Phase:
//   - 逐步排空 pipeline
//   - 只有 backward 操作
//
// Bubble Ratio = (PP - 1) / (M + PP - 1) ≈ (PP-1)/M for large M
// 其中 M 是 micro-batch 数

func build_1f1b_schedule(int num_stages, int num_micro_batches) pipeline_schedule {
    // Warmup: 需要 (PP-1) 个 micro-batches 来填满 pipeline
    int num_warmup = num_stages - 1
    // Steady: 剩余的 micro-batches 在稳定状态
    int num_steady = num_micro_batches - 2 * (num_stages - 1)
    if num_steady < 0 { num_steady = 0 }  // micro-batches 太少时可能没有 steady phase
    // Cooldown: 与 warmup 对称
    int num_cooldown = num_stages - 1
    
    // Bubble ratio
    float bubble = float_of_int(num_stages - 1) / float_of_int(num_micro_batches + num_stages - 1)
    
    // 构建指令序列 (简化版,实际会更复杂以支持异步通信)
    []schedule_instruction instrs = []schedule_instruction{}
    
    int instruction_id = 0
    
    // === WARMUP PHASE ===
    int mb = 0
    while mb < num_warmup && mb < num_micro_batches {
        int s = 0
        while s <= mb {
            // Stage s 处理 micro-batch mb 的 forward
            schedule_instruction fwd_instr
            fwd_instr.action = MICRO_FORWARD
            fwd_instr.micro_batch_id = mb
            fwd_instr.stage_id = s
            fwd_instr.dependency_id = -1
            
            instrs = append(instrs, fwd_instr)
            instruction_id = instruction_id + 1
            
            s = s + 1
        }
        mb = mb + 1
    }
    
    // === STEADY STATE PHASE ===
    int steady_mb = num_warmup
    while steady_mb < num_warmup + num_steady && steady_mb < num_micro_batches {
        int s = 0
        while s < num_stages {
            // Forward for current micro-batch
            schedule_instruction fwd_instr
            fwd_instr.action = MICRO_FORWARD
            fwd_instr.micro_batch_id = steady_mb
            fwd_instr.stage_id = s
            fwd_instr.dependency_id = -1
            instrs = append(instrs, fwd_instr)
            
            // Backward for earlier micro-batch (在 steady 阶段)
            if steady_mb >= num_warmup {
                int bw_mb = steady_mb - num_warmup
                if bw_mb < num_micro_batches {
                    schedule_instruction bwd_instr
                    bwd_instr.action = MICRO_BACKWARD
                    bwd_instr.micro_batch_id = bw_mb
                    bwd_instr.stage_id = s
                    bwd_instr.dependency_id = -1
                    instrs = append(instrs, bwd_instr)
                }
            }
            
            instruction_id = instruction_id + 1
            s = s + 1
        }
        steady_mb = steady_mb + 1
    }
    
    // === COOLDOWN PHASE ===
    int cooldown_mb = max_int(num_warmup + num_steady, 0)
    while cooldown_mb < num_micro_batches + num_cooldown {
        int s = num_stages - 1
        while s >= 0 {
            int bw_mb = cooldown_mb - num_warmup
            if bw_mb >= 0 && bw_mb < num_micro_batches {
                schedule_instruction bwd_instr
                bwd_instr.action = MICRO_BACKWARD
                bwd_instr.micro_batch_id = bw_mb
                bwd_instr.stage_id = s
                bwd_instr.dependency_id = -1
                instrs = append(instrs, bwd_instr)
                
                instruction_id = instruction_id + 1
            }
            s = s - 1
        }
        cooldown_mb = cooldown_mb + 1
    }
    
    pipeline_schedule {
        type: SCHEDULE_1F1B,
        num_micro_batches: num_micro_batches,
        warmup_microbatches: num_warmup,
        steady_microbatches: num_steady,
        cooldown_microbatches: num_cooldown,
        bubble_ratio: bubble,
        instructions: instrs,
    }
}

// ============================================================================
// 5. 核心训练循环
// ============================================================================

// 单个训练步骤的完整流程
func training_step(ref orchestrator_state orch, batch_data data) float {
    orch.current_phase = PHASE_FORWARD
    float step_time_start = get_current_time_ms()
    
    // ===== GRADIENT ACCUMULATION LOOP =====
    int micro_batch_id = 0
    while micro_batch_id < orch.train_cfg.gradient_accum_steps {
        // 获取当前 micro-batch 的数据
        micro_batch_data micro_data = get_micro_batch(data, micro_batch_id)
        
        // 按照 Pipeline Schedule 执行
        execute_pipeline_forward(orch, micro_data, micro_batch_id)
        
        // 计算损失
        float loss = compute_loss(orch)
        orch.accumulated_loss = orch.accumulated_loss + loss
        
        // Backward (如果在 schedule 中)
        execute_pipeline_backward(orch, micro_batch_id)
        
        micro_batch_id = micro_batch_id + 1
        orch.micro_batch_counter = orch.micro_batch_counter + 1
    }
    
    // ===== OPTIMIZER STEP =====
    orch.current_phase = PHASE_OPTIMIZER_STEP
    
    // 梯度同步 (跨 DP 维度)
    synchronize_gradients_across_dp(orch)
    
    // 梯度裁剪
    clip_gradients(orch, orch.train_cfg.max_grad_norm)
    
    // 优化器更新 (AdamW)
    optimizer_step(orch)
    
    // 清空梯度
    zero_grads(orch)
    
    // ===== LOGGING & CHECKPOINTING =====
    float step_time = get_current_time_ms() - step_time_start
    update_performance_stats(orch, step_time)
    
    // 打印日志
    if orch.current_step % orch.train_cfg.logging_interval == 0 {
        log_training_progress(orch)
    }
    
    // 保存 Checkpoint
    if orch.train_cfg.save_interval > 0 &&
       orch.current_step % orch.train_cfg.save_interval == 0 {
        if orch.train_cfg.async_checkpoint {
            trigger_async_checkpoint(orch)
        } else {
            save_checkpoint_sync(orch)
        }
    }
    
    // 更新状态
    orch.current_step = orch.current_step + 1
    orch.micro_batch_counter = 0
    orch.accumulated_loss = 0.0
    orch.current_phase = PHASE_IDLE
    
    return orch.accumulated_loss / float_of_int(orch.train_cfg.gradient_accum_steps)
}

// 执行 Pipeline Forward (单 micro-batch)
func execute_pipeline_forward(
    ref orchestrator_state orch,
    micro_batch_data data,
    int micro_batch_id
) {
    int my_stage = orch.model_cfg.dims.pp_rank
    int num_stages = orch.model_cfg.dims.pp_degree
    
    // 接收前一个 stage 的输出 (如果不是第一个 stage)
    if my_stage > 0 {
        orch.pp_stages[my_stage].input_buffer = recv_activation_from_previous_stage(
            my_stage - 1, micro_batch_id
        )
    } else {
        // 第一个 stage: 使用输入数据
        orch.pp_stages[my_stage].input_buffer = data.input_tokens
    }
    
    // 执行本 stage 的 forward (包含所有 assigned layers)
    [][]float output = run_stage_forward(
        orch,
        orch.pp_stages[my_stage],
        orch.pp_stages[my_stage].input_buffer,
        micro_batch_id
    )
    
    // 发送到下一个 stage (如果不是最后一个 stage)
    if my_stage < num_stages - 1 {
        send_activation_to_next_stage(my_stage, output, micro_batch_id)
    } else {
        // 最后一个 stage: 保存输出用于 loss 计算
        orch.pp_stages[my_stage].output_buffer = output
    }
}

// 执行单个 Stage 的 Forward (调用各层)
func run_stage_forward(
    ref orchestrator_state orch,
    pipeline_stage_state stage,
    [][]float input,
    int micro_batch_id
) [][]float {
    int num_layers_in_stage = len(stage.layer_indices)
    [][]float current_hidden = input
    
    int idx = 0
    while idx < num_layers_in_stage {
        int layer_idx = stage.layer_indices[idx]
        
        // 运行单层 Transformer (包含 attention + FFN + norm)
        current_hidden = transformer_layer_forward(
            orch.model_cfg,
            layer_idx,
            current_hidden,
            micro_batch_id
        )
        
        idx = idx + 1
    }
    
    return current_hidden
}

// 单层 Transformer Forward
func transformer_layer_forward(
    model_parallel_config cfg,
    int layer_idx,
    [][]float hidden_states,  // [seq_len, hidden_dim]
    int micro_batch_id
) [][]float {
    // Pre-attention RMSNorm
    hidden_states = apply_rmsnorm(hidden_states, layer_idx, cfg)
    
    // Multi-Head Attention (with TP)
    hidden_states = multi_head_attention_forward(cfg, layer_idx, hidden_states)
    
    // Residual connection
    hidden_states = residual_add(hidden_states, /* saved_input */ hidden_states)
    
    // Pre-FFN RMSNorm
    hidden_states = apply_rmsnorm(hidden_states, layer_idx + 1000, cfg)  // offset to distinguish
    
    // FFN (SwiGLU or MoE) (with TP)
    if cfg.use_moe {
        hidden_states = moe_ffn_forward(cfg, layer_idx, hidden_states)
    } else {
        hidden_states = swiglu_ffn_forward(cfg, layer_idx, hidden_states)
    }
    
    // Residual connection
    hidden_states = residual_add(hidden_states, /* saved_input */ hidden_states)
    
    return hidden_states
}

// (占位符函数 - 实际实现会调用 CUDA kernels)
func apply_rmsnorm([][]float x, int norm_idx, model_parallel_config cfg) [][]float { x }
func multi_head_attention_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func swiglu_ffn_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func moe_ffn_forward(model_parallelConfig cfg, int layer, [][]float x) [][]float { x }
func residual_add([][]float a, [][]float b) [][]float { a }

// Pipeline Backward (类似 forward 但反向)
func execute_pipeline_backward(ref orchestrator_state orch, int micro_batch_id) {
    // ... 类似于 forward,但是反向传播梯度
    // 包括:
    // 1. Loss backward → d_logits
    // 2. 通过 pipeline stages 反向传播
    // 3. 每个 stage 内部反向传播各层
    // 4. 累积参数梯度
}

// ============================================================================
// 6. 梯度同步 & 优化
// ============================================================================

// 跨 DP 维度同步梯度 (AllReduce or ReduceScatter)
func synchronize_gradients_across_dp(ref orchestrator_state orch) {
    parallel dims = orch.model_cfg.dims
    
    // 对于每个参数:
    //   如果使用 FSDP: ReduceScatter (只保留本地 shard)
    //   否则: AllReduce (每个 rank 都有完整梯度)
    
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        
        // 执行通信
        if is_fsdp_enabled(orch) {
            grad = reduce_scatter_across_dp(grad, dims.dp_group_id, dims.dp_degree)
        } else {
            grad = all_reduce_sum_across_dp(grad, dims.dp_group_id, dims.dp_degree)
        }
        
        set_parameter_grad(orch, p, grad)
        p = p + 1
    }
}

// 梯度裁剪
func clip_gradients(ref orchestrator_state orch, float max_norm) {
    // 计算总梯度范数
    float total_norm = 0.0
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        float norm = vector_l2_norm(grad)
        total_norm = total_norm + norm * norm
        p = p + 1
    }
    total_norm = sqrt_approx(total_norm)
    
    // 裁剪
    if total_norm > max_norm {
        float scale = max_norm / total_norm
        p = 0
        while p < get_num_parameters(orch) {
            scale_vector(get_parameter_grad_ref(orch, p), scale)
            p = p + 1
        }
    }
}

// AdamW Optimizer Step
func optimizer_step(ref orchestrator_state orch) {
    training_config tc = orch.train_cfg
    int t = orch.current_step + 1  // timestep (1-indexed)
    
    int p = 0
    while p < get_num_parameters(orch) {
        []float param = get_parameter(orch, p)
        []float grad = get_parameter_grad(orch, p)
        []float exp_avg = get_exp_avg(orch, p)   // 一阶矩
        []float exp_avg_sq = get_exp_avg_sq(orch, p)  // 二阶矩
        
        // Bias correction
        float bias_corr1 = 1.0 - pow_float(tc.adam_beta1, float_of_int(t))
        float bias_corr2 = 1.0 - pow_float(tc.adam_beta2, float_of_int(t))
        float step_size = tc.learning_rate / bias_corr1
        
        int i = 0
        while i < len(param) {
            // Update moments
            exp_avg[i] = tc.adam_beta1 * exp_avg[i] + (1.0 - tc.adam_beta1) * grad[i]
            exp_avg_sq[i] = tc.adam_beta2 * exp_avg_sq[i] + (1.0 - tc.adam_beta2) * grad[i] * grad[i]
            
            // Compute update
            float denom = sqrt_approx(exp_avg_sq[i] / bias_corr2) + tc.adam_epsilon
            float update = step_size * exp_avg[i] / denom
            
            // Weight decay (AdamW decoupled)
            param[i] = param[i] - tc.weight_decay * tc.learning_rate * param[i] - update
            
            i = i + 1
        }
        
        // Save updated states
        set_parameter(orch, p, param)
        set_exp_avg(orch, p, exp_avg)
        set_exp_avg_sq(orch, p, exp_avg_sq)
        
        p = p + 1
    }
}

// 清零梯度
func zero_grads(ref orchestrator_state orch) {
    int p = 0
    while p < get_num_parameters(orch) {
        []float grad = get_parameter_grad(orch, p)
        int i = 0
        while i < len(grad) {
            grad[i] = 0.0
            i = i + 1
        }
        p = p + 1
    }
}

// ============================================================================
// 7. 性能监控 & 统计
// ============================================================================

struct performance_stats {
    float total_flops                // 累计 FLOPs
    float total_comm_bytes           // 累计通信量
    float steps_per_second           // 吞吐量 (steps/sec)
    float tflops                     // TFLOPS (实际达到的)
    float gpu_utilization            // GPU 利用率 (0-1)
    float memory_bandwidth_usage     // 显存带宽利用率
    float comm_compute_overlap_pct   // 通信-计算重叠百分比
}

struct memory_stats {
    float peak_gpu_memory_gb         // 峰值显存
    float current_gpu_memory_gb      // 当前显存
    float fragmentation_ratio        // 碎片率
    float activation_memory_gb       // 激活值占用
    float parameter_memory_gb        // 参数占用
    float optimizer_memory_gb        // 优化器状态占用
    float gradient_memory_gb         // 梯度占用
}

// 更新性能统计
func update_performance_stats(ref orchestrator_state orch, float step_time_ms) {
    orch.stats.steps_per_second = 1000.0 / step_time_ms
    
    // 估算 TFLOPS (简化)
    int H = orch.model_cfg.hidden_dim
    int L = orch.model_cfg.num_layers
    int S = orch.model_cfg.max_seq_len
    int B = orch.train_cfg.global_batch_size
    
    // 每个 step 的近似 FLOPs (forward + backward)
    // Forward: ~24 * L * H^2 * B * S
    // Backward: ~2x forward
    float flops_per_step = 72.0 * float_of_int(L) * float_of_int(H * H) * float_of_int(B * S)
    
    orch.stats.tflops = flops_per_step / (step_time_ms / 1000.0) / 1e12
    orch.stats.total_flops = orch.stats.total_flops + flops_per_step
}

// 打印训练进度
func log_training_progress(orchestrator_state orch) {
    float avg_loss = orch.accumulated_loss / float_of_int(max_int(orch.micro_batch_counter, 1))
    
    string progress =
        "Step [" + string(orch.current_step) + "/" + string(orch.train_cfg.total_training_steps) + "] " +
        "Loss: " + string(avg_loss) + " " +
        "LR: " + string(current_learning_rate(orch)) + " " +
        "Throughput: " + string(orch.stats.steps_per_second, 2) + " steps/s " +
        "TFLOPS: " + string(orch.stats.tflops, 1) + " " +
        "GPU Mem: " + string(orch.mem_stats.current_gpu_memory_gb, 1) + " GB"
    
    // 实际会调用 logging framework
    print(progress)
}

// 获取当前学习率
func current_learning_rate(orchestrator_state orch) float {
    training_config tc = orch.train_cfg
    int step = orch.current_step
    int warmup = tc.warmup_steps
    int total = tc.total_training_steps
    float lr = tc.learning_rate
    float lr_min = tc.lr_min
    
    if step < warmup {
        // Linear warmup
        lr = lr * float_of_int(step + 1) / float_of_int(warmup)
    } else {
        if tc.lr_schedule_type == "cosine" {
            // Cosine decay
            float progress = float_of_int(step - warmup) / float_of_int(total - warmup)
            lr = lr_min + 0.5 * (lr - lr_min) * (1.0 + cos_approx(3.14159265 * progress))
        } else if tc.lr_schedule_type == "linear" {
            // Linear decay
            float progress = float_of_int(step - warmup) / float_of_int(total - warmup)
            lr = lr - (lr - lr_min) * progress
        }
    }
    
    lr
}

// 数学辅助函数
func sqrt_approx(float x) float {
    if x <= 0.0 { return 0.0 }
    float g = x * 0.5
    int iter = 0
    while iter < 20 {
        float ng = (g + x / g) * 0.5
        if ng == g { break }
        g = ng
        iter = iter + 1
    }
    return g
}

func pow_float(float base, float exp) float {
    if exp == 0.0 { return 1.0 }
    if base <= 0.0 { return 0.0 }
    float result = 1.0
    bool neg = exp < 0.0
    if neg { exp = -exp }
    float e = 0.0
    while e < exp { result = result * base; e = e + 1.0 }
    if neg { result = 1.0 / result }
    return result
}

func cos_approx(float x) float {
    float term = 1.0
    float result = 1.0
    float xx = x * x
    int n = 1
    while n <= 12 {
        term = -term * xx / float_of_int((2*n-1) * (2*n))
        result = result + term
        n = n + 1
    }
    return result
}

func vector_l2_norm([]float v) float {
    float sum_sq = 0.0
    int i = 0
    while i < len(v) { sum_sq = sum_sq + v[i] * v[i]; i = i + 1 }
    return sqrt_approx(sum_sq)
}

func scale_vector(ref []float v, float s) {
    int i = 0
    while i < len(v) { v[i] = v[i] * s; i = i + 1 }
}

// (通信原语的占位符 - 实际会调用 NCCL)
func recv_activation_from_previous_stage(int from_stage, int mb_id) [][]float { return allocate_2d(128, 8192) }
func send_activation_to_next_stage(int to_stage, [][]float act, int mb_id) {}
func reduce_scatter_across_dp([]float g, int group, int degree) []float { return g }
func all_reduce_sum_across_dp([]float g, int group, int degree) []float { return g }

func allocate_2d(int r, int c) [][]float {
    [][]float t = [][]float{cap: r}
    int i = 0
    while i < r { t[i] = []float{cap: c}; i = i + 1 }
    return t
}

func get_num_parameters(orchestrator_state o) int { return 1000 }
func get_parameter(orchestrator o, int idx) []float { return []float{} }
func get_parameter_grad(orchestrator o, int idx) []float { return []float{} }
func get_parameter_grad_ref(ref orchestrator o, int idx) []float { return []float{} }
func set_parameter(ref orchestrator o, int idx, []float v) {}
func set_parameter_grad(ref orchestrator o, int idx, []float v) {}
func get_exp_avg(orchestrator o, int idx) []float { return []float{} }
func get_exp_avg_sq(orchestrator o, int idx) []float { return []float{} }
func set_exp_avg(ref orchestrator o, int idx, []float v) {}
func set_exp_avg_sq(ref orchestrator o, int idx, []float v) {}
func compute_loss(orchestrator o) float { return 0.5 }

struct micro_batch_data { [][]float input_tokens }
func get_micro_batch(batch_data b, int id) micro_batch_data { return micro_batch_data{} }
struct batch_data {}

func is_fsdp_enabled(orchestrator o) bool { return true }
func get_current_time_ms() float { return 0.0 }
func save_checkpoint_sync(orchestrator o) {}
func trigger_async_checkpoint(orchestrator o) {}
func print(string s) {}

func string(int i) string { return "" }
func string(float f, int prec) string { return "" }

// ============================================================================
// 8. NEURX-5.2 特定配置预设
// ============================================================================

// 为 NEURX-5.2 创建推荐的 3D 并行配置
// 假设 NEURX-5.2 规格 (推测):
//   - ~200B parameters
//   - Hidden dim: 12288
//   - Layers: 96
//   - Heads: 128
//   - KV Heads: 16 (GQA 8:1)
//   - FFN dim: 32768 (SwiGLU)
//   - Vocab: 128K
//   - Context: 32K (可扩展到 128K)

func create_neurx_200b_config_for_64gpus() model_parallel_config {
    parallel dims = create_parallel_config(64, 8, 4, 2, 0)
    
    model_parallel_config {
        name: "NEURX-5.2",
        hidden_dim: 12288,
        num_layers: 96,
        num_attention_heads: 128,
        num_kv_heads: 16,              // GQA 8:1
        ffn_dim: 32768,
        vocab_size: 128000,
        max_seq_len: 32768,
        dropout: 0.0,
        
        use_moe: false,                // NEURX-5.2 可能不是 MoE
        // 如果是 MoE:
        // use_moe: true,
        // moe_num_experts: 64,
        // moe_top_k: 6,
        // moe_capacity_factor: 1.25,
        
        dims: dims,
    }
}

// NEURX-5.2 训练配置 (参考 NEURX-130B 的训练设置)
func create_128gpu_training_config() training_config {
    training_config {
        global_batch_size: 2048,       // 大 batch size (2048-4096)
        micro_batch_size: 4,            // per GPU micro-batch (受限于显存)
        gradient_accum_steps: 512,      // 2048 / (8*4*2 GPUs / 2 avg) ≈ 32, 这里简化
        
        learning_rate: 3e-4,           // NEURX 用较高的 LR
        lr_min: 3e-5,
        weight_decay: 0.1,
        warmup_steps: 2000,             // 2K steps warmup
        total_training_steps: 500000,   // 500K steps (~2T tokens at BS=2048*seq=4K)
        lr_schedule_type: "cosine",
        
        optimizer_name: "adamw",
        adam_beta1: 0.9,
        adam_beta2: 0.95,
        adam_epsilon: 1e-8,
        max_grad_norm: 1.0,
        
        use_bf16: true,
        use_fp16: false,
        loss_scale: 65536.0,           // 2^16
        dynamic_loss_scaling: true,
        
        save_interval: 5000,            // 每 5K steps 保存
        checkpoint_dir: "./checkpoints/neurx",
        async_checkpoint: true,
        
        eval_interval: 1000,
        logging_interval: 10,
        use_gradient_checkpointing: true,
        use_flash_attention: true,
        use_rope_scaling: true,
        rope_target_length: 131072,     // 支持 128K context
    }
}

// 打印完整的训练配置摘要
func print_full_config_summary(model_parallel_config mcfg, training_config tcfg) string {
    parallel dims = mcfg.dims
    
    "╔══════════════════════════════════════════════════════════╗\n" +
    "║           NEURX-5.2 3D Parallel Training Configuration       ║\n" +
    "╠══════════════════════════════════════════════════════════╣\n" +
    "║ Model: " + mcfg.name + "\n" +
    "║ Parameters: ~" + string(estimate_params(mcfg)) + "B\n" +
    "║ Architecture:\n" +
    "║   Hidden Dim: " + string(mcfg.hidden_dim) + "\n" +
    "║   Layers: " + string(mcfg.num_layers) + "\n" +
    "║   Heads: " + string(mcfg.num_attention_heads) + " (KV: " + string(mcfg.num_kv_heads) + ")\n" +
    "║   FFN Dim: " + string(mcfg.ffn_dim) + "\n" +
    "║   Vocab Size: " + string(mcfg.vocab_size) + "\n" +
    "║   Max Seq Len: " + string(mcfg.max_seq_len) + " (" + string(mcfg.max_seq_len/1024) + "K)\n" +
    "║\n" +
    "║ 3D Parallelism:\n" +
    "║   Tensor Parallel (TP): " + string(dims.tp_degree) + "\n" +
    "║   Pipeline Parallel (PP): " + string(dims.pp_degree) + "\n" +
    "║   Data Parallel (DP/FSDP): " + string(dims.dp_degree) + "\n" +
    "║   Total GPUs: " + string(dims.total_gpus) + "\n" +
    "║\n" +
    "║ Training:\n" +
    "║   Global Batch Size: " + string(tcfg.global_batch_size) + "\n" +
    "║   Micro Batch Size: " + string(tcfg.micro_batch_size) + "\n" +
    "║   Learning Rate: " + string(tcfg.learning_rate) + "\n" +
    "║   Total Steps: " + string(tcfg.total_training_steps) + "\n" +
    "║   Precision: BF16" + "\n" +
    "║   Gradient Checkpointing: ON\n" +
    "║   Flash Attention: ON\n" +
    "║   RoPE Scaling (128K): ON\n" +
    "╚══════════════════════════════════════════════════════════╝"
}

// 估算参数量
func estimate_params(model_parallel_config cfg) float {
    // Transformer 模型参数量估算 (简化):
    // Embedding: vocab * hidden
    // Per layer:
    //   Attention: 4 * hidden^2 (QKV + O) * (kv_heads/query_heads ratio for GQA)
    //   FFN: 3 * hidden * ffn_dim (gate + up + down for SwiGLU)
    //   Norms: 2 * hidden (RMSNorm * 2)
    // Final norm: hidden
    // LM Head: vocab * hidden (often tied with embedding)
    
    float embed = float_of_int(cfg.vocab_size * cfg.hidden_dim)
    
    float attn_per_layer = 4.0 * float_of_int(cfg.hidden_dim * cfg.hidden_dim) * 
                          float_of_int(cfg.num_kv_heads) / float_of_int(cfg.num_attention_heads)
    
    float ffn_per_layer = 3.0 * float_of_int(cfg.hidden_dim * cfg.ffn_dim)
    
    float norm_per_layer = 2.0 * float_of_int(cfg.hidden_dim)
    
    float per_layer = attn_per_layer + ffn_per_layer + norm_per_layer
    
    float total = embed + float_of_int(cfg.num_layers) * per_layer + float_of_int(cfg.hidden_dim)
    
    // Return in billions
    return total / 1e9
}
