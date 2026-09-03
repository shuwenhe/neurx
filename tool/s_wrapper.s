package main
use std.exec
use std.os
use std.path

func find_s_compiler() string {
    real_s := "/usr/local/bin/s"
    _, err := os.Stat(real_s)
    if err == nil {
        return real_s
    }
    path, err := exec.LookPath("s")
    if err == nil && path != "" {
        return path
    }
    return ""
}

func main() {
    real_s := find_s_compiler()
    if real_s == "" {
        os.Stderr.WriteString("error: could not find an executable 's' compiler\n")
        os.Exit(1)
    }
    args := os.Args[1:]
    if len(args) > 0 && args[0] == "ir" {
        args = args[1:]
        if len(args) >= 2 && args[1] == "-o" {
            input := args[0]
            output := args[2]
            cmd := exec.command(real_s, input, output)
            cmd.Stdout = os.Stdout
            cmd.Stderr = os.Stderr
            cmd.Run()
            return
        }
        cmd := exec.command(append([]string{real_s, "ir"}, args...)...)
        cmd.Stdout = os.Stdout
        cmd.Stderr = os.Stderr
        cmd.Run()
        return
    }
    cmd := exec.command(append([]string{real_s}, args...)...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Run()
}
