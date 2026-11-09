package neurx.runtime.io
import ("neurx.runtime.command")
extern "intrinsic" func __host_read_to_string(string path) string
extern "intrinsic" func __host_write_text_file(string path, string content) int
extern "intrinsic" func __host_byte_at(string text, int index) int
extern "intrinsic" func __host_char_at(string text, int index) string
extern "intrinsic" func __host_env_exists(string name) bool
extern "intrinsic" func __host_run_argv_output(string[] args) string
struct json_value {
}

struct runtime_command_result {
    bool ok
    int exit_code
    string error
}

func trim(string s) string {
    int i = 0
    for i < len(s) && (__host_byte_at(s, i) == 32 || __host_byte_at(s, i) == 9 || __host_byte_at(s, i) == 10 || __host_byte_at(s, i) == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    for j >= 0 && (__host_byte_at(s, j) == 32 || __host_byte_at(s, j) == 9 || __host_byte_at(s, j) == 10 || __host_byte_at(s, j) == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    string out = ""
    int k = i
    for k <= j {
        out = out + __host_char_at(s, k)
        k = k + 1
    }
    out
}

func runtime_shell_escape(string value) string {
    return neurx.runtime.command.runtime_shell_escape(value)
}

func runtime_read_text_file(string path) string {
    return __host_read_to_string(path)
}
extern "intrinsic" func __host_read_binary_file(string path) int[]
func runtime_read_binary_file(string path) int[] {
    __host_read_binary_file(path)
}

func runtime_write_text_file(string path, string content) () {
    __host_write_text_file(path, content)
    return
}

func runtime_append_text_file(string path, string content) () {
    string previous = runtime_read_text_file(path)
    runtime_write_text_file(path, previous + content)
}

func runtime_file_exists(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    runtime_run_command("test -e " + neurx.runtime.command.runtime_shell_escape(trimmed)).ok
}

func runtime_dir_exists(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    runtime_run_command("test -d " + neurx.runtime.command.runtime_shell_escape(trimmed)).ok
}

func runtime_make_dirs(string path) runtime_command_result {
    string trimmed = trim(path)
    if trimmed == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_path",
        }
    }
    runtime_run_command("mkdir -p " + neurx.runtime.command.runtime_shell_escape(trimmed))
}

func runtime_delete_path(string path, bool recursive) runtime_command_result {
    string trimmed = trim(path)
    if trimmed == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_path",
        }
    }
    string command = ""
    if recursive {
        command = "rm -rf -- " + neurx.runtime.command.runtime_shell_escape(trimmed)
    } else {
        command = "rm -f -- " + neurx.runtime.command.runtime_shell_escape(trimmed)
    }
    runtime_run_command(command)
}

func runtime_env_get(string name, string default_value) string {
    return neurx.runtime.command.runtime_env_get(name, default_value)
}

func runtime_env_has(string name) bool {
    return __host_env_exists(name)
}

func runtime_run_command(string command) runtime_command_result {
    cmd := trim(command)
    if cmd == "" {
        return runtime_command_result { ok: false, exit_code: 1, error: "empty_command" }
    }
    status := neurx.runtime.command.runtime_run_command_exit_code(cmd)
    if status == 0 { return runtime_command_result { ok: true, exit_code: 0, error: "" } }
    return runtime_command_result { ok: false, exit_code: status, error: "command_failed" }
}

func runtime_run_command_output(string command) string {
    cmd := trim(command)
    if cmd == "" { return "" }
    argv := string[]()
    argv.push("/bin/sh")
    argv.push("-c")
    argv.push(cmd)
    return __host_run_argv_output(argv)
}

func runtime_run_command_exit_code(string command) int {
    return neurx.runtime.command.runtime_run_command_exit_code(command)
}

func runtime_json_parse(string text) json_value {
    json_value {}
}

func runtime_json_stringify(json_value value) string {
    "{}"
}

func runtime_read_json_file(string path) json_value {
    json_value {}
}

func runtime_write_json_file(string path, json_value value) () {
    runtime_write_text_file(path, runtime_json_stringify(value))
}
