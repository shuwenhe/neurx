package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() {
    string project_root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/train/neurx")
    string neurx_dir = runtime_env_get("NEURX_DIR", project_root)
    string s_root = runtime_env_get("S_ROOT", "/app/train/s")
    string log_dir = runtime_env_get("LOG_DIR", "/tmp/neurx_train_logs")
    string rank_table = runtime_env_get("RANK_TABLE_FILE", neurx_dir + "/configs/rank_table_8card_310p3.json")
    string cmd = "mkdir -p " + runtime_shell_escape(log_dir) + " && RANK_TABLE_FILE=" + runtime_shell_escape(rank_table) + " WORLD_SIZE=8 NEURX_DIR=" + runtime_shell_escape(neurx_dir) + " S_ROOT=" + runtime_shell_escape(s_root) + " make -C " + runtime_shell_escape(neurx_dir) + " run-train-model-ir-s"
    if !runtime_run_command(cmd).ok {
        return 1
    }
    0
}
