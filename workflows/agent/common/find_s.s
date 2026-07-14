package main

use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println

func main() int {
    string root_dir = runtime_env_get("NEURX_FIND_S_ROOT", "")
    string resolved = resolve_s_bin(root_dir)
    if resolved == "" {
        return 1
    }

    println(resolved)
    0
}

func resolve_s_bin(string root_dir) string {
    string candidate = trim(runtime_env_get("S_BIN", ""))
    if is_runnable(candidate) {
        return candidate
    }

    candidate = trim(runtime_run_command_output("command -v s 2>/dev/null || true"))
    if is_runnable(candidate) {
        return candidate
    }

    candidate = trim(runtime_env_get("S_ROOT", "")) + "/bin/s"
    if is_runnable(candidate) {
        return candidate
    }
    candidate = trim(runtime_env_get("S_ROOT", "")) + "/bin/s_x86_64"
    if is_runnable(candidate) {
        return candidate
    }

    candidate = trim(runtime_env_get("HOME", "")) + "/s/bin/s"
    if is_runnable(candidate) {
        return candidate
    }
    candidate = trim(runtime_env_get("HOME", "")) + "/s/bin/s_x86_64"
    if is_runnable(candidate) {
        return candidate
    }

    if root_dir != "" {
        candidate = root_dir + "/../s/bin/s"
        if is_runnable(candidate) {
            return candidate
        }
        candidate = root_dir + "/../s/bin/s_x86_64"
        if is_runnable(candidate) {
            return candidate
        }
    }

    ""
}

func is_runnable(string path) bool {
    string trimmed = trim(path)
    if trimmed == "" {
        return false
    }
    runtime_file_exists(trimmed) && runtime_run_command_output("test -x " + runtime_shell_escape(trimmed) + " && printf ok || true") == "ok"
}
