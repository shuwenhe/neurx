package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() int {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string out_dir = runtime_env_get("OUT_DIR", "/data/the-stack-py")
    string bucket = runtime_env_get("COS_BUCKET", "")
    string shard_size = runtime_env_get("SHARD_SIZE", "1000")
    string dataset = runtime_env_get("DATASET", "bigcode/the-stack-dedup")
    string lang = runtime_env_get("LANG", "py")
    string licenses = runtime_env_get("LICENSES", "MIT Apache-2.0 BSD-3-Clause")
    if bucket == "" {
        return 1
    }
    string cmd = "echo 'stack_streamer.py removed; use the S data pipeline instead' && exit 1"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
