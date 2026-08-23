package main
use neurx.runtime.command.{runtime_env_get, runtime_parse_int, runtime_run_command_exit_code, runtime_shell_escape}

func main() {
    string worker_bin = runtime_env_get("NEURX_WORKER_BIN", "")
    string master_addr = runtime_env_get("MASTER_ADDR", "")
    string master_port = runtime_env_get("MASTER_PORT", "29500")
    string world_size_text = runtime_env_get("WORLD_SIZE", "")
    string rank_text = runtime_env_get("RANK", "")
    string local_rank_text = runtime_env_get("LOCAL_RANK", "0")
    int world_size = runtime_parse_int(world_size_text, 0)
    int rank = runtime_parse_int(rank_text, -1)
    int local_rank = runtime_parse_int(local_rank_text, -1)
    if worker_bin == "" || master_addr == "" || world_size <= 0 || rank < 0 || rank >= world_size || local_rank < 0 {
        println("[neurx-worker] NEURX_WORKER_BIN, MASTER_ADDR, WORLD_SIZE, RANK, and LOCAL_RANK must be valid")
        return 2
    }
    if runtime_run_command_exit_code("test -x " + runtime_shell_escape(worker_bin)) != 0 {
        println("[neurx-worker] worker binary is not executable: " + worker_bin)
        return 3
    }
    println("[neurx-worker] rank=" + rank_text + " local_rank=" + local_rank_text + " master=" + master_addr + ":" + master_port)
    string command = "WORLD_SIZE=" + runtime_shell_escape(world_size_text)
        + " RANK=" + runtime_shell_escape(rank_text)
        + " LOCAL_RANK=" + runtime_shell_escape(local_rank_text)
        + " MASTER_ADDR=" + runtime_shell_escape(master_addr)
        + " MASTER_PORT=" + runtime_shell_escape(master_port)
        + " exec " + runtime_shell_escape(worker_bin)
    int exit_code = runtime_run_command_exit_code(command)
    if exit_code != 0 {
        println("[neurx-worker] execution failed")
        return exit_code
    }
    0
}
