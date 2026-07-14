package neurx.data.dataloader

// ═══════════════════════════════════════════════════════════════════
// High-Performance Data Pipeline — 高性能数据流水线
//
// 核心挑战:
//   • 万亿 token 级别预训练需要极高的数据吞吐 (TB/小时)
//   • GPU 计算速度远超单线程数据加载速度
//   • 数据来源多样: 文本、代码、多模态等
//   • 数据质量参差不齐,需要实时过滤
//
// 解决方案 (参考 DeepSpeed-DataPipeline / WebDataset):
//
//   ┌────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────┐
//   │ Disk/Cloud │ →  │ Pre-fetch    │ →  │ Tokenize &   │ →  │ GPU      │
//   │ Storage    │    │ Buffer      │    │ Transform     │    │ Memory   │
//   │ (async)    │    │ (multi-file)│    │ (parallel)    │    │ (pinned)│
//   └────────────┘    └──────────────┘    └──────────────┘    └──────────┘
//         ↑                   ↑                    ↑               ↑
//    IO Thread          CPU Threads         Worker Pool       Training Loop
//
// 关键特性:
//   ✓ 异步预取 (Async Prefetch): GPU 计算时,CPU 准备下一个 batch
//   ✓ 内存池 (Memory Pool): 避免频繁 malloc/free,减少 GC 压力
//   ✓ Pinned Memory: 锁页内存,加速 CPU→GPU DMA 传输
//   ✓ 多文件并行读取: 同时从多个文件/分区读取数据
//   ✓ 智能数据打包 (Smart Binning/Packing): 变长序列高效填充
//   ✓ 分布式采样: 多节点无重复或可控重复的数据分配
//   ✓ 动态数据过滤: 实时质量检查和过滤
//   ✓ 支持多种格式: JSONL, Parquet, TFRecord, Arrow, MMAP
// ═══════════════════════════════════════════════════════════════════

// ============================================================================
// 1. 配置结构体
// ============================================================================

enum data_format {
    FORMAT_JSONL,              // 每行一个 JSON 对象
    FORMAT_PARQUET,            // Apache Parquet (列式,高压缩)
    FORMAT_TFRECORD,           // TensorFlow Record 格式
    FORMAT_ARROW,              // Apache Arrow (内存格式)
    FORMAT_MMAP,               // 内存映射文件 (极快随机访问)
    FORMAT_CUSTOM,             // 用户自定义格式 (通过回调)
}

enum packing_strategy {
    PACKING_NONE,              // 不打包,padding 到最长序列
    PACKING_FIXED_LENGTH,      // 固定长度截断/padding
    PACKING_BINNING,           // 分桶:相似长度的序列放一起
    PACKING_SMART_PACKING,     // 智能打包:多个短序列拼接成固定长度块 (推荐!)
}

struct dataloader_config {
    // 数据源配置
    []string data_paths                // 数据文件/目录列表 (支持 glob)
    data_format format                 // 文件格式
    
    // Batch 配置
    int batch_size                     // 每个 batch 的样本数
    int max_seq_len                    // 最大序列长度 (padding/cutoff 目标)
    int min_seq_len                    // 最小序列长度 (过滤过短样本)
    
    // 打包策略
    packing_strategy packing           // 序列打包策略
    float packing_efficiency_target    // 目标打包效率 (如 0.9 = 90% non-padding)
    
    // 并行与性能
    int num_workers                    // 数据加载工作进程数 (通常 4-16)
    int prefetch_factor                // 预取因子 (每个 worker 预取多少 batch)
    bool pin_memory                    // 使用锁页内存 (加速 CPU→GPU)
    int io_thread_count                // IO 线程数 (用于并行读取文件)
    int tokenize_thread_count          // Tokenization 线程数
    
    // Tokenizer 配置
    string tokenizer_path              // Tokenizer 文件路径
    bool add_special_tokens            // 是否添加特殊 token (BOS/EOS/PAD)
    bool enable_rope_scaling           // 是否应用 RoPE position encoding
    
    // 分布式训练支持
    bool distributed_sampling          // 分布式采样 (每个 rank 看不同数据)
    int world_size                     // 总 rank 数
    int local_rank                     // 当前 rank
    uint64 seed                        // 随机种子 (确保可复现性)
    int shuffle_buffer_size            // Shuffle buffer 大小 (样本数)
    
    // 数据过滤与质量控制
    bool enable_filtering              // 启用数据过滤
    float max_token_ratio_to_filter    // 超过此比例的 token 重复率则过滤 (去重)
    int min_chars_per_sample           // 最小字符数 (过滤空/过短)
    bool check_utf8_validity           // UTF-8 合法性检查
    
    // 性能监控
    bool enable_profiling              // 启用性能分析
    int stats_report_interval          // 统计报告间隔 (batch 数)
}

// 默认配置 (针对 NEURX-5.2 预训练优化)
func default_dataloader_config() dataloader_config {
    dataloader_config {
        data_paths: ["./data/pretrain/**/*.jsonl"],
        format: FORMAT_JSONL,
        
        batch_size: 512,                  // per-GPU micro-batch size
        max_seq_len: 4096,                // NEURX-5.2 训练时的序列长度
        min_seq_len: 256,                 // 过滤太短的样本
        
        packing: PACKING_SMART_PACKING,   // 智能打包 (推荐!)
        packing_efficiency_target: 0.92,  // 92% 效率
        
        num_workers: 8,                   // 8 个 worker 进程
        prefetch_factor: 2,               // 预取 2 个 batch
        pin_memory: true,
        io_thread_count: 4,               // 4 个 IO 线程
        tokenize_thread_count: 8,         // 8 个 tokenization 线程
        
        tokenizer_path: "./tokenizer/tokenizer.model",
        add_special_tokens: true,
        enable_rope_scaling: false,       // RoPE 在 model 中处理
        
        distributed_sampling: true,
        world_size: 64,
        local_rank: 0,
        seed: 42,
        shuffle_buffer_size: 10000,       // 10K shuffle buffer
        
        enable_filtering: true,
        max_token_ratio_to_filter: 0.7,   // >70% 重复 token 则丢弃
        min_chars_per_sample: 100,
        check_utf8_validity: true,
        
        enable_profiling: true,
        stats_report_interval: 1000,
    }
}

// ============================================================================
// 2. 核心数据结构
// ============================================================================

// 单个训练样本 (原始文本)
struct raw_sample {
    string text                         // 原始文本
    string source_file                  // 来源文件
    int64 file_offset                   // 文件偏移 (用于快速定位)
    int length_chars                    // 字符长度
    int estimated_tokens                // 估算的 token 数
}

// Tokenized 后的样本
struct tokenized_sample {
    []int token_ids                     // Token ID 列表 [seq_len]
    int seq_len                         // 实际序列长度
    int attention_mask[]                // Attention mask [seq_len] (1=real, 0=pad)
    int[] position_ids                  // Position IDs (如果需要)
    int64 sample_id                     // 全局唯一 ID (用于去重/debug)
    float weight                        // 样本权重 (可用于 upweighting 重要数据)
    string metadata                     // 元数据 JSON (可选)
}

// 一个完整的 Batch (送给模型)
struct training_batch {
    [][]int input_ids                    // [batch_size, seq_len] Token IDs
    [][]int attention_mask              // [batch_size, seq_len]
    [][]int position_ids                // [batch_size, seq_len] (optional)
    []float labels                      // [batch_size * seq_len] 展平的 labels (for LM loss)
    
    // Metadata
    int batch_id                        // Batch ID (递增)
    float effective_batch_ratio         // 有效数据比例 (非 padding 占比)
    int actual_num_samples              // 实际独立样本数 (smart packing 时可能 < batch_size)
    
    // Timing info
    float64 load_time_ms                // 加载耗时
    float64 tokenize_time_ms            // Tokenization 耗时
    float64 total_prepare_time_ms       // 总准备时间
}

// ============================================================================
// 3. DataLoader 主类
// ============================================================================

enum loader_status {
    LOADER_IDLE,
    LOADER_LOADING,
    LOADER_READY,
    LOADER_EXHAUSTED,
    LOADER_ERROR
}

struct dataloader {
    dataloader_config config
    loader_status status
    
    // 文件管理
    []file_handle open_files            // 已打开的文件句柄
    []string all_data_files            // 所有数据文件列表
    int current_file_index              // 当前读取到的文件索引
    
    // 缓冲区系统
    sample_buffer raw_buffer            // 原始样本缓冲区 (从磁盘读取)
    tokenized_buffer tokenized_buffer   // Tokenized 后的缓冲区 (等待送入 GPU)
    training_batch[] gpu_queue          // GPU 输入队列 (pinned memory)
    
    // 工作线程池
    thread_pool io_workers              // IO 线程池
    thread_pool tokenize_workers        // Tokenize 线程池
    
    // Shuffle & Sampling
    rng_state shuffler                   // Shuffle RNG
    distributed_sampler sampler         // 分布式采样器
    
    // Smart Packing 状态
    smart_packer packer                 // 智能打包器实例
    
    // 统计信息
    dataloader_stats stats
    
    // 控制标志
    bool should_stop                    // 外部请求停止
    bool epoch_completed                // 当前 epoch 是否完成
    int current_epoch                   // 当前 epoch 编号
    int total_samples_processed         // 累计处理样本数
    int total_batches_produced          // 累计产出 batch 数
}

struct sample_buffer {
    raw_sample[] samples
    int count                           // 当前已存储数量
    int capacity                       // 总容量
    bool is_full                        // 是否已满
    mutex lock                          // 互斥锁 (多线程安全)
}

struct tokenized_buffer {
    tokenized_sample[] samples
    int count
    int capacity
    bool is_ready                       // 是否有可消费数据
    mutex lock
}

struct thread_pool {
    int num_threads
    []thread workers
    task_queue queue
    bool running
}

struct rng_state {
    uint64 state
    uint64 inc
}

struct distributed_sampler {
    int world_size
    int rank
    int total_samples
    int samples_per_rank
    int current_index
    uint64 seed
    int[] shuffled_indices             // 全局打乱后的索引
}

struct smart_packer {
    packing_strategy strategy
    int target_length                   // 目标打包后的总长度
    float efficiency_threshold
    []tokenized_sample current_batch_accumulator  // 当前正在积累的样本
    int accumulated_tokens              // 已累积的总 token 数
}

struct dataloader_stats {
    int total_files_scanned             // 扫描的文件总数
    int64 total_bytes_read              // 读取的总字节数
    int total_samples_loaded            // 加载的原始样本总数
    int total_samples_after_filter      // 过滤后剩余的样本数
    int total_batches_produced          // 生成的 batch 总数
    float avg_tokens_per_sample         // 平均每样本 token 数
    float packing_efficiency            // 平均打包效率
    float load_throughput_mb_s          // 数据加载吞吐量 (MB/s)
    float tokenize_throughput_k_samples_s  // Tokenization 吞吐量 (K samples/s)
    float gpu_feed_throughput_batches_s     // GPU 喂入吞吐量 (batches/s)
    int peak_memory_usage_mb            // 峰值内存使用 (MB)
    float total_time_spent_loading_pct  // 加载耗时占比
    float total_time_spent_tokenize_pct // Tokenize 耗时占比
    float total_time_waiting_pct        // 等待 GPU 耗时占比
}

// ============================================================================
// 4. 初始化
// ============================================================================

func init_dataloader(dataloader_config cfg) dataloader {
    // 扫描数据文件
    []string files = scan_data_files(cfg.data_paths, cfg.format)
    
    if len(files) == 0 {
        // 错误:没有找到数据文件
    }
    
    // 初始化统计
    dataloader_stats init_stats
    
    // 初始化缓冲区
    int raw_buf_size = cfg.batch_size * cfg.prefetch_factor * 4  // 额外空间
    sample_buffer raw_buf
    raw_buf.samples = []raw_sample{cap: raw_buf_size}
    raw_buf.count = 0
    raw_buf.capacity = raw_buf_size
    raw_buf.is_full = false
    
    int tok_buf_size = cfg.batch_size * cfg.prefetch_factor * 2
    tokenized_buffer tok_buf
    tok_buf.samples = []tokenized_sample{cap: tok_buf_size}
    tok_buf.count = 0
    tok_buf.capacity = tok_buf_size
    tok_buf.is_ready = false
    
    // 初始化分布式采样器
    distributed_sampler samp
    samp.world_size = cfg.world_size
    samp.rank = cfg.local_rank
    samp.total_samples = estimate_total_samples(files)  // 估算
    samp.samples_per_rank = samp.total_samples / cfg.world_size
    samp.current_index = 0
    samp.seed = cfg.seed
    samp.shuffled_indices = generate_shuffled_indices(samp.total_samples, cfg.seed)
    
    // 初始化 Smart Packer
    smart_packer pk
    pk.strategy = cfg.packing
    pk.target_length = cfg.max_seq_len
    pk.efficiency_threshold = cfg.packing_efficiency_target
    pk.current_batch_accumulator = []tokenized_sample{}
    pk.accumulated_tokens = 0
    
    // 创建 DataLoader 实例
    dataloader loader
    loader.config = cfg
    loader.status = LOADER_IDLE
    loader.all_data_files = files
    loader.current_file_index = 0
    loader.raw_buffer = raw_buf
    loader.tokenized_buffer = tok_buf
    loader.gpu_queue = []training_batch{cap: cfg.prefetch_factor}
    loader.sampler = samp
    loader.packer = pk
    loader.stats = init_stats
    loader.should_stop = false
    loader.epoch_completed = false
    loader.current_epoch = 0
    loader.total_samples_processed = 0
    loader.total_batches_produced = 0
    
    return loader
}

func scan_data_files([]string paths, data_format fmt) []string {
    // 实现: glob 匹配 + 文件类型验证
    return []string{}
}

func estimate_total_samples([]string files) int {
    // 估算总样本数 (基于文件大小或抽样统计)
    return 100000000  // placeholder: 100M samples
}

func generate_shuffled_indices(int n, uint64 seed) []int {
    // Fisher-Yates shuffle 生成随机排列
    []int indices = []int{cap: n}
    int i = 0
    while i < n { 
        indices[i] = i; 
        i = i + 1 
    }
    
    // 使用种子初始化 RNG
    rng_state rng
    rng.state = seed
    rng.inc = 6364136223846793005  // LCG multiplier
    
    i = n - 1
    while i > 0 {
        int j = random_int_range(&rng, 0, i)
        // swap
        int temp = indices[i]
        indices[i] = indices[j]
        indices[j] = temp
        i = i - 1
    }
    
    return indices
}

// ============================================================================
// 5. 核心迭代接口
// ============================================================================

// 获取下一个 batch (主训练循环调用)
func get_next_batch(ref dataloader loader) training_batch {
    // 如果 GPU 队列为空,需要等待/触发数据准备
    if len(loader.gpu_queue) == 0 || !is_batch_ready(loader.gpu_queue[0]) {
        // 同步等待或触发一次性的数据准备
        prepare_next_batches(loader)
    }
    
    // 从队列取出
    training_batch batch = dequeue_gpu_queue(loader)
    
    // 更新统计
    loader.total_batches_produced = loader.total_batches_produced + 1
    loader.stats.total_batches_produced = loader.stats.total_batches_produced + 1
    
    return batch
}

// 异步准备后续 batches (在后台运行)
func prepare_next_batches(ref dataloader loader) {
    int batches_to_prepare = loader.config.prefetch_factor - len(loader.gpu_queue)
    
    int b = 0
    while b < batches_to_prepare && !loader.epoch_completed {
        // 1. 从 tokenized buffer 取出足够样本
        []tokenized_sample samples = fetch_samples_from_tokenized_buffer(loader, loader.config.batch_size)
        
        if len(samples) == 0 {
            // buffer 空,尝试补充
            refill_tokenized_buffer(loader)
            
            if loader.tokenized_buffer.count == 0 {
                // 真的没有数据了,epoch 结束
                loader.epoch_completed = true
                break
            }
            
            samples = fetch_samples_from_tokenized_buffer(loader, loader.config.batch_size)
        }
        
        // 2. 构建 batch (应用打包策略)
        training_batch batch = build_training_batch(loader, samples)
        
        // 3. 放入 GPU 队列
        enqueue_gpu_queue(loader, batch)
        
        b = b + 1
    }
}

// 从 tokenized buffer 取出样本
func fetch_samples_from_tokenized_buffer(dataloader loader, int count) []tokenized_sample {
    // 简化实现:直接取出前 count 个
    []tokenized_sample result = []tokenized_sample{cap: count}
    
    int available = min_int(count, loader.tokenized_buffer.count)
    int i = 0
    while i < available {
        result[i] = loader.tokenized_buffer.samples[i]
        i = i + 1
    }
    
    // 移除已取出的 (实际应该用队列更高效)
    int remaining = loader.tokenized_buffer.count - available
    int j = 0
    while j < remaining {
        loader.tokenized_buffer.samples[j] = loader.tokenized_buffer.samples[j + available]
        j = j + 1
    }
    loader.tokenized_buffer.count = remaining
    
    return result
}

// 补充 tokenized buffer (从原始数据 → tokenize)
func refill_tokenized_buffer(ref dataloader loader) {
    // 1. 补充原始数据 buffer
    refill_raw_buffer(loader)
    
    // 2. 批量 tokenize
    int i = 0
    while i < loader.raw_buffer.count && loader.tokenized_buffer.count < loader.tokenized_buffer.capacity {
        raw_sample raw = loader.raw_buffer.samples[i]
        
        // Tokenize
        tokenized_sample tok = tokenize_single(raw, loader.config)
        
        // 质量过滤
        if passes_quality_filter(tok, loader.config) {
            // 加入 tokenized buffer
            loader.tokenized_buffer.samples[loader.tokenized_buffer.count] = tok
            loader.tokenized_buffer.count = loader.tokenized_buffer.count + 1
            
            loader.stats.total_samples_after_filter = loader.stats.total_samples_after_filter + 1
        }
        
        i = i + 1
    }
    
    // 清空已处理的 raw 数据
    loader.raw_buffer.count = 0
    loader.raw_buffer.is_full = false
}

// 补充原始数据 buffer (从磁盘读取)
func refill_raw_buffer(ref dataloader loader) {
    if loader.raw_buffer.is_full { return }
    
    int to_load = loader.raw_buffer.capacity - loader.raw_buffer.count
    int loaded = 0
    
    while loaded < to_load && !loader.epoch_completed {
        // 从当前文件读取
        raw_sample sample = read_next_sample(loader)
        
        if sample.text == "" {
            // 文件结束,切换到下一个
            loader.current_file_index = loader.current_file_index + 1
            
            if loader.current_file_index >= len(loader.all_data_files) {
                // 所有用完,epoch 结束
                loader.epoch_completed = true
                
                // 重置状态 (开始新 epoch)
                reset_for_new_epoch(loader)
                break
            } else {
                continue  // 尝试下一个文件
            }
        }
        
        // 存入 buffer
        loader.raw_buffer.samples[loader.raw_buffer.count] = sample
        loader.raw_buffer.count = loader.raw_buffer.count + 1
        loaded = loaded + 1
        
        loader.stats.total_samples_loaded = loader.stats.total_samples_loaded + 1
    }
    
    if loader.raw_buffer.count >= loader.raw_buffer.capacity {
        loader.raw_buffer.is_full = true
    }
}

// 读取下一个样本 (简化版)
func read_next_sample(dataloader loader) raw_sample {
    // 实际会根据 format 选择不同的解析器
    raw_sample sample
    sample.text = ""
    sample.source_file = loader.all_data_files[loader.current_file_index]
    sample.file_offset = 0
    sample.length_chars = 0
    sample.estimated_tokens = 0
    return sample
}

// ============================================================================
// 6. Tokenization
// ============================================================================

func tokenize_single(raw_sample raw, dataloader_config cfg) tokenized_sample {
    // 调用 tokenizer (BPE / SentencePiece / WordPiece 等)
    []int token_ids = run_tokenizer(raw.text, cfg)
    
    // 截断到最大长度
    if len(token_ids) > cfg.max_seq_len {
        token_ids = truncate(token_ids, cfg.max_seq_len)
    }
    
    // 添加特殊 token
    if cfg.add_special_tokens {
        token_ids = add_special_tokens(token_ids)
    }
    
    tokenized_sample result
    result.token_ids = token_ids
    result.seq_len = len(token_ids)
    result.attention_mask = create_attention_mask(result.seq_len)
    result.position_ids = create_position_ids(result.seq_len)
    result.sample_id = hash_string(raw.text)
    result.weight = 1.0
    result.metadata = ""
    
    return result
}

// (占位符 - 实际会调用 tokenizer C 库或 Python binding)
func run_tokenizer(string text, dataloaderConfig cfg) []int {
    // 简化:返回伪 token IDs
    int estimated_len = len(text) / 4  // rough estimate
    []int ids = []int{cap: estimated_len}
    int i = 0
    while i < estimated_len { ids[i] = i % 128000; i = i + 1 }
    return ids
}

func truncate([]int ids, int max_len) []int {
    []int result = []int{cap: max_len}
    int i = 0
    while i < max_len && i < len(ids) { result[i] = ids[i]; i = i + 1 }
    return result
}

func add_special_tokens([]int ids) []int {
    // 添加 BOS (ID=1), EOS (ID=2)
    int new_len = len(ids) + 2
    []int result = []int{cap: new_len}
    result[0] = 1  // BOS
    int i = 0
    while i < len(ids) { result[i+1] = ids[i]; i = i + 1 }
    result[new_len-1] = 2  // EOS
    return result
}

func create_attention_mask(int seq_len) []int {
    []int mask = []int{cap: seq_len}
    int i = 0
    while i < seq_len { mask[i] = 1; i = i + 1 }
    return mask
}

func create_position_ids(int seq_len) []int {
    []int pos = []int{cap: seq_len}
    int i = 0
    while i < seq_len { pos[i] = i; i = i + 1 }
    return pos
}

// ============================================================================
// 7. Smart Packing (核心算法)
// ============================================================================
//
// 问题: 不同样本长度差异大,padding 浪费大量计算
//
// 解决方案: 将多个短样本 "打包" 成固定长度的序列块
//
// 示例 (target_length=10):
//   Sample A: [tok tok tok] (len=3)  + PAD x7 = 10 tokens (30% efficiency)
//   Sample B: [tok tok tok tok tok] (len=5) + PAD x5 = 10 tokens (50% efficiency)
//
// Smart Packing:
//   Block: [tok_A tok_A tok_A EOS tok_B tok_B tok_B tok_B tok_B EOS PAD PAD] (len=10)
//   Efficiency: 8/10 = 80%! (A 和 B 共享同一个 block)
//
// 注意事项:
//   - 需要记录每个样本的位置范围 (用于 loss mask)
//   - Attention mask 需要阻止跨样本的注意力 (sample boundary masking)
//   - Labels 只对真实 token 计算,PAD 位置忽略 (loss = -100 或 mask=0)

func build_training_batch(dataloader loader, []tokenized_sample samples) training_batch {
    if loader.config.packing == PACKING_SMART_PACKING {
        return build_packed_batch(loader, samples)
    } else {
        return build_standard_batch(loader, samples)
    }
}

// 标准 batch (padding 到相同长度)
func build_standard_batch(dataloader loader, []tokenized_sample samples) training_batch {
    int batch_size = len(samples)
    int max_len_in_batch = 0
    
    // 找最长序列
    int s = 0
    while s < batch_size {
        if samples[s].seq_len > max_len_in_batch {
            max_len_in_batch = samples[s].seq_len
        }
        s = s + 1
    }
    
    // 截断到全局最大
    if max_len_in_batch > loader.config.max_seq_len {
        max_len_in_batch = loader.config.max_seq_len
    }
    
    // 构建张量
    [][]int input_ids = allocate_2d_int(batch_size, max_len_in_batch)
    [][]int attention_mask = allocate_2d_int(batch_size, max_len_in_batch)
    [][]int position_ids = allocate_2d_int(batch_size, max_len_in_batch)
    
    s = 0
    while s < batch_size {
        int t = 0
        while t < samples[s].seq_len && t < max_len_in_batch {
            input_ids[s][t] = samples[s].token_ids[t]
            attention_mask[s][t] = samples[s].attention_mask[t]
            position_ids[s][t] = samples[s].position_ids[t]
            t = t + 1
        }
        // Padding 部分
        while t < max_len_in_batch {
            input_ids[s][t] = 0  // PAD token
            attention_mask[s][t] = 0  // 不参与计算
            position_ids[s][t] = 0
            t = t + 1
        }
        s = s + 1
    }
    
    // 计算 labels (shifted input_ids for LM loss)
    []float labels = build_labels(input_ids, batch_size, max_len_in_batch)
    
    // 计算效率
    float total_real_tokens = 0.0
    s = 0
    while s < batch_size {
        total_real_tokens = total_real_tokens + float_of_int(min_int(samples[s].seq_len, max_len_in_batch))
        s = s + 1
    }
    float efficiency = total_real_tokens / float_of_int(batch_size * max_len_in_batch)
    
    training_batch batch
    batch.input_ids = input_ids
    batch.attention_mask = attention_mask
    batch.position_ids = position_ids
    batch.labels = labels
    batch.batch_id = loader.total_batches_produced
    batch.effective_batch_ratio = efficiency
    batch.actual_num_samples = batch_size
    batch.load_time_ms = 0.0
    batch.tokenize_time_ms = 0.0
    batch.total_prepare_time_ms = 0.0
    
    return batch
}

// Smart Packed batch (推荐!)
func build_packed_batch(dataloader loader, []tokenized_sample samples) training_batch {
    int target_len = loader.config.max_seq_len
    int batch_size = loader.config.batch_size
    
    // 打包逻辑
    [][]int packed_input_ids = allocate_2d_int(batch_size, target_len)
    [][]int packed_attention_mask = allocate_2d_int(batch_size, target_len)
    [][]int packed_position_ids = allocate_2d_int(batch_size, target_len)
    
    int packed_idx = 0  // 当前 batch 内的第几个 packed sequence
    int sample_idx = 0  // 当前处理到第几个输入样本
    
    while packed_idx < batch_size && sample_idx < len(samples) {
        int offset = 0  // 当前 packed sequence 内的偏移
        
        // 尝试将样本装入当前 block
        while offset < target_len && sample_idx < len(samples) {
            tokenized_sample sample = samples[sample_idx]
            int remaining_space = target_len - offset
            
            if sample.seq_len <= remaining_space {
                // 可以完整放入
                copy_tokens(packed_input_ids[packed_idx], sample.token_ids, offset, sample.seq_len)
                set_range(packed_attention_mask[packed_idx], offset, sample.seq_len, 1)
                
                // Position IDs (如果是 packed,可能需要相对位置)
                set_consecutive(packed_position_ids[packed_idx], offset, sample.seq_len, offset)
                
                offset = offset + sample.seq_len
                sample_idx = sample_idx + 1
            } else {
                // 放不下这个样本了,结束当前 block
                break
            }
            
            // 在样本间添加分隔符 (可选,如 EOS token)
            if offset < target_len {
                packed_input_ids[packed_idx][offset] = 2  // EOS as separator
                packed_attention_mask[packed_idx][offset] = 0  // separator 不参与 loss
                offset = offset + 1
            }
        }
        
        // Pad 剩余部分
        while offset < target_len {
            packed_input_ids[packed_idx][offset] = 0
            packed_attention_mask[packed_idx][offset] = 0
            packed_position_ids[packed_idx][offset] = 0
            offset = offset + 1
        }
        
        packed_idx = packed_idx + 1
    }
    
    // Labels
    []float labels = build_labels(packed_input_ids, packed_idx, target_len)
    
    // 计算效率
    float real_tokens = calculate_real_token_count(packed_attention_mask, packed_idx, target_len)
    float efficiency = real_tokens / float_of_int(packed_idx * target_len)
    
    training_batch batch
    batch.input_ids = packed_input_ids[:packed_idx]
    batch.attention_mask = packed_attention_mask[:packed_idx]
    batch.position_ids = packed_position_ids[:packed_idx]
    batch.labels = labels
    batch.batch_id = loader.total_batches_produced
    batch.effective_batch_ratio = efficiency
    batch.actual_num_samples = sample_idx  // 可能 > batch_size 因为 packing
    batch.load_time_ms = 0.0
    batch.tokenize_time_ms = 0.0
    batch.total_prepare_time_ms = 0.0
    
    return batch
}

// ============================================================================
// 8. 数据质量过滤
// ============================================================================

func passes_quality_filter(tokenized_sample tok, dataloader_config cfg) bool {
    // 1. 长度检查
    if tok.seq_len < cfg.min_seq_len {
        return false  // 太短
    }
    
    if tok.seq_len > cfg.max_seq_len {
        return false  // 太长 (应该在 tokenize 时截断,这里 double-check)
    }
    
    // 2. 字符数检查 (原始文本级别)
    // (需要在 tokenize 前检查,这里简化)
    
    // 3. Token 重复率检查 (启发式)
    if cfg.enable_filtering && cfg.max_token_ratio_to_filter < 1.0 {
        float repetition_ratio = calculate_token_repetition_ratio(tok.token_ids)
        if repetition_ratio > cfg.max_token_ratio_to_filter {
            return false  // 可能是垃圾/低质量数据
        }
    }
    
    return true
}

// 计算 token 重复率 (简单启发式)
func calculate_token_repetition_ratio([]int tokens) float {
    if len(tokens) == 0 { return 0.0 }
    
    // 统计 unique tokens
    map(int, int) freq_map
    int i = 0
    while i < len(tokens) {
        freq_map[tokens[i]] = freq_map[tokens[i]] + 1
        i = i + 1
    }
    
    // 找最高频次的 token 及其占比
    int max_count = 0
    for pair in freq_map {
        if pair.value > max_count {
            max_count = pair.value
        }
    }
    
    return float_of_int(max_count) / float_of_int(len(tokens))
}

// ============================================================================
// 9. 分布式采样
// ============================================================================

// 为每个 rank 确定应该处理哪些样本
func get_local_samples_for_rank(distributed_sampler samp, int num_samples_needed) []int {
    []int local_indices = []int{cap: num_samples_needed}
    
    int fetched = 0
    while fetched < num_samples_needed {
        // 全局索引
        int global_idx = samp.shuffled_indices[samp.current_index]
        
        // 检查是否属于本 rank
        if global_idx % samp.world_size == samp.rank {
            local_indices[fetched] = global_idx
            fetched = fetched + 1
        }
        
        samp.current_index = samp.current_index + 1
        
        // Wrap around
        if samp.current_index >= samp.total_samples {
            samp.current_index = 0
            // Re-shuffle for new epoch
            samp.shuffled_indices = generate_shuffled_indices(samp.total_samples, samp.seed + 1)
        }
    }
    
    return local_indices
}

// Epoch 结束后重置
func reset_for_new_epoch(ref dataloader loader) {
    loader.current_epoch = loader.current_epoch + 1
    loader.current_file_index = 0
    loader.sampler.current_index = 0
    loader.epoch_completed = false
    
    // 重新 shuffle
    loader.sampler.shuffled_indices = generate_shuffled_indices(
        loader.sampler.total_samples,
        loader.config.seed + loader.current_epoch
    )
}

// ============================================================================
// 10. 性能监控
// ============================================================================

func get_dataloader_stats(dataloader loader) dataloader_stats {
    return loader.stats
}

func print_dataloader_summary(dataloader loader) string {
    dataloader_stats stats = loader.stats
    
    "DataLoader Summary:\n" +
    "  Files Scanned: " + string(stats.total_files_scanned) + "\n" +
    "  Data Read: " + string(stats.total_bytes_read / (1024*1024)) + " MB\n" +
    "  Samples Loaded: " + string(stats.total_samples_loaded) + "\n" +
    "  After Filtering: " + string(stats.total_samples_after_filter) + "\n" +
    "  Batches Produced: " + string(stats.total_batches_produced) + "\n" +
    "  Avg Tokens/Sample: " + string(avg_tokens_per_sample, 1) + "\n" +
    "  Packing Efficiency: " + string(stats.packing_efficiency * 100, 1) + "%\n" +
    "  Load Throughput: " + string(stats.load_throughput_mb_s, 1) + " MB/s\n" +
    "  Tokenize Throughput: " + string(stats.tokenize_throughput_k_samples_s, 1) + " K samples/s\n" +
    "  Current Epoch: " + string(loader.current_epoch) + "\n" +
    "  Samples This Epoch: " + string(loader.total_samples_processed)
}

// ============================================================================
// 11. 辅助函数
// ============================================================================

func min_int(int a, int b) int { if a < b { return a }; return b }
func max_int(int a, int b) int { if a > b { return a }; return b }
func float_of_int(int n) float { 
    float r = 0.0; 
    int i = 0; 
    while i < n { r = r + 1.0; i = i + 1 }; 
    return r 
}

func string(int i) string { return "" }

func allocate_2d_int(int rows, int cols) [][]int {
    [][]int m = [][]int{cap: rows}
    int i = 0
    while i < rows { m[i] = []int{cap: cols}; i = i + 1 }
    return m
}

func copy_tokens([]int dst, []int src, int offset, int count) {
    int i = 0
    while i < count { dst[offset+i] = src[i]; i = i + 1 }
}

func set_range([]int arr, int start, int count, int val) {
    int i = 0
    while i < count { arr[start+i] = val; i = i + 1 }
}

func set_consecutive([]int arr, int start, int count, int from_val) {
    int i = 0
    while i < count { arr[start+i] = from_val+i; i = i + 1 }
}

func build_labels([][][]int input_ids, int batch, int seq) []float {
    // Shifted input_ids: labels[t] = input_ids[t+1], last token label = -100 (ignore)
    int total = batch * seq
    []float labels = []float{cap: total}
    int b = 0
    while b < batch {
        int t = 0
        while t < seq - 1 {
            labels[b * seq + t] = float_of_int(input_ids[b][t + 1])
            t = t + 1
        }
        labels[b * seq + seq - 1] = -100.0  // ignore last token
        b = b + 1
    }
    return labels
}

func calculate_real_token_count([][][]int mask, int batch, int seq) float {
    float sum = 0.0
    int b = 0
    while b < batch {
        int t = 0
        while t < seq {
            if mask[b][t] != 0 { sum = sum + 1.0 }
            t = t + 1
        }
        b = b + 1
    }
    return sum
}

func is_batch_ready(training_batch b) bool { return true }
func dequeue_gpu_queue(dataloader l) training_batch { return training_batch{} }
func enqueue_gpu_queue(ref dataloader l, training_batch b) {}
func hash_string(string s) int64 { return 0 }
