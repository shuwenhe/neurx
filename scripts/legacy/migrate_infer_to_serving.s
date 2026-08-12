package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string infer_dir = project_root + "/infer"
    string serving_dir = project_root + "/serving"
    string cmd = "cd " + runtime_shell_escape(project_root) + " && test -d infer && mkdir -p serving && find infer -type f -name \"*.s\" | sort | while read -r src; do rel=\"${src#infer/}\"; dst=\"serving/$rel\"; mkdir -p \"$(dirname \"$dst\")\"; if [ ! -f \"$dst\" ]; then cp \"$src\" \"$dst\"; fi; done"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}

