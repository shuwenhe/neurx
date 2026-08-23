package neurx.train.bridge
use std.fs.write_text_file as write_file
use std.fs.read_to_string as read_file

func checkpoint_save(string path, string content) bool {
    var result = write_file(path, content)
    result.is_ok()
}

func checkpoint_load(string path) string {
    var result = read_file(path)
    if result.is_ok() {
        return result.unwrap()
    }
    ""
}

func file_exists(string path) bool {
    var result = read_file(path)
    result.is_ok()
}

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
