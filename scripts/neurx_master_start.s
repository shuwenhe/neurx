package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_run_command_output, runtime_shell_escape}
use std.io.println
func main() {
    string master_host = runtime_env_get("MASTER_HOST", "112.29.145.3")
    string worker_host = runtime_env_get("WORKER_HOST", "root@112.29.145.15")
    string neurx_root = runtime_env_get("NEURX_ROOT", "/app/shuwen/neurx")
    string s_bin = runtime_env_get("S_BIN", runtime_run_command_output("command -v s 2>/dev/null || true"))
    string tmp_bin = runtime_env_get("TMP_BIN", "/tmp/neurx_train")
    string config = runtime_env_get("NEURX_PRETRAIN_CONFIG", "workflows/llm/pretrain/config/sample.yaml")
    string world_size = runtime_env_get("WORLD_SIZE", "2")
    string master_port = runtime_env_get("MASTER_PORT", "29500")
    println("[neurx-master] master=" + master_host + " worker=" + worker_host)
    if s_bin == "" {
        println("[ERROR] S compiler not found; set S_BIN or install s in PATH")
        return 1
    }
    println("[neurx-master] Syncing code to worker...")
    string rsync_cmd = "rsync -avz --delete " + runtime_shell_escape(neurx_root + "/") + " " + runtime_shell_escape(worker_host + ":" + neurx_root + "/")
    runtime_run_command(rsync_cmd)
    println("[neurx-master] Compiling pretrain entrypoint with s...")
    string compile_cmd = runtime_shell_escape(s_bin) + " " + runtime_shell_escape(neurx_root + "/workflows/llm/pretrain/run/run_with_config.s")
    if !runtime_run_command(compile_cmd).ok {
        println("[ERROR] failed to compile run_with_config.s")
        return 2
    }
    println("[neurx-master] Emitting binary...")
    string emit_cmd = runtime_shell_escape(s_bin) + " --emit-bin /tmp/neurx_llm_pretrain_run_tmp.ir " + runtime_shell_escape(tmp_bin)
    if !runtime_run_command(emit_cmd).ok {
        println("[ERROR] failed to emit binary")
        return 3
    }
    runtime_run_command("chmod +x " + runtime_shell_escape(tmp_bin))
    println("[neurx-master] Distributing binary to worker...")
    runtime_run_command("rsync -avz " + runtime_shell_escape(tmp_bin) + " " + runtime_shell_escape(worker_host + ":" + tmp_bin))
    println("[neurx-master] Starting worker on " + worker_host + " (rank=1)")
    string ssh_worker = "ssh -o StrictHostKeyChecking=no " + runtime_shell_escape(worker_host) + " 'export WORLD_SIZE=" + world_size + "; export RANK=1; export LOCAL_RANK=0; export MASTER_ADDR=" + master_host + "; export MASTER_PORT=" + master_port + "; export NEURX_PRETRAIN_CONFIG=" + runtime_shell_escape(config) + "; export NEURX_TRAIN_BIN=" + runtime_shell_escape(tmp_bin) + "; nohup " + runtime_shell_escape(tmp_bin) + " > ~/neurx_worker_train.log 2>&1 &'"
    runtime_run_command(ssh_worker)
    println("[neurx-master] Starting master locally (rank=0)")
    runtime_run_command("export WORLD_SIZE=" + world_size + "; export RANK=0; export LOCAL_RANK=0; export MASTER_ADDR=" + master_host + "; export MASTER_PORT=" + master_port + "; export NEURX_PRETRAIN_CONFIG=" + runtime_shell_escape(config) + "; export NEURX_TRAIN_BIN=" + runtime_shell_escape(tmp_bin) + "; nohup " + runtime_shell_escape(tmp_bin) + " > ~/neurx_master_train.log 2>&1 &")
    println("[neurx-master] Done. Logs: ~/neurx_master_train.log (master), ~/neurx_worker_train.log (worker remote)")
    0
}

