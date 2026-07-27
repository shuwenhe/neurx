package main
use std.exec
use std.os
use std.path
func findSCompiler() string {
    realS := "/usr/local/bin/s"
    _, err := os.Stat(realS)
    if err == nil {
        return realS
    }
    path, err := exec.LookPath("s")
    if err == nil && path != "" {
        return path
    }
    return ""
}
func main() {
    realS := findSCompiler()
    if realS == "" {
        os.Stderr.WriteString("error: could not find an executable 's' compiler\n")
        os.Exit(1)
    }
    args := os.Args[1:]
    if len(args) > 0 && args[0] == "ir" {
        args = args[1:]
        if len(args) >= 2 && args[1] == "-o" {
            input := args[0]
            output := args[2]
            cmd := exec.Command(realS, input, output)
            cmd.Stdout = os.Stdout
            cmd.Stderr = os.Stderr
            cmd.Run()
            return
        }
        cmd := exec.Command(append([]string{realS, "ir"}, args...)...)
        cmd.Stdout = os.Stdout
        cmd.Stderr = os.Stderr
        cmd.Run()
        return
    }
    cmd := exec.Command(append([]string{realS}, args...)...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr
    cmd.Run()
}
