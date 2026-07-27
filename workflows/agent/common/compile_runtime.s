package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_run_command, runtime_run_command_output, runtime_shell_escape}
use std.io.println
func main() int {
    string root_dir = ""
    string s_bin_override = runtime_env_get("S_BIN", runtime_env_get("S_COMPILER", ""))
    string root = resolve_root(root_dir)
    string s_bin = resolve_s_bin(root, s_bin_override)
    if s_bin == "" {
        println("[neurx] compile runtime: missing runnable 's' executable")
        return 1
    }
    if !runtime_run_command("mkdir -p build/ir").ok {
        return 1
    }
    string help_text = runtime_run_command_output(runtime_shell_escape(s_bin) + " --help 2>&1")
    bool legacy_mode = contains_text(help_text, "<input.s> <output.ir>")
    []string roots = []string{cap: 0}
    roots.push("agent")
    roots.push("s")
    roots.push("ops")
    roots.push("data")
    roots.push("tensor")
    roots.push("ad")
    roots.push("engine")
    roots.push("nn")
    roots.push("opt")
    roots.push("lf")
    roots.push("train")
    roots.push("pretrain")
    roots.push("runtime")
    roots.push("distributed")
    roots.push("serving")
    roots.push("infer")
    roots.push("infer/vllm")
    roots.push("model")
    roots.push("platform")
    roots.push("compile")
    roots.push("reasoning")
    roots.push("workflows")
    roots.push("app")
    roots.push("web")
    int r = 0
    while r < len(roots) {
        string root_name = roots[r]
        if runtime_file_exists(root_name) {
            string list = runtime_run_command_output("find " + runtime_shell_escape(root_name) + " -type f -name '*.s' | sort")
            []string srcs = split_lines(list)
            int j = 0
            while j < len(srcs) {
                string src = trim(srcs[j])
                if src != "" {
                    if !compile_one(s_bin, legacy_mode, src) {
                        return 1
                    }
                }
                j = j + 1
            }
        }
        r = r + 1
    }
    string root_path = runtime_run_command_output("pwd")
    string artifact_dir = trim(root_path) + "/build/ir"
    string manifest_path = artifact_dir + "/manifest.json"
    string files = runtime_run_command_output("cd build/ir && find . -type f -name '*.ir' | sed 's#^\\./##' | sort")
    []string manifest_files = split_lines(files)
    string manifest = "{\n"
    manifest = manifest + "  \"source_root\": " + json_escape(trim(root_path)) + ",\n"
    manifest = manifest + "  \"artifact_root\": " + json_escape(artifact_dir) + ",\n"
    manifest = manifest + "  \"ir_files\": [\n"
    int k = 0
    int count = 0
    while k < len(manifest_files) {
        string file = trim(manifest_files[k])
        if file != "" {
            if count > 0 {
                manifest = manifest + ",\n"
            }
            manifest = manifest + "    " + json_escape(file)
            count = count + 1
        }
        k = k + 1
    }
    manifest = manifest + "\n  ]\n"
    manifest = manifest + "}\n"
    _ = runtime_run_command("mkdir -p " + runtime_shell_escape(artifact_dir))
    _ = runtime_run_command_output("printf %s " + runtime_shell_escape(manifest) + " > " + runtime_shell_escape(manifest_path))
    println("runtime manifest: build/ir/manifest.json")
    0
}

func resolve_root(string fallback) string {
    string root = trim(runtime_env_get("NEURX_ROOT", ""))
    if root != "" {
        return root
    }
    if fallback != "" {
        return fallback
    }
    trim(runtime_run_command_output("git rev-parse --show-toplevel 2>/dev/null || pwd"))
}

func resolve_s_bin(string root_dir, string override) string {
    string candidate = trim(override)
    if is_runnable(candidate) {
        return candidate
    }
    candidate = trim(runtime_env_get("S_BIN", ""))
    if is_runnable(candidate) {
        return candidate
    }
    candidate = trim(runtime_env_get("COMPILER_BIN", ""))
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

func compile_one(string s_bin, bool legacy_mode, string src) bool {
    string base = basename_no_ext(src)
    string parent = basename(dirname_of(src))
    string module = src
    if parent == base {
        module = dirname_of(src)
    }
    string target_dir = dirname_of(module)
    string target = "build/ir/" + module + ".ir"
    _ = runtime_run_command("mkdir -p build/ir/" + runtime_shell_escape(target_dir))
    println("Compiling " + src + " -> " + target)
    if legacy_mode {
        return runtime_run_command(runtime_shell_escape(s_bin) + " " + runtime_shell_escape(src) + " " + runtime_shell_escape(target)).ok
    }
    return runtime_run_command(runtime_shell_escape(s_bin) + " ir " + runtime_shell_escape(src) + " -o " + runtime_shell_escape(target)).ok
}

func split_lines(string text) []string {
    []string lines = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = char_at(text, i)
        if ch == "\n" {
            string line = trim(current)
            if line != "" {
                lines.push(line)
            }
            current = ""
        } else if ch != "\r" {
            current = current + ch
        }
        i = i + 1
    }
    string tail = trim(current)
    if tail != "" {
        lines.push(tail)
    }
    lines
}

func basename_no_ext(string path) string {
    string base = basename(path)
    int dot = last_index_of(base, ".")
    if dot < 0 {
        return base
    }
    slice(base, 0, dot)
}

func basename(string path) string {
    int last = last_index_of(path, "/")
    if last < 0 {
        return path
    }
    slice(path, last + 1, len(path))
}

func dirname_of(string path) string {
    int last = last_index_of(path, "/")
    if last < 0 {
        return "."
    }
    if last == 0 {
        return "/"
    }
    slice(path, 0, last)
}

func last_index_of(string text, string pattern) int {
    int last = -1
    int i = 0
    while i + len(pattern) <= len(text) {
        if slice(text, i, i + len(pattern)) == pattern {
            last = i
        }
        i = i + 1
    }
    last
}

func contains_text(string text, string pattern) bool {
    if pattern == "" {
        return true
    }
    int i = 0
    while i + len(pattern) <= len(text) {
        if slice(text, i, i + len(pattern)) == pattern {
            return true
        }
        i = i + 1
    }
    false
}

func json_escape(string s) string {
    string out = "\""
    int i = 0
    while i < len(s) {
        string ch = char_at(s, i)
        if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\\" {
            out = out + "\\\\"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "\""
    out
}
