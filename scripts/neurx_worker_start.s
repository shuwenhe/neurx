package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println

func main() {
    string tmp_bin = runtime_env_get("TMP_BIN", "/tmp/neurx_train")
    string world_size = runtime_env_get("WORLD_SIZE", "2")
    string rank = runtime_env_get("RANK", "1")
    string local_rank = runtime_env_get("LOCAL_RANK", "0")
    string master_addr = runtime_env_get("MASTER_ADDR", "112.29.145.3")
    string master_port = runtime_env_get("MASTER_PORT", "29500")
    string config = runtime_env_get("NEURX_PRETRAIN_CONFIG", "workflows/llm/pretrain/config/sample.yaml")
    println("[neurx-worker] Starting as rank=" + rank + " local_rank=" + local_rank + " master=" + master_addr + ":" + master_port)
    if !runtime_run_command("test -x " + runtime_shell_escape(tmp_bin)).ok {
        println("[ERROR] Training binary not found or not executable: " + tmp_bin)
        return 2
    }
    string cmd = "export WORLD_SIZE=" + world_size + "; export RANK=" + rank + "; export LOCAL_RANK=" + local_rank + "; export MASTER_ADDR=" + master_addr + "; export MASTER_PORT=" + master_port + "; export NEURX_PRETRAIN_CONFIG=" + runtime_shell_escape(config) + "; export NEURX_TRAIN_BIN=" + runtime_shell_escape(tmp_bin) + "; " + runtime_shell_escape(tmp_bin) + " 2>&1 | tee ~/neurx_worker_train.log"
    runtime_run_command(cmd)
    0
}
