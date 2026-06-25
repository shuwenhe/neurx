package neurx.runtime.io

use std.env.get as env_get
use std.fs.read_to_string as fs_read_to_string
use std.fs.write_text_file as fs_write_text_file
use std.process.run_process
use std.process.run_process_output
use std.vec.vec

struct json_value {
}

struct runtime_command_result {
    bool ok
    int exit_code
    string error
}

func runtime_shell_escape(string value) string {
    string out = "'"
    int i = 0
    while i < len(value) {
        string ch = string(value[i])
        // '\'' ASCII is 39
        if int(ch) == 39 {
            out = neurx.strings.concat2(out, "'\"'\"'")
        } else {
            out = neurx.strings.concat2(out, ch)
        }
        i = i + 1
    }
    neurx.strings.concat2(out, "'")
}

func runtime_read_text_file(string path) string {
    var out = fs_read_to_string(path)
    if out.is_ok() {
        return out.unwrap()
    }
    ""
}

func runtime_write_text_file(string path, string content) () {
    fs_write_text_file(path, content)
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
    if fs_read_to_string(trimmed).is_ok() {
        return true
    }
    runtime_run_command("test -e " + runtime_shell_escape(trimmed)).ok
}

func runtime_dir_exists(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    runtime_run_command("test -d " + runtime_shell_escape(trimmed)).ok
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
    runtime_run_command("mkdir -p " + runtime_shell_escape(trimmed))
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
        command = "rm -rf -- " + runtime_shell_escape(trimmed)
    } else {
        command = "rm -f -- " + runtime_shell_escape(trimmed)
    }
    runtime_run_command(command)
}

func runtime_env_get(string name, string default_value) string {
    env_get(name).unwrap_or(default_value)
}

func runtime_env_has(string name) bool {
    env_get(name).is_some()
}

func runtime_run_command(string command) runtime_command_result {
    string cmd = trim(command)
    if cmd == "" {
        return runtime_command_result {
            ok: false,
            exit_code: 1,
            error: "empty_command",
        }
    }

    []string argv = []string{cap: 3}
    argv[0] = "sh"
    argv[1] = "-c"
    argv[2] = cmd
    var out = run_process(argv)
    if out.is_ok() {
        return runtime_command_result {
            ok: true,
            exit_code: 0,
            error: "",
        }
    }
    runtime_command_result {
        ok: false,
        exit_code: 1,
        error: out.unwrap_err().message,
    }
}

func runtime_run_command_output(string command) string {
    string cmd = trim(command)
    if cmd == "" {
        return ""
    }
    []string argv = []string{cap: 3}
    argv[0] = "sh"
    argv[1] = "-c"
    argv[2] = cmd
    var out = run_process_output(argv)
    if out.is_ok() {
        return out.unwrap()
    }
    ""
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
