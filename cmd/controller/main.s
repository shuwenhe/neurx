package main
use std.conv.parse_int_default as parse_int
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}

func main() {
    string apply = runtime_env_get("NEURX_CONTROLLER_APPLY", "0")
    string worker_host = runtime_env_get("NEURX_WORKER_HOST", "")
    string worker_bin = runtime_env_get("NEURX_REMOTE_WORKER_BIN", "")
    string known_hosts = runtime_env_get("NEURX_SSH_KNOWN_HOSTS", "")
    string master_addr = runtime_env_get("MASTER_ADDR", "")
    string master_port = runtime_env_get("MASTER_PORT", "29500")
    string world_size_text = runtime_env_get("WORLD_SIZE", "2")
    string worker_rank_text = runtime_env_get("NEURX_WORKER_RANK", "1")
    int world_size = parse_int(world_size_text, 0)
    int worker_rank = parse_int(worker_rank_text, -1)
    if worker_host == "" || worker_bin == "" || known_hosts == "" || master_addr == "" {
        println("[neurx-controller] worker host, remote binary, known_hosts, and master address are required")
        return 2
    }
    if world_size <= 1 || worker_rank <= 0 || worker_rank >= world_size {
        println("[neurx-controller] invalid WORLD_SIZE or NEURX_WORKER_RANK")
        return 2
    }
    println("[neurx-controller] worker=" + worker_host + " rank=" + worker_rank_text + " master=" + master_addr + ":" + master_port)
    if apply != "1" {
        println("[neurx-controller] dry-run complete; set NEURX_CONTROLLER_APPLY=1 to launch")
        return 0
    }
    string remote_command = "WORLD_SIZE=" + runtime_shell_escape(world_size_text)
        + " RANK=" + runtime_shell_escape(worker_rank_text)
        + " LOCAL_RANK='0' MASTER_ADDR=" + runtime_shell_escape(master_addr)
        + " MASTER_PORT=" + runtime_shell_escape(master_port)
        + " exec " + runtime_shell_escape(worker_bin)
    string command = "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="
        + runtime_shell_escape(known_hosts) + " -- " + runtime_shell_escape(worker_host)
        + " " + runtime_shell_escape(remote_command)
    var result = runtime_run_command(command)
    if !result.ok {
        println("[neurx-controller] remote launch failed: " + result.error)
        return result.exit_code
    }
    0
}
