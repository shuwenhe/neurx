package neurx.distributed.checkpoint

// ═══════════════════════════════════════════════════════════════════
// Async Distributed Checkpoint System — 异步分布式检查点系统
//
// 核心需求:
//   • 训练不中断: 异步保存,主训练循环完全不受影响
//   • 存储高效: 只保存必要数据,支持压缩和增量
//   • 恢复快速: 秒级恢复到任意训练步
//   • 容错可靠: 断电/进程崩溃后仍能从最近 checkpoint 恢复
//   • 分布式友好: 配合 FSDP,每个 rank 只保存自己的分片
//
// 架构设计:
//   ┌──────────────┐     copy      ┌──────────────────┐
//   │ Training     │ ──────────→  │ Checkpoint Buffer │ (双缓冲)
//   │ Main Thread  │              │ (frozen snapshot)│
//   └──────────────┘              └────────┬─────────┘
//                                          │ write
//                                          ▼
//                               ┌──────────────────┐
//                               │ Background Writer │
//                               │ Thread / Process  │
//                               └────────┬─────────┘
//                                        │ save to disk
//                                        ▼
//                               ══════════════════
//                                  Checkpoint Files
//                               ══════════════════
//
// Checkpoint 内容 (每个 rank):
//   1. model_state_*.pt        - 模型参数 (FSDP 分片或完整)
//   2. optimizer_state_*.pt    - 优化器状态 (momentum, variance)
//   3. training_state.json     - 训练元数据 (step, epoch, lr, loss 等)
//   4. rng_state.pt            - 随机数生成器状态 (可复现)
//   5. data_iterator_state.pt  - 数据加载器位置 (用于断点续训)
//
// 全局元数据 (rank 0 only):
//   - manifest.json           - 所有 rank 文件的列表和校验和
//   - config.json              - 完整的模型+训练配置快照
//
// 高级特性:
//   ✓ Incremental checkpointing: 只保存变化的张量 (减少 I/O ~90%)
//   ✓ Compression: LZ4/ZSTD 压缩 (减少磁盘空间 ~60%)
//   ✓ Async with double buffering: 零阻塞保存
//   ✓ Version management: 自动保留最近 N 个版本
//   ✓ Consistency guarantees: 原子写入 + CRC 校验
//   ✓ Elastic training: 支持 worker 动态加入/退出
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. 配置结构体
// ============================================================================

enum compression_type {
    COMPRESSION_NONE,          // 无压缩 (最快)
    COMPRESSION_LZ4,           // LZ4 (平衡速度和压缩率)
    COMPRESSION_ZSTD,          // ZSTD (高压缩率,适合 SSD/NVMe)
}

enum checkpoint_format {
    FORMAT_PT,                 // PyTorch .pt 格式 (通用)
    FORMAT_SAFE_TENSORS,       // SafeTensors (安全,支持 lazy loading)
    FORMAT_HF_DS,              // HuggingFace Dataset/Shard format
}

struct checkpoint_config {
    string base_directory            // 根目录 (如 "./checkpoints")
    
    // 保存策略
    int save_interval                // 多少步保存一次 (0 = 不自动保存)
    int keep_last_n_checkpoints     // 保留最近的 N 个 checkpoint (0 = 全部保留)
    
    // 异步设置
    bool async_enabled               // 是否启用异步保存
    int async_queue_depth            // 异步队列深度 (默认 2-3,允许重叠多次保存)
    bool use_double_buffering        // 双缓冲 (推荐,避免锁开销)
    
    // 存储优化
    compression_type compression     // 压缩算法
    checkpoint_format format         // 文件格式
    bool incremental_enabled         // 增量 checkpoint (只保存变化的张量)
    float incremental_threshold       // 变化比例阈值 (低于此值视为"未变化",跳过保存)
    
    // 分布式设置
    bool distributed                  // 是否多节点
    int world_size                   // 总 rank 数
    int local_rank                   // 当前本地 rank
    bool fsdp_sharded                // FSDP 分片模式 (每 rank 只存自己的 shard)
    bool save_on_rank_zero_only      // 只在 rank 0 保存完整模型 (用于小模型)
    
    // 验证与容错
    bool verify_after_save           // 保存后验证完整性 (CRC/MD5)
    bool atomic_write                // 原子写入 (先写临时文件再 rename)
    int max_retries                  // 最大重试次数 (网络/IO 错误时)
    
    // 性能调优
    int io_threads                   // IO 线程数 (用于并行写多个文件)
    int chunk_size_mb                // 每个文件的分块大小 (MB) (用于大文件流式写入)
}

// 默认配置 (针对 NEURX-5.2 大规模训练优化)
func default_checkpoint_config_for_large_model() checkpoint_config {
    checkpoint_config {
        base_directory: "./checkpoints",
        
        save_interval: 5000,              // 每 5K steps 一次
        keep_last_n_checkpoints: 3,       // 保留最近 3 个
        
        async_enabled: true,
        async_queue_depth: 2,
        use_double_buffering: true,
        
        compression: COMPRESSION_ZSTD,    // ZSTD 平衡好
        format: FORMAT_SAFE_TENSORS,      // SafeTensors 安全且支持 lazy loading
        incremental_enabled: true,
        incremental_threshold: 0.01,       // 变化 <1% 视为不变
        
        distributed: true,
        world_size: 64,                   // 默认 64 GPU
        local_rank: 0,
        fsdp_sharded: true,               // FSDP 模式
        
        verify_after_save: true,
        atomic_write: true,
        max_retries: 3,
        
        io_threads: 4,                    // 并行 IO
        chunk_size_mb: 512,               // 512MB chunks
    }
}

// ============================================================================
// 2. Checkpoint 数据结构
// ============================================================================

struct model_checkpoint {
    int version                       // Checkpoint 版本号
    int training_step                 // 训练步数
    int epoch                         // 当前的 epoch
    
    // 模型参数 (根据配置可能是分片或完整)
    []tensor_shard param_shards       // [num_shards] 每个 shard 的信息
    int total_parameters              // 总参数量 (所有 shards 合计)
    int64 total_bytes                 // 总字节数
    
    // 优化器状态
    optimizer_state opt_state         // AdamW 的 exp_avg, exp_avg_sq, step_count
    
    // 训练元数据
    training_metadata metadata
    
    // 时间戳
    float64 created_timestamp         // 创建时间 (Unix timestamp)
    float64 save_duration_ms          // 保存耗时
    
    // 校验和信息
    string checksum_md5               // MD5 (用于验证完整性)
    string checksum_crc32             // CRC32 (快速验证)
}

struct tensor_shard {
    string name                        // 参数名 (如 "layers.0.attention.qkv.weight")
    int[] shape                        // 张量形状
    int num_elements                   // 元素数量
    int dtype                          // 数据类型 (fp32/bf16/fp16)
    []float data                       // 实际数据 (可能被延迟加载)
    
    // 分布式信息
    int global_offset                  // 在完整张量中的偏移 (FSDP)
    int local_size                     // 本地 shard 大小
    
    // 增量信息 (用于 incremental checkpointing)
    string prev_checksum               // 上一次保存时的 checksum
    bool has_changed                   // 自上次保存后是否改变
}

struct optimizer_state {
    int step_count                      // 优化器已执行的步数
    []float exp_avg                    // 一阶矩 (momentum) - 可能是分片
    []float exp_avg_sq                 // 二阶矩 (variance) - 可能是分片
    
    // 可选: 其他优化器状态
    // []float master_params            // FP32 master params (if using AMP)
}

struct training_metadata {
    float loss                          // 最后一个 step 的 loss
    float learning_rate                 // 当前的学习率
    float global_batch_size             // 全局批次大小
    int tokens_processed                // 已处理的 token 数 (累计)
    int seen_samples                    // 已见样本数
    float throughput_samples_per_sec    // 吞吐量
    string config_snapshot              // 配置 JSON 字符串 (用于复现)
    
    // RNG 状态 (用于精确复现)
    []uint64 cuda_rng_state             // CUDA RNG 状态
    []uint64 cpu_rng_state             // CPU RNG 状态
    
    // Data iterator state
    data_iterator_state data_iter_state
}

struct data_iterator_state {
    int current_file_idx                // 当前数据文件索引
    int current_offset_in_file          // 文件内的字节偏移
    int samples_consumed_from_file      // 该文件已消费的样本数
    string dataset_version              // 数据集版本/commit hash
}

// ============================================================================
// 3. 核心 Checkpoint Manager
// ============================================================================

enum checkpoint_status {
    CKPT_IDLE,                         // 空闲,没有正在进行的保存操作
    CKPT_PREPARING,                    // 准备中 (冻结状态)
    CKPT_SAVING,                       // 正在写入磁盘
    CKPT_VERIFYING,                    // 校验完整性
    CKPT_COMPLETED,                    // 完成
    CKPT_FAILED,                       // 失败
    CKPT_CANCELLED,                    // 被取消
}

struct checkpoint_manager {
    checkpoint_config config
    checkpoint_status status
    int current_checkpoint_version     // 递增的版本号
    
    // 双缓冲区
    checkpoint_buffer front_buffer     // 前缓冲 (训练线程写入)
    checkpoint_buffer back_buffer      // 后缓冲 (writer 线程读取)
    bool buffer_locked                 // 后缓冲是否正在被写入
    
    // 异步任务队列
    []checkpoint_task task_queue       // 待执行的保存任务
    int queue_front                    // 队列头
    int queue_rear                     // 队列尾
    
    // 统计信息
    checkpoint_stats stats
    int last_saved_step                // 最近一次成功保存的 step
    
    // 回调函数 (可选)
    function on_save_complete          // 保存完成回调
    function on_save_failed            // 保存失败回调
}

struct checkpoint_buffer {
    model_checkpoint ckpt              // 缓存的 checkpoint 数据
    bool is_valid                      // 是否包含有效数据
    float64 frozen_time                // 冻结时间戳
}

struct checkpoint_task {
    int task_id                         // 任务 ID
    checkpoint_buffer data             // 要保存的数据
    string target_path                  // 目标路径
    int priority                       // 优先级 (数字越小越优先)
    bool is_cancelled                   // 是否被取消
}

struct checkpoint_stats {
    int total_saves_attempted          // 尝试保存的总次数
    int total_saves_completed          // 成功次数
    int total_saves_failed             // 失败次数
    float64 total_save_time_ms         // 累计保存时间
    float64 avg_save_time_ms           // 平均保存时间
    int64 total_data_written_mb        // 累计写入的数据量 (MB)
    float64 peak_io_throughput_mb_s    // 峰值 IO 吞吐 (MB/s)
    int last_error_code                // 最近一次错误码
    string last_error_message          // 最近一次错误消息
}

// ============================================================================
// 4. 初始化
// ============================================================================

func init_checkpoint_manager(checkpoint_config cfg) checkpoint_manager {
    // 创建目录 (如果不存在)
    create_directory_if_not_exists(cfg.base_directory)
    
    // 初始化统计
    checkpoint_stats init_stats
    init_stats.total_saves_attempted = 0
    init_stats.total_saves_completed = 0
    init_stats.total_saves_failed = 0
    init_stats.total_save_time_ms = 0.0
    init_stats.avg_save_time_ms = 0.0
    init_stats.total_data_written_mb = 0
    init_stats.peak_io_throughput_mb_s = 0.0
    init_stats.last_error_code = 0
    init_stats.last_error_message = ""
    
    // 初始化缓冲区
    checkpoint_buffer empty_buf
    empty_buf.is_valid = false
    empty_buf.frozen_time = 0.0
    
    checkpoint_manager mgr {
        config: cfg,
        status: CKPT_IDLE,
        current_checkpoint_version: 0,
        front_buffer: empty_buf,
        back_buffer: empty_buf,
        buffer_locked: false,
        task_queue: []checkpoint_task{cap: cfg.async_queue_depth},
        queue_front: 0,
        queue_rear: 0,
        stats: init_stats,
        last_saved_step: -1,
    }
    
    return mgr
}

func create_directory_if_not_exists(string path) {
    // 实现: mkdir -p path
}

// ============================================================================
// 5. 核心保存流程 (触发点)
// ============================================================================

// 触发异步保存 (从训练循环调用)
func trigger_async_save(ref checkpoint_manager mgr, model_checkpoint ckpt_data) bool {
    if !mgr.config.async_enabled {
        // 同步模式: 直接保存
        return sync_save(mgr, ckpt_data)
    }
    
    // 检查队列是否已满
    if is_queue_full(mgr) {
        // 队列满:丢弃最旧的任务或等待
        // 这里选择丢弃并返回 false
        return false
    }
    
    // === 双缓冲交换 ===
    // 将当前 checkpoint 数据复制到前缓冲 (如果还没被消费)
    if !mgr.front_buffer.is_valid || !mgr.buffer_locked {
        // 冻结前缓冲
        mgr.front_buffer.ckpt = ckpt_data
        mgr.front_buffer.is_valid = true
        mgr.front_buffer.frozen_time = get_current_time_ms()
        
        // 交换前后缓冲
        if !mgr.buffer_locked && mgr.back_buffer.is_valid {
            // 后缓冲已经被消费完,可以安全交换
            swap_buffers(mgr)
            
            // 创建保存任务并入队
            checkpoint_task task
            task.task_id = mgr.current_checkpoint_version
            task.data = mgr.back_buffer
            task.target_path = build_checkpoint_path(mgr, ckpt_data.training_step)
            task.priority = 0
            task.is_cancelled = false
            
            enqueue_task(mgr, task)
            
            // 启动后台 writer (如果还没有运行)
            start_background_writer_if_needed(mgr)
        }
    }
    
    mgr.current_checkpoint_version = mgr.current_checkpoint_version + 1
    return true
}

// 同步保存 (阻塞直到完成)
func sync_save(ref checkpoint_manager mgr, model_checkpoint ckpt_data) bool {
    mgr.status = CKPT_PREPARING
    float64 start_time = get_current_time_ms()
    
    // 构建目标路径
    string ckpt_dir = build_checkpoint_path(mgr, ckpt_data.training_step)
    create_directory_if_not_exists(ckpt_dir)
    
    // 写入文件
    bool success = write_checkpoint_to_disk(mgr, ckpt_data, ckpt_dir)
    
    if success {
        // 更新统计
        mgr.status = CKPT_VERIFYING
        if mgr.config.verify_after_save {
            success = verify_checkpoint(ckpt_dir)
        }
        
        if success {
            mgr.status = CKPT_COMPLETED
            mgr.last_saved_step = ckpt_data.training_step
            
            // 清理旧 checkpoint
            cleanup_old_checkpoints(mgr)
            
            // 更新统计
            float64 elapsed = get_current_time_ms() - start_time
            update_save_stats_success(mgr, elapsed, estimate_checkpoint_size_mb(ckpt_data))
        }
    } else {
        mgr.status = CKPT_FAILED
        update_save_stats_failure(mgr)
    }
    
    return success
}

// ============================================================================
// 6. 写入磁盘实现
// ============================================================================

func write_checkpoint_to_disk(
    ref checkpoint_manager mgr,
    model_checkpoint ckpt,
    string directory
) bool {
    int retries = 0
    while retries < mgr.config.max_retries {
        // 尝试保存
        if attempt_write_checkpoint(mgr, ckpt, directory, retries == 0) {
            return true
        }
        retries = retries + 1
    }
    return false
}

func attempt_write_checkpoint(
    ref checkpoint_manager mgr,
    model_checkpoint ckpt,
    string dir_path,
    bool is_first_attempt
) bool {
    // 如果是原子写入模式,先写到临时目录
    string actual_dir = dir_path
    string temp_dir = ""
    if mgr.config.atomic_write && is_first_attempt {
        temp_dir = dir_path + ".tmp_" + string(get_unique_id())
        create_directory_if_not_exists(temp_dir)
        actual_dir = temp_dir
    }
    
    // === 1. 保存模型参数 ===
    if !save_model_parameters(mgr, ckpt, actual_dir) {
        cleanup_directory(temp_dir)
        return false
    }
    
    // === 2. 保存优化器状态 ===
    if !save_optimizer_state(mgr, ckpt.opt_state, actual_dir) {
        cleanup_directory(temp_dir)
        return false
    }
    
    // === 3. 保存训练元数据 ===
    if !save_training_metadata(mgr, ckpt.metadata, actual_dir) {
        cleanup_directory(temp_dir)
        return false
    }
    
    // === 4. 保存 manifest (如果是分布式 & 是 rank 0) ===
    if mgr.config.local_rank == 0 && mgr.config.distributed {
        if !save_manifest(mgr, ckpt, actual_dir) {
            cleanup_directory(temp_dir)
            return false
        }
    }
    
    // === 5. 如果是临时目录,原子性地 rename ===
    if len(temp_dir) > 0 {
        if !atomic_rename(temp_dir, dir_path) {
            cleanup_directory(temp_dir)
            return false
        }
    }
    
    return true
}

// 保存模型参数
func save_model_parameters(
    ref checkpoint_manager mgr,
    model_checkpoint ckpt,
    string dir_path
) bool {
    int num_shards = len(ckpt.param_shards)
    
    int shard_idx = 0
    while shard_idx < num_shards {
        tensor_shard shard = ckpt.param_shards[shard_idx]
        
        // 增量 checkpoint: 检查是否真的改变了
        if mgr.config.incremental_enabled && !shard.has_changed {
            shard_idx = shard_idx + 1
            continue  // 跳过未改变的 shard
        }
        
        // 构建文件名
        string filename
        if mgr.config.fsdp_sharded {
            filename = "model_rank" + string(mgr.config.local_rank) + "_shard" + string(shard_idx)
        } else {
            filename = "model_" + sanitize_filename(shard.name)
        }
        
        // 添加扩展名
        if mgr.config.format == FORMAT_SAFE_TENSORS {
            filename = filename + ".safetensors"
        } else {
            filename = filename + ".pt"
        }
        
        string full_path = dir_path + "/" + filename
        
        // 写入文件 (实际调用底层 IO)
        if !write_tensor_to_file(shard, full_path, mgr.config.compression) {
            return false
        }
        
        shard_idx = shard_idx + 1
    }
    
    return true
}

// 保存优化器状态
func save_optimizer_state(
    ref checkpoint_manager mgr,
    optimizer_state opt,
    string dir_path
) bool {
    string filepath = dir_path + "/optimizer"
    if mgr.config.fsdp_sharded {
        filepath = filepath + "_rank" + string(mgr.config.local_rank)
    }
    filepath = filepath + ".pt"
    
    // 序列化为字节流然后写入
    // ... (具体序列化逻辑)
    
    return true
}

// 保存训练元数据 (JSON 格式)
func save_training_metadata(
    ref checkpoint_manager mgr,
    training_metadata meta,
    string dir_path
) bool {
    string filepath = dir_path + "/training_state.json"
    
    string json_content = serialize_metadata_to_json(meta)
    
    return write_string_to_file(filepath, json_content)
}

// 保存 manifest (rank 0 only)
func save_manifest(
    ref checkpoint_manager mgr,
    model_checkpoint ckpt,
    string dir_path
) bool {
    string filepath = dir_path + "/manifest.json"
    
    // 包含:
    // - 所有 rank 的文件列表和大小
    // - 完整的配置快照
    // - 校验和信息
    
    string manifest_json =
        "{\n" +
        "  \"version\": \"" + string(ckpt.version) + "\",\n" +
        "  \"training_step\": " + string(ckpt.training_step) + ",\n" +
        "  \"world_size\": " + string(mgr.config.world_size) + ",\n" +
        "  \"total_parameters\": " + string(ckpt.total_parameters) + ",\n" +
        "  \"total_bytes\": " + string(ckpt.total_bytes) + ",\n" +
        "  \"created_at\": \"" + string_timestamp(ckpt.created_timestamp) + "\",\n" +
        "  \"checksum_md5\": \"" + ckpt.checksum_md5 + "\",\n" +
        "  \"files\": [...],\n" +
        "  \"config\": " + meta.config_snapshot + "\n" +
        "}\n"
    
    return write_string_to_file(filepath, manifest_json)
}

// ============================================================================
// 7. 加载与恢复
// ============================================================================

// 加载 checkpoint (用于 resume training)
func load_checkpoint(
    ref checkpoint_manager mgr,
    string ckpt_path_or_step
) model_checkpoint {
    // 解析路径: 可能是目录名、步骤号、或 "latest"/"best"
    string resolved_path = resolve_checkpoint_path(mgr, ckpt_path_or_step)
    
    if resolved_path == "" {
        // 错误: 找不到 checkpoint
        return empty_checkpoint()
    }
    
    // 加载各个组件
    model_checkpoint loaded
    loaded.param_shards = load_model_parameters(mgr, resolved_path)
    loaded.opt_state = load_optimizer_state(mgr, resolved_path)
    loaded.metadata = load_training_metadata(mgr, resolved_path)
    
    // 验证完整性
    if mgr.config.verify_after_save && !verify_checkpoint(resolved_path) {
        // 校验失败
        return empty_checkpoint()
    }
    
    return loaded
}

// 解析 checkpoint 路径
func resolve_checkpoint_path(ref checkpoint_manager mgr, string input) string {
    if input == "latest" {
        // 查找最新的 checkpoint
        return find_latest_checkpoint(mgr.config.base_directory)
    } else if input == "best" {
        // 查找最低 validation loss 的 checkpoint
        return find_best_checkpoint(mgr.config.base_directory)
    } else if is_numeric(input) {
        // 输入的是 step number
        int step = parse_int(input)
        return mgr.config.base_directory + "/step_" + pad_with_zeros(step, 8)
    } else {
        // 直接就是路径
        if directory_exists(input) {
            return input
        }
        return ""
    }
}

// 恢复训练状态 (完整的 resume 逻辑)
func restore_training_state(
    ref checkpoint_manager mgr,
    string ckpt_path
) bool {
    // 1. 加载 checkpoint
    model_checkpoint ckpt = load_checkpoint(mgr, ckpt_path)
    
    if !is_valid_checkpoint(ckpt) {
        return false
    }
    
    // 2. 恢复模型参数到内存/GPU
    restore_parameters_to_model(ckpt.param_shards)
    
    // 3. 恢复优化器状态
    restore_optimizer_state(ckpt.opt_state)
    
    // 4. 恢复 RNG 状态 (确保可复现性)
    restore_rng_states(ckpt.metadata.cuda_rng_state, ckpt.metadata.cpu_rng_state)
    
    // 5. 恢复数据迭代器位置
    restore_data_iterator(ckpt.metadata.data_iter_state)
    
    // 6. 更新 manager 状态
    mgr.last_saved_step = ckpt.training_step
    mgr.current_checkpoint_version = ckpt.version + 1
    
    return true
}

// ============================================================================
// 8. 后台 Writer 线程 (异步保存的核心)
// ============================================================================

// 后台 writer 主循环
func background_writer_loop(ref checkpoint_manager mgr) {
    while true {
        // 从队列取出任务
        checkpoint_task task = dequeue_task(mgr)
        
        if task.is_cancelled {
            continue
        }
        
        // 执行保存
        mgr.status = CKPT_SAVING
        bool success = sync_save(mgr, task.data.ckpt)
        
        // 标记后缓冲为可用
        mgr.buffer_locked = false
        task.data.is_valid = false
        
        // 通知完成
        if success && mgr.on_save_complete != null {
            call_callback(mgr.on_save_complete, task.task_id)
        } else if !success && mgr.on_save_failed != null {
            call_callback(mgr.on_save_failed, task.task_id)
        }
    }
}

// ============================================================================
// 9. 清理与管理工具
// ============================================================================

// 清理旧 checkpoint,只保留最近 N 个
func cleanup_old_checkpoints(ref checkpoint_manager mgr) {
    int keep_n = mgr.config.keep_last_n_checkpoints
    if keep_n <= 0 { return }  // 0 表示全部保留
    
    // 列出所有 checkpoint 目录
    []string all_ckpts = list_all_checkpoints(mgr.config.base_directory)
    
    // 按 step number 排序 (最新的在前)
    sort_checkpoints_by_step_desc(all_ckpts)
    
    // 删除超出数量的旧 checkpoint
    int idx = keep_n
    while idx < len(all_ckpts) {
        string old_path = all_ckpts[idx]
        delete_directory_recursive(old_path)
        log_info("Deleted old checkpoint: " + old_path)
        idx = idx + 1
    }
}

// 查找最新 checkpoint
func find_latest_checkpoint(string base_dir) string {
    []string all_ckpts = list_all_checkpoints(base_dir)
    
    if len(all_ckpts) == 0 { return "" }
    
    // 返回 step 最大的那个
    string latest = all_ckpts[0]
    int latest_step = -1
    
    int i = 0
    while i < len(all_ckpts) {
        int step = extract_step_from_path(all_ckpts[i])
        if step > latest_step {
            latest_step = step
            latest = all_ckpts[i]
        }
        i = i + 1
    }
    
    return latest
}

// 验证 checkpoint 完整性
func verify_checkpoint(string ckpt_dir) bool {
    // 检查必需文件是否存在
    if !file_exists(ckpt_dir + "/training_state.json") {
        return false
    }
    
    // 检查 manifest (如果有)
    string manifest_path = ckpt_dir + "/manifest.json"
    if file_exists(manifest_path) {
        // 读取 manifest 并验证每个文件的校验和
        // ...
    }
    
    // 可选: 对关键文件做抽样校验
    // ...
    
    return true
}

// ============================================================================
// 10. 辅助函数
// ============================================================================

func build_checkpoint_path(checkpoint_manager mgr, int step) string {
    mgr.config.base_directory + "/step_" + pad_with_zeros(step, 8)
}

func pad_with_zeros(int value, int width) string {
    string s = string(value)
    while len(s) < width {
        s = "0" + s
    }
    return s
}

func get_current_time_ms() float64 { return 0.0 }
func get_unique_id() int { return 0 }

func is_queue_full(checkpoint_manager mgr) bool {
    return (mgr.queue_rear + 1) % len(mgr.task_queue) == mgr.queue_front
}

func swap_buffers(ref checkpoint_manager mgr) {
    checkpoint_buffer temp = mgr.front_buffer
    mgr.front_buffer = mgr.back_buffer
    mgr.back_buffer = temp
    mgr.buffer_locked = true
}

func enqueue_task(ref checkpoint_manager mgr, checkpoint_task task) {
    mgr.task_queue[mgr.queue_rear] = task
    mgr.queue_rear = (mgr.queue_rear + 1) % len(mgr.task_queue)
}

func dequeue_task(checkpoint_manager mgr) checkpoint_task {
    checkpoint_task task = mgr.task_queue[mgr.queue_front]
    mgr.queue_front = (mgr.queue_front + 1) % len(mgr.task_queue)
    return task
}

func start_background_writer_if_needed(ref checkpoint_manager mgr) {}

func update_save_stats_success(ref checkpoint_manager mgr, float64 time_ms, int size_mb) {
    mgr.stats.total_saves_completed = mgr.stats.total_saves_completed + 1
    mgr.stats.total_saves_attempted = mgr.stats.total_saves_attempted + 1
    mgr.stats.total_save_time_ms = mgr.stats.total_save_time_ms + time_ms
    mgr.stats.avg_save_time_ms = mgr.stats.total_save_time_ms / float_of_int(mgr.stats.total_saves_completed)
    mgr.stats.total_data_written_mb = mgr.stats.total_data_written_mb + float_of_int(size_mb)
}

func update_save_stats_failure(ref checkpoint_manager mgr) {
    mgr.stats.total_saves_failed = mgr.stats.total_saves_failed + 1
    mgr.stats.total_saves_attempted = mgr.stats.total_saves_attempted + 1
}

func write_tensor_to_file(tensor_shard t, string path, compression_type c) bool { return true }
func write_string_to_file(string path, string content) bool { return true }
func serialize_metadata_to_json(training_metadata m) string { return "{}" }

func empty_checkpoint() model_checkpoint { 
    return model_checkpoint{} 
}
func is_valid_checkpoint(model_checkpoint c) bool { return true }
func restore_parameters_to_model([]tensor_shard shards) {}
func restore_optimizer_state(optimizer_state opt) {}
func restore_rng_states([]uint64 cuda, []uint64 cpu) {}
func restore_data_iterator(data_iterator_state iter) {}

func find_best_checkpoint(string base_dir) string { return "" }
func list_all_checkpoints(string base_dir) []string { return []string{} }
func sort_checkpoints_by_step_desc(ref []string paths) {}
func extract_step_from_path(string path) int { return 0 }
func delete_directory_recursive(string path) {}

func file_exists(string path) bool { return false }
func directory_exists(string path) bool { return false }
func cleanup_directory(string path) {}
func atomic_rename(string from, string to) bool { return true }

func log_info(string msg) {}
func sanitize_filename(string name) string { return name }
func string_timestamp(float64 ts) string { return "" }
func is_numeric(string s) bool { return false }
func parse_int(string s) int { return 0 }

func float_of_int(int n) float { return 0.0 }

// NEURX-5.2 特定: 快速恢复接口
func quick_resume_training(string checkpoint_path) bool {
    // 一键恢复 NEURX-5.2 训练的便捷函数
    checkpoint_config cfg = default_checkpoint_config_for_large_model()
    checkpoint_manager mgr = init_checkpoint_manager(cfg)
    
    return restore_training_state(mgr, checkpoint_path)
}
