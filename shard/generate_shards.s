package main
use std.os.{command, getenv}
func string_char(int c) string {
    string(c)
}

func shell_escape(string s) string {
    string out = "'"
    int i = 0
    while i < len(s) {
        string ch = string_char(s[i])
        if ch == "'" {
            out = out + "'\"'\"'"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out = out + "'"
    out
}

func main() {
    string neurx_root = getenv("NEURX_HOME", ".")
    let (_, code) = command("make -C " + shell_escape(neurx_root) + " shard")
    code
}
