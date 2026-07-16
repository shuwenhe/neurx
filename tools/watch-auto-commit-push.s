package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape}
use std.io.println

func main() int {
    string branch = runtime_env_get("NEURX_WATCH_BRANCH", "main")
    string interval = runtime_env_get("NEURX_WATCH_INTERVAL", "2")
    string debounce = runtime_env_get("NEURX_WATCH_DEBOUNCE", "1")
    string prefix = runtime_env_get("NEURX_AUTO_COMMIT_PREFIX", "feat: auto-save")

    string current = runtime_run_command_output("git symbolic-ref --quiet --short HEAD 2>/dev/null || true")
    if current != branch {
        println("watcher: current branch is '" + current + "', expected '" + branch + "'")
        return 1
    }

    println("watcher: monitoring branch '" + branch + "'")
    println("watcher: prefix '" + prefix + "'")
    while true {
        if runtime_run_command("git diff --quiet && git diff --cached --quiet").ok {
            _ = runtime_run_command("sleep " + interval)
            continue
        }

        _ = runtime_run_command("git add -A")
        string stats = runtime_run_command_output("git diff --cached --numstat | awk '{added+=$1; removed+=$2} END {print added+0 \" \" removed+0}'")
        string added = first_field(stats)
        string removed = second_field(stats)
        string changed = runtime_run_command_output("git diff --cached --name-only | tr '\n' ' '")
        string message = generate_commit_message(prefix, changed, added, removed)

        if runtime_run_command("git commit -m " + runtime_shell_escape(message)).ok {
            println("watcher: committed: " + message)
            _ = runtime_run_command("git push origin " + runtime_shell_escape(branch))
        }
        _ = runtime_run_command("sleep " + debounce)
    }
    0
}

func generate_commit_message(string prefix, string changed, string added, string removed) string {
    if changed == "" {
        return prefix + ": update code (" + added + " added, " + removed + " removed)"
    }
    if contains(changed, "scripts/legacy/") {
        return prefix + ": update scripts (" + added + " added, " + removed + " removed)"
    }
    if contains(changed, "docs/") {
        return prefix + ": update docs (" + added + " added, " + removed + " removed)"
    }
    if contains(changed, "tools/") {
        return prefix + ": update tooling (" + added + " added, " + removed + " removed)"
    }
    return prefix + ": update code (" + added + " added, " + removed + " removed)"
}

func contains(string text, string needle) bool {
    int i = 0
    while i + len(needle) <= len(text) {
        if slice(text, i, i + len(needle)) == needle {
            return true
        }
        i = i + 1
    }
    false
}

func first_field(string text) string {
    int sp = index_of_space(text)
    if sp < 0 {
        return text
    }
    slice(text, 0, sp)
}

func second_field(string text) string {
    int sp = index_of_space(text)
    if sp < 0 || sp + 1 >= len(text) {
        return "0"
    }
    slice(text, sp + 1, len(text))
}

func index_of_space(string text) int {
    int i = 0
    while i < len(text) {
        if char_at(text, i) == " " {
            return i
        }
        i = i + 1
    }
    -1
}
