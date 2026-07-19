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

    string cmd = "mkdir -p " + runtime_shell_escape(out_dir) + " && cd " + runtime_shell_escape(project_root) + " && python3 tools/stack_streamer.py --dataset " + runtime_shell_escape(dataset) + " --lang " + runtime_shell_escape(lang) + " --licenses " + runtime_shell_escape(licenses) + " --shard-size " + runtime_shell_escape(shard_size) + " --out-dir " + runtime_shell_escape(out_dir) + " --max-files 0 --progress && command -v coscmd >/dev/null 2>&1 && coscmd upload -r " + runtime_shell_escape(out_dir + "/") + " " + runtime_shell_escape(bucket)
    if !runtime_run_command(cmd).ok {
        return 1
    }

    0
}
