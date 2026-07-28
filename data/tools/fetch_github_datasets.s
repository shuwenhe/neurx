package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape, trim}
use std.io.println

func main() int {
    string root = dataset_root()
    bool force = runtime_env_get("NEURX_GITHUB_DATASETS_FORCE", "0") == "1"
    string list_file = runtime_env_get("NEURX_GITHUB_DATASETS_FILE", "")
    string keys = runtime_env_get("NEURX_GITHUB_DATASETS", "")
    if list_file != "" {
        if !runtime_run_command("test -f " + runtime_shell_escape(list_file)).ok {
            println("List file not found: " + list_file)
            return 1
        }
        return clone_from_file(root, list_file, force)
    }
    if keys == "" {
        println("Usage: set NEURX_GITHUB_DATASETS=human-eval,mbpp,apps,... or NEURX_GITHUB_DATASETS_FILE=/path/to/list.txt")
        println("Known keys: human-eval mbpp apps codexglue code-search-net codeparrot")
        return 1
    }
    []string items = split_commas(keys)
    int rc = 0
    int i = 0
    while i < len(items) {
        string key = trim(items[i])
        string url = known_repo(key)
        if url == "" {
            println("Unknown dataset key: " + key)
            rc = 1
            i = i + 1
            continue
        }
        string name = normalize_name(key)
        string dest = root + "/" + name
        println("Cloning " + key + " -> " + dest)
        if force {
            _ = runtime_run_command("rm -rf " + runtime_shell_escape(dest))
        }
        if !clone_repo(url, dest) {
            rc = 1
        }
        if key == "mbpp" {
            handle_mbpp(root, dest)
        }
        i = i + 1
    }
    println("All done. Data available under " + root)
    rc
}

func dataset_root() string {
    string root = runtime_run_command_output("cd dataset 2>/dev/null && pwd || pwd")
    if root == "" {
        return "dataset"
    }
    root
}

func clone_from_file(string root, string list_file, bool force) int {
    string list_text = runtime_run_command_output("cat " + runtime_shell_escape(list_file))
    []string lines = split_lines(list_text)
    int i = 0
    while i < len(lines) {
        string line = trim(lines[i])
        if line != "" {
            string repo = first_token(line)
            string url = repo
            if !starts_with(url, "http:
                url = "https:
            }
            string name = basename(repo)
            string dest = root + "/" + name
            if force {
                _ = runtime_run_command("rm -rf " + runtime_shell_escape(dest))
            }
            if !clone_repo(url, dest) {
                return 1
            }
        }
        i = i + 1
    }
    0
}

func split_commas(string text) []string {
    []string out = []string{cap: 0}
    string current = ""
    int i = 0
    while i < len(text) {
        string ch = char_at(text, i)
        if ch == "," {
            if current != "" {
                out.push(current)
            }
            current = ""
        } else {
            current = current + ch
        }
        i = i + 1
    }
    if current != "" {
        out.push(current)
    }
    out
}

func clone_repo(string url, string dest) bool {
    if runtime_run_command("test -d " + runtime_shell_escape(dest)).ok {
        println("Destination " + dest + " already exists - skipping")
        return true
    }
    if runtime_run_command("git clone --depth 1 " + runtime_shell_escape(url) + " " + runtime_shell_escape(dest)).ok {
        return true
    }
    println("git clone failed for " + url + ", trying full clone")
    runtime_run_command("git clone " + runtime_shell_escape(url) + " " + runtime_shell_escape(dest)).ok
}

func known_repo(string key) string {
    if key == "human-eval" {
        return runtime_env_get("NEURX_HUMAN_EVAL_REPO_URL", "https:
    }
    if key == "mbpp" {
        return "https:
    }
    if key == "apps" {
        return "https:
    }
    if key == "codexglue" || key == "codex-glue" || key == "codex_glue" {
        return "https:
    }
    if key == "code-search-net" || key == "codesearchnet" || key == "code_search_net" {
        return "https:
    }
    if key == "codeparrot" {
        return "https:
    }
    ""
}

func handle_mbpp(string root, string dest) {
    if runtime_run_command("test -d " + runtime_shell_escape(dest + "/google-research/mbpp")).ok {
        _ = runtime_run_command("mv " + runtime_shell_escape(dest + "/google-research/mbpp") + " " + runtime_shell_escape(root + "/mbpp"))
        _ = runtime_run_command("rm -rf " + runtime_shell_escape(dest))
    }
}

func normalize_name(string key) string {
    int i = 0
    string out = ""
    while i < len(key) {
        string ch = char_at(key, i)
        if ch == "_" {
            out = out + "-"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}

func basename(string path) string {
    int last = last_index_of(path, "/")
    if last < 0 {
        return path
    }
    string out = slice(path, last + 1, len(path))
    int dot = last_index_of(out, ".")
    if dot > 0 {
        return slice(out, 0, dot)
    }
    out
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

func first_token(string text) string {
    int i = 0
    while i < len(text) {
        if char_at(text, i) == " " || char_at(text, i) == "\t" {
            return slice(text, 0, i)
        }
        i = i + 1
    }
    text
}

func starts_with(string text, string prefix) bool {
    len(prefix) <= len(text) && slice(text, 0, len(prefix)) == prefix
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
