package neurx.runtime.io

use std.env.get as env_get
use std.fs.read_to_string as fs_read_to_string
use std.fs.write_text_file as fs_write_text_file
use std.process.run_process
use std.vec.vec

struct json_value {
}

struct runtime_command_result {
    bool ok
    int exit_code
    string error
}

func runtime_read_text_file(string path) string {
    result[string, std.fs.fs_error] out = fs_read_to_string(path)
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
    fs_read_to_string(path).is_ok()
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

    vec[string] argv = vec[string]()
    argv.push("sh")
    argv.push("-c")
    argv.push(cmd)
    result[(), std.process.process_error] out = run_process(argv)
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
