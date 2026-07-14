package neurx.monitoring.moe_1t_metrics

// ============================================================================
// 1T MoE 分布式监控系统
//
// 收集的指标:
//   1. 训练指标
//      - loss, perplexity, tokens/sec
//      - 梯度范数, 权重范数
//   
//   2. MoE 指标
//      - 每个专家的负载
//      - 路由分布
//      - 专家利用率
//   
//   3. 通信指标
//      - AllGather/ReduceScatter/AllReduce 延迟
//      - 带宽利用率
//      - 通信与计算的重叠比例
//   
//   4. 系统指标
//      - GPU 内存用量
//      - 热度/功耗
//      - 吞吐量
//      - 墙钟时间
//
// ============================================================================

use neurx.strings
use neurx.runtime.io.{io_println, runtime_make_dirs, runtime_write_text_file, runtime_run_command_output}

// ============================================================================
// 1. 指标类型定义
// ============================================================================

struct training_metrics {
    float loss
    float loss_ce
    float loss_aux
    float loss_kl
    float perplexity
    float learning_rate
    float gradient_norm
    float weight_norm
    float gradient_flow
}

struct moe_metrics {
    []float expert_load           // [num_experts]
    []float expert_utilization    // [num_experts]
    []int expert_dropout_count    // [num_experts] 超容量的 token 数
    float load_balance_ratio      // max_load / mean_load
    float expert_diversity        // 使用的不同专家比例
}

struct communication_metrics {
    long allgather_bytes
    long allreduce_bytes
    long reduce_scatter_bytes
    float allgather_time_ms
    float allreduce_time_ms
    float reduce_scatter_time_ms
    float communication_compute_overlap_ratio
}

struct system_metrics {
    long gpu_memory_used_bytes
    long gpu_memory_total_bytes
    float gpu_memory_percent
    float gpu_power_watts
    float gpu_temperature_celsius
    float throughput_tokens_per_sec
    long wall_clock_time_ms
    float iteration_time_ms
}

struct metrics_frame {
    int step
    int global_rank
    long timestamp_ms
    
    training_metrics train_metrics
    moe_metrics moe_metrics
    communication_metrics comm_metrics
    system_metrics sys_metrics
}

// ============================================================================
// 2. 指标收集器
// ============================================================================

struct metrics_collector {
    int global_rank
    int world_size
    int local_rank
    int local_world_size
    
    // 当前帧
    metrics_frame current_frame
    
    // 历史帧
    []metrics_frame frames_history
    int max_history_size
    
    // 聚合统计
    float avg_loss
    float max_loss
    float min_loss
    int steps_logged
    
    // 输出配置
    int log_frequency            // 每 N 步输出一次
    int save_frequency
    string metrics_output_dir
}

// 初始化指标收集器
func metrics_collector_new(
    int global_rank,
    int world_size,
    int local_rank,
    int local_world_size,
    string output_dir
) metrics_collector {
    
    metrics_collector collector = metrics_collector {
        global_rank: global_rank,
        world_size: world_size,
        local_rank: local_rank,
        local_world_size: local_world_size,
        current_frame: metrics_frame {
            step: 0,
            global_rank: global_rank,
            timestamp_ms: 0,
            train_metrics: training_metrics {
                loss: 0.0,
                loss_ce: 0.0,
                loss_aux: 0.0,
                loss_kl: 0.0,
                perplexity: 0.0,
                learning_rate: 0.0,
                gradient_norm: 0.0,
                weight_norm: 0.0,
                gradient_flow: 0.0,
            },
            moe_metrics: moe_metrics {
                expert_load: make([]float, 256),
                expert_utilization: make([]float, 256),
                expert_dropout_count: make([]int, 256),
                load_balance_ratio: 0.0,
                expert_diversity: 0.0,
            },
            comm_metrics: communication_metrics {
                allgather_bytes: 0,
                allreduce_bytes: 0,
                reduce_scatter_bytes: 0,
                allgather_time_ms: 0.0,
                allreduce_time_ms: 0.0,
                reduce_scatter_time_ms: 0.0,
                communication_compute_overlap_ratio: 0.0,
            },
            sys_metrics: system_metrics {
                gpu_memory_used_bytes: 0,
                gpu_memory_total_bytes: 79 * 1024 * 1024 * 1024,  // 80GB
                gpu_memory_percent: 0.0,
                gpu_power_watts: 0.0,
                gpu_temperature_celsius: 0.0,
                throughput_tokens_per_sec: 0.0,
                wall_clock_time_ms: 0,
                iteration_time_ms: 0.0,
            },
        },
        frames_history: make([]metrics_frame, 0),
        max_history_size: 1000,
        avg_loss: 0.0,
        max_loss: 0.0,
        min_loss: 0.0,
        steps_logged: 0,
        log_frequency: 100,
        save_frequency: 1000,
        metrics_output_dir: output_dir,
    }

    if output_dir != "" {
        runtime_make_dirs(output_dir)
    }
    
    collector
}

// ============================================================================
// 3. 训练指标更新
// ============================================================================

// 更新训练指标
func update_training_metrics(
    metrics_collector collector,
    float loss,
    float loss_ce,
    float loss_aux,
    float learning_rate,
    float gradient_norm
) {
    
    collector.current_frame.train_metrics.loss = loss
    collector.current_frame.train_metrics.loss_ce = loss_ce
    collector.current_frame.train_metrics.loss_aux = loss_aux
    collector.current_frame.train_metrics.learning_rate = learning_rate
    collector.current_frame.train_metrics.gradient_norm = gradient_norm
    collector.current_frame.train_metrics.weight_norm = collector.current_frame.train_metrics.weight_norm
    
    // 计算 perplexity
    float perplexity = 0.0
    if loss > 0.0 {
        perplexity = exp(loss)
    }
    collector.current_frame.train_metrics.perplexity = perplexity
    collector.current_frame.timestamp_ms = current_timestamp_ms()
    
    // 更新聚合统计
    collector.avg_loss = (collector.avg_loss * float(collector.steps_logged) + loss) / 
                        float(collector.steps_logged + 1)
    
    if loss > collector.max_loss || collector.steps_logged == 0 {
        collector.max_loss = loss
    }
    if loss < collector.min_loss || collector.steps_logged == 0 {
        collector.min_loss = loss
    }
}

// ============================================================================
// 4. MoE 指标更新
// ============================================================================

// 更新 MoE 指标
func update_moe_metrics(
    metrics_collector collector,
    []float expert_load,              // [num_experts]
    []float expert_utilization,       // [num_experts]
    []int expert_dropout_count
) {
    
    collector.current_frame.moe_metrics.expert_load = expert_load
    collector.current_frame.moe_metrics.expert_utilization = expert_utilization
    collector.current_frame.moe_metrics.expert_dropout_count = expert_dropout_count
    
    // 计算负载平衡比率
    float max_load = 0.0
    float sum_load = 0.0
    float active_experts = 0.0
    
    int e = 0
    while e < len(expert_load) {
        if expert_load[e] > 0.0 {
            active_experts = active_experts + 1.0
        }
        if expert_load[e] > max_load {
            max_load = expert_load[e]
        }
        sum_load = sum_load + expert_load[e]
        e = e + 1
    }
    
    float mean_load = 0.0
    if len(expert_load) > 0 {
        mean_load = sum_load / float(len(expert_load))
    }
    
    float load_balance = 1.0
    if mean_load > 0.0 {
        load_balance = max_load / mean_load
    }
    
    collector.current_frame.moe_metrics.load_balance_ratio = load_balance
    
    // 专家多样性 = 活跃专家数 / 总专家数
    if len(expert_load) > 0 {
        collector.current_frame.moe_metrics.expert_diversity = active_experts / float(len(expert_load))
    }
}

// ============================================================================
// 5. 通信指标更新
// ============================================================================

// 更新通信指标
func update_communication_metrics(
    metrics_collector collector,
    long allgather_bytes,
    long allreduce_bytes,
    long reduce_scatter_bytes,
    float allgather_time_ms,
    float allreduce_time_ms,
    float reduce_scatter_time_ms
) {
    
    collector.current_frame.comm_metrics.allgather_bytes = allgather_bytes
    collector.current_frame.comm_metrics.allreduce_bytes = allreduce_bytes
    collector.current_frame.comm_metrics.reduce_scatter_bytes = reduce_scatter_bytes
    collector.current_frame.comm_metrics.allgather_time_ms = allgather_time_ms
    collector.current_frame.comm_metrics.allreduce_time_ms = allreduce_time_ms
    collector.current_frame.comm_metrics.reduce_scatter_time_ms = reduce_scatter_time_ms
}

// ============================================================================
// 6. 系统指标更新
// ============================================================================

// 更新系统指标
func update_system_metrics(
    metrics_collector collector,
    long gpu_memory_used,
    float gpu_power,
    float gpu_temp,
    float throughput,
    float iteration_time
) {
    
    collector.current_frame.sys_metrics.gpu_memory_used_bytes = gpu_memory_used
    collector.current_frame.sys_metrics.gpu_power_watts = gpu_power
    collector.current_frame.sys_metrics.gpu_temperature_celsius = gpu_temp
    collector.current_frame.sys_metrics.throughput_tokens_per_sec = throughput
    collector.current_frame.sys_metrics.iteration_time_ms = iteration_time
    collector.current_frame.sys_metrics.wall_clock_time_ms = current_timestamp_ms()
    
    // 计算内存百分比
    long total_mem = collector.current_frame.sys_metrics.gpu_memory_total_bytes
    if total_mem > 0 {
        collector.current_frame.sys_metrics.gpu_memory_percent = 
            float(gpu_memory_used) / float(total_mem) * 100.0
    }
}

// ============================================================================
// 7. 日志输出
// ============================================================================

// 记录当前指标帧
func log_step(
    metrics_collector collector,
    int step
) {
    
    collector.current_frame.step = step
    collector.steps_logged = collector.steps_logged + 1
    
    // 添加到历史
    if len(collector.frames_history) < collector.max_history_size {
        collector.frames_history = append_frame(collector.frames_history, collector.current_frame)
    }
    if len(collector.frames_history) > collector.max_history_size {
        collector.frames_history = trim_history(collector.frames_history, collector.max_history_size)
    }
    
    // 定期输出日志
    if step % collector.log_frequency == 0 {
        log_metrics_frame(collector.current_frame)
    }
}

// 输出指标帧
func log_metrics_frame(metrics_frame frame) {
    
    string log_str = ""
    log_str = log_str + "Step=" + int_to_string(frame.step) + " "
    log_str = log_str + "Loss=" + float_to_string(frame.train_metrics.loss, 4) + " "
    log_str = log_str + "LR=" + float_to_string(frame.train_metrics.learning_rate, 6) + " "
    log_str = log_str + "Perplexity=" + float_to_string(frame.train_metrics.perplexity, 2) + " "
    log_str = log_str + "GradNorm=" + float_to_string(frame.train_metrics.gradient_norm, 4) + " "
    log_str = log_str + "MoE-Load=" + float_to_string(frame.moe_metrics.load_balance_ratio, 2) + " "
    log_str = log_str + "Throughput=" + float_to_string(frame.sys_metrics.throughput_tokens_per_sec, 0) + " tokens/sec "
    log_str = log_str + "Memory=" + float_to_string(frame.sys_metrics.gpu_memory_percent, 1) + "%"
    
    io_println(log_str)
}

// ============================================================================
// 8. 聚合统计
// ============================================================================

// 收集全局统计 (AllReduce)
func collect_global_stats(
    metrics_collector collector,
    collective_state comm
) {
    
    // 在实际实现中，需要对所有 GPU 进行 AllReduce
    // 这里只是本地统计
    
    io_println("Global stats collected for rank=" + int_to_string(collector.global_rank))
}

// 保存指标到文件
func save_metrics(
    metrics_collector collector,
    string filename
) {
    string payload = metrics_to_csv(collector)
    runtime_write_text_file(filename, payload)
    io_println("Metrics saved to " + filename)
}

// ============================================================================
// 9. 工具函数
// ============================================================================

func append_frame([]metrics_frame frames, metrics_frame f) []metrics_frame {
    int n = len(frames)
    []metrics_frame out = []metrics_frame{cap: n + 1}
    int i = 0
    while i < n {
        out[i] = frames[i]
        i = i + 1
    }
    out[n] = f
    out
}

func exp(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i < 12 {
        term = term * x / float(i)
        result = result + term
        i = i + 1
    }
    result
}

func int_to_string(int x) string {
    if x == 0 {
        return "0"
    }
    bool neg = false
    int value = x
    if value < 0 {
        neg = true
        value = -value
    }
    string out = ""
    while value > 0 {
        int digit = value % 10
        out = string(digit + 48) + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func float_to_string(float x, int precision) string {
    if precision < 0 {
        precision = 0
    }
    bool neg = false
    float value = x
    if value < 0.0 {
        neg = true
        value = -value
    }

    int scale = 1
    int i = 0
    while i < precision {
        scale = scale * 10
        i = i + 1
    }

    int scaled = int(value * float(scale) + 0.5)
    int whole = 0
    int frac = 0
    if scale > 0 {
        whole = scaled / scale
        frac = scaled % scale
    } else {
        whole = int(value)
    }

    string result = ""
    if neg {
        result = "-"
    }
    result = result + int_to_string(whole)
    if precision > 0 {
        result = result + "."
        string frac_str = int_to_string(frac)
        int pad = precision - len(frac_str)
        while pad > 0 {
            result = result + "0"
            pad = pad - 1
        }
        result = result + frac_str
    }
    result
}

func trim_history([]metrics_frame frames, int limit) []metrics_frame {
    int n = len(frames)
    if n <= limit {
        return frames
    }
    []metrics_frame out = []metrics_frame{cap: limit}
    int start = n - limit
    int i = 0
    while i < limit {
        out[i] = frames[start + i]
        i = i + 1
    }
    out
}

func metrics_to_csv(metrics_collector collector) string {
    string out = "step,rank,timestamp_ms,loss,loss_ce,loss_aux,loss_kl,perplexity,learning_rate,gradient_norm,weight_norm,gradient_flow,load_balance_ratio,expert_diversity,allgather_bytes,allreduce_bytes,reduce_scatter_bytes,allgather_time_ms,allreduce_time_ms,reduce_scatter_time_ms,overlap_ratio,gpu_memory_used_bytes,gpu_memory_total_bytes,gpu_memory_percent,gpu_power_watts,gpu_temperature_celsius,throughput_tokens_per_sec,wall_clock_time_ms,iteration_time_ms\n"
    int i = 0
    while i < len(collector.frames_history) {
        metrics_frame f = collector.frames_history[i]
        out = out + int_to_string(f.step) + ","
        out = out + int_to_string(f.global_rank) + ","
        out = out + int_to_string(f.timestamp_ms) + ","
        out = out + float_to_string(f.train_metrics.loss, 4) + ","
        out = out + float_to_string(f.train_metrics.loss_ce, 4) + ","
        out = out + float_to_string(f.train_metrics.loss_aux, 4) + ","
        out = out + float_to_string(f.train_metrics.loss_kl, 4) + ","
        out = out + float_to_string(f.train_metrics.perplexity, 4) + ","
        out = out + float_to_string(f.train_metrics.learning_rate, 8) + ","
        out = out + float_to_string(f.train_metrics.gradient_norm, 4) + ","
        out = out + float_to_string(f.train_metrics.weight_norm, 4) + ","
        out = out + float_to_string(f.train_metrics.gradient_flow, 4) + ","
        out = out + float_to_string(f.moe_metrics.load_balance_ratio, 4) + ","
        out = out + float_to_string(f.moe_metrics.expert_diversity, 4) + ","
        out = out + long_to_string(f.comm_metrics.allgather_bytes) + ","
        out = out + long_to_string(f.comm_metrics.allreduce_bytes) + ","
        out = out + long_to_string(f.comm_metrics.reduce_scatter_bytes) + ","
        out = out + float_to_string(f.comm_metrics.allgather_time_ms, 4) + ","
        out = out + float_to_string(f.comm_metrics.allreduce_time_ms, 4) + ","
        out = out + float_to_string(f.comm_metrics.reduce_scatter_time_ms, 4) + ","
        out = out + float_to_string(f.comm_metrics.communication_compute_overlap_ratio, 4) + ","
        out = out + long_to_string(f.sys_metrics.gpu_memory_used_bytes) + ","
        out = out + long_to_string(f.sys_metrics.gpu_memory_total_bytes) + ","
        out = out + float_to_string(f.sys_metrics.gpu_memory_percent, 4) + ","
        out = out + float_to_string(f.sys_metrics.gpu_power_watts, 4) + ","
        out = out + float_to_string(f.sys_metrics.gpu_temperature_celsius, 4) + ","
        out = out + float_to_string(f.sys_metrics.throughput_tokens_per_sec, 4) + ","
        out = out + long_to_string(f.sys_metrics.wall_clock_time_ms) + ","
        out = out + float_to_string(f.sys_metrics.iteration_time_ms, 4) + "\n"
        i = i + 1
    }
    out
}

func long_to_string(long x) string {
    int value = int(x)
    int_to_string(value)
}

func current_timestamp_ms() long {
    string raw = runtime_run_command_output("python3 -c 'import time; print(int(time.time()*1000))'")
    long value = long(parse_int_str(raw))
    if value > 0 {
        return value
    }
    0
}

func parse_int_str(string s) int {
    string text = trim(s)
    if text == "" {
        return 0
    }
    bool neg = false
    int i = 0
    if string(text[0]) == "-" {
        neg = true
        i = 1
    }
    int value = 0
    while i < len(text) {
        string ch = string(text[i])
        if ch < "0" || ch > "9" {
            return 0
        }
        value = value * 10 + (int(ch) - 48)
        i = i + 1
    }
    if neg {
        value = -value
    }
    value
}
