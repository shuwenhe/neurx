package neurx.runtime.command

extern "intrinsic" func runtime_env_get(string name, string default_value) string
extern "intrinsic" func runtime_run_command_exit_code(string command) int

func runtime_parse_int(string text, int fallback) int {
    if text == "" { return fallback }
    int sign = 1
    int i = 0
    if int(text[0]) == 45 {
        sign = -1
        i = 1
        if i >= len(text) { return fallback }
    }
    int value = 0
    for i < len(text) {
        int ch = int(text[i])
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
        string ch = string(value[i])
        if int(ch) == 39 { out = out + "'\"'\"'" } else { out = out + ch }
        i = i + 1
    }
    out + "'"
}
