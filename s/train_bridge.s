package neurx.train.bridge

// NeurX Training Bridge for S Language
// 连接 S 编译器运行时与 NeurX 训练框架

use std.fs.write_text_file as write_file
use std.fs.read_to_string as read_file
use std.io.println as println

// ============================================
// Checkpoint I/O (对应 s/checkpoint.s)
// ============================================

// 写入 checkpoint 文件 (对应 save_checkpoint)
func checkpoint_save(string path, string content) bool {
    var result = write_file(path, content)
    result.is_ok()
}

// 读取 checkpoint 文件 (对应 load_checkpoint)  
func checkpoint_load(string path) string {
    var result = read_file(path)
    if result.is_ok() {
        return result.unwrap()
    }
    ""
}

// 检查文件是否存在
func file_exists(string path) bool {
    var result = read_file(path)
    result.is_ok()
}

// ============================================
// Training Logging (训练日志)
// ============================================

func log_info(string message) () {
    println("[INFO] " + message)
}

func log_step(int step, float loss, float best_loss) () {
    string step_str = string(step)
    string loss_str = string(loss)
    string best_str = string(best_loss)
    println("Step " + step_str + " | Loss: " + loss_str + " | Best: " + best_str)
}

func log_save(string path) () {
    println("  -> Saved: " + path)
}

func log_header(string title, string subtitle) () {
    println("")
    println("========================================")
    println(title)
    if subtitle != "" {
        println(subtitle)
    }
    println("========================================")
}

func log_footer(string message) () {
    println("========================================")
    println(message)
    println("========================================")
}

// ============================================
// Model Config Helpers (模型配置辅助)
// ============================================

// 格式化参数数量为可读字符串
func format_param_count(int count) string {
    if count >= 1000000 {
        int millions = count / 1000000
        return string(millions) + "M"
    }
    if count >= 1000 {
        int thousands = count / 1000
        return string(thousands) + "K"
    }
    string(count)
}
