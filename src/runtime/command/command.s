package neurx.runtime.command
extern "intrinsic" func runtime_env_get(string name, string default_value) string
extern "intrinsic" func __host_run_argv(string[] args) int
extern "intrinsic" func __host_byte_at(string text, int index) int
extern "intrinsic" func __host_char_at(string text, int index) string

func runtime_run_command_exit_code(string command) int {
    args := string[]()
    args.push("/bin/sh")
    args.push("-c")
    args.push(command)
    return __host_run_argv(args)
}
func runtime_parse_int(string text, int fallback) int {
    if text == "" { return fallback }
    int sign = 1
    int i = 0
    if __host_byte_at(text, 0) == 45 {
        sign = -1
        i = 1
        if i >= len(text) { return fallback }
    }
    int value = 0
    for i < len(text) {
        int ch = __host_byte_at(text, i)
        if ch < 48 || ch > 57 { return fallback }
        value = value * 10 + ch - 48
        i = i + 1
    }
    value * sign
}

func runtime_shell_escape(string value) string {
    string out = "'"
    int i = 0
    for i < len(value) {
        string escaped_char = __host_char_at(value, i)
        if __host_byte_at(value, i) == 39 { out = out + "'\"'\"'" } else { out = out + escaped_char }
        i = i + 1
    }
    out + "'"
}
