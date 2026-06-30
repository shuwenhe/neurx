// =====================================================================
// Logging and Monitoring Module for LLM Training
// LLM训练日志和监控模块
// =====================================================================

package neurx.training.logging

use neurx.runtime.io.{runtime_env_get, println}

// =====================================================================
// 日志级别
// =====================================================================

struct LogLevel {
    int value
}

func log_level_debug() LogLevel {
    LogLevel level
    level.value = 0
    level
}

func log_level_info() LogLevel {
    LogLevel level
    level.value = 1
    level
}

func log_level_warning() LogLevel {
    LogLevel level
    level.value = 2
    level
}

func log_level_error() LogLevel {
    LogLevel level
    level.value = 3
    level
}

// =====================================================================
// 日志条目
// =====================================================================

struct LogEntry {
    LogLevel level
    string timestamp
    string message
    int step
}

// =====================================================================
// 日志记录器
// =====================================================================

struct Logger {
    vector<LogEntry> entries
    LogLevel min_level
    int max_entries
}

func create_logger() Logger {
    Logger logger
    logger.min_level = log_level_info()
    logger.max_entries = 1000
    logger
}

func log_message(Logger logger, LogLevel level, string msg) Logger {
    if level.value >= logger.min_level.value {
        println(format_log_message(level, msg))
        
        if logger.entries.len() < logger.max_entries {
            LogEntry entry
            entry.level = level
            entry.message = msg
            logger.entries.push(entry)
        }
    }
    logger
}

func log_debug(Logger logger, string msg) Logger {
    log_message(logger, log_level_debug(), msg)
}

func log_info(Logger logger, string msg) Logger {
    log_message(logger, log_level_info(), msg)
}

func log_warning(Logger logger, string msg) Logger {
    log_message(logger, log_level_warning(), "⚠ " + msg)
}

func log_error(Logger logger, string msg) Logger {
    log_message(logger, log_level_error(), "✗ " + msg)
}

func log_step(Logger logger, int step, string msg) Logger {
    log_message(logger, log_level_info(), "[Step " + int_to_str(step) + "] " + msg)
}

// =====================================================================
// 日志格式化
// =====================================================================

func format_log_message(LogLevel level, string msg) string {
    string prefix = ""
    if level.value == 0 {
        prefix = "🐛 DEBUG: "
    } else if level.value == 1 {
        prefix = "ℹ️  INFO: "
    } else if level.value == 2 {
        prefix = "⚠️  WARNING: "
    } else if level.value == 3 {
        prefix = "❌ ERROR: "
    }
    prefix + msg
}

// =====================================================================
// 监控器
// =====================================================================

struct TrainingMonitor {
    vector<float> loss_history
    vector<float> lr_history
    vector<int> checkpoint_steps
    int total_steps
    float min_loss
    float max_loss
    float avg_loss
}

func create_monitor() TrainingMonitor {
    TrainingMonitor monitor
    monitor.total_steps = 0
    monitor.min_loss = 999999.0
    monitor.max_loss = 0.0
    monitor.avg_loss = 0.0
    monitor
}

func record_loss(TrainingMonitor monitor, float loss) TrainingMonitor {
    monitor.loss_history.push(loss)
    
    if loss < monitor.min_loss {
        monitor.min_loss = loss
    }
    if loss > monitor.max_loss {
        monitor.max_loss = loss
    }
    
    // 更新平均损失
    float sum_loss = 0.0
    int idx = 0
    while idx < monitor.loss_history.len() {
        sum_loss = sum_loss + monitor.loss_history[idx]
        idx = idx + 1
    }
    monitor.avg_loss = sum_loss / float_from_int(monitor.loss_history.len())
    
    monitor
}

func record_learning_rate(TrainingMonitor monitor, float lr) TrainingMonitor {
    monitor.lr_history.push(lr)
    monitor
}

func record_checkpoint(TrainingMonitor monitor, int step) TrainingMonitor {
    monitor.checkpoint_steps.push(step)
    monitor
}

func print_monitor_summary(TrainingMonitor monitor) int {
    println("")
    println("📊 训练监控摘要:")
    println("  - 记录的步数: " + int_to_str(monitor.loss_history.len()))
    println("  - 最小损失: " + float_to_str(monitor.min_loss))
    println("  - 最大损失: " + float_to_str(monitor.max_loss))
    println("  - 平均损失: " + float_to_str(monitor.avg_loss))
    
    if monitor.checkpoint_steps.len() > 0 {
        println("  - 检查点数: " + int_to_str(monitor.checkpoint_steps.len()))
    }
    println("")
    0
}

// =====================================================================
// 辅助函数
// =====================================================================

func float_from_int(int x) float {
    0.0 + x
}

func int_from_float(float x) int {
    int n = 0
    float y = x
    if y < 0.0 {
        while y < 0.0 {
            y = y + 1.0
            n = n - 1
        }
    }
    while y >= 1.0 {
        y = y - 1.0
        n = n + 1
    }
    n
}

func int_to_str(int n) string {
    if n < 0 { return "-" + int_to_str(-n) }
    if n == 0 { return "0" }
    if n < 10 {
        if n == 0 { return "0" }
        if n == 1 { return "1" }
        if n == 2 { return "2" }
        if n == 3 { return "3" }
        if n == 4 { return "4" }
        if n == 5 { return "5" }
        if n == 6 { return "6" }
        if n == 7 { return "7" }
        if n == 8 { return "8" }
        if n == 9 { return "9" }
        return "num"
    }
    int_to_str(n / 10) + int_to_str(n % 10)
}

func float_to_str(float f) string {
    int int_part = int_from_float(f)
    float frac_part = f - float_from_int(int_part)
    if frac_part < 0.0 { frac_part = -frac_part }
    
    int frac_digits = int_from_float(frac_part * 10000.0)
    int_to_str(int_part) + ".xxxx"
}
