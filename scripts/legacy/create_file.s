package main
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, runtime_make_dirs, runtime_write_text_file}
use std.io.println

func parent_path(string path) string {
    int slash = -1
    int i = 0
    while i < len(path) {
        if path[i] == 47 { slash = i }
        i = i + 1
    }
    if slash <= 0 { return "." }
    string out = ""
    i = 0
    while i < slash {
        out = out + string_char(path[i])
        i = i + 1
    }
    out
}

func main() int {
    string path = runtime_env_get("NEURX_CREATE_FILE_PATH", "")
    string content = runtime_env_get("NEURX_CREATE_FILE_TEXT", "")
    bool overwrite = runtime_env_get("NEURX_CREATE_FILE_OVERWRITE", "0") == "1"
    if path == "" {
        println("Set NEURX_CREATE_FILE_PATH and NEURX_CREATE_FILE_TEXT")
        return 2
    }
    if runtime_file_exists(path) && !overwrite {
        println("Refusing to overwrite existing file: " + path)
        return 1
    }
    if !runtime_make_dirs(parent_path(path)).ok {
        println("Failed to create parent directory")
        return 1
    }
    runtime_write_text_file(path, content)
    println("Created: " + path)
    0
}
