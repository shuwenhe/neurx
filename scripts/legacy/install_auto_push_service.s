package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string service_src = project_root + "/systemd/neurx-auto-push.service"
    string service_dst = "/etc/systemd/system/neurx-auto-push.service"
    string cmd = "cp " + runtime_shell_escape(service_src) + " " + runtime_shell_escape(service_dst) + " && systemctl daemon-reload && systemctl enable --now neurx-auto-push.service && systemctl status neurx-auto-push.service --no-pager"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
