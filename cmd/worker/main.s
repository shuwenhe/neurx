package main
import (
    "neurx.deployment.cluster_orchestration"
    "neurx.deployment.cluster_runtime_bridge"
    "neurx.distributed.cluster.heartbeat"
    "neurx.runtime.command"
    "neurx.runtime.io"
)

func main() int {
    string cluster_name = neurx.runtime.command.runtime_env_get("NEURX_CLUSTER_NAME", "neurx-inference")
    string worker_bin = neurx.runtime.command.runtime_env_get("NEURX_WORKER_BIN", "")
    string master_addr = neurx.runtime.command.runtime_env_get("MASTER_ADDR", "")
    string master_port = neurx.runtime.command.runtime_env_get("MASTER_PORT", "29500")
    string world_size_text = neurx.runtime.command.runtime_env_get("WORLD_SIZE", "")
    string rank_text = neurx.runtime.command.runtime_env_get("RANK", "")
    string local_rank_text = neurx.runtime.command.runtime_env_get("LOCAL_RANK", "0")
    string node_name = neurx.runtime.command.runtime_env_get("NEURX_NODE_NAME", neurx.runtime.command.runtime_env_get("HOSTNAME", "worker"))
    string node_host = neurx.runtime.command.runtime_env_get("NEURX_NODE_HOST", neurx.runtime.command.runtime_env_get("HOSTNAME", "localhost"))
    string enable_relaunch = neurx.runtime.command.runtime_env_get("NEURX_ENABLE_RELAUNCH_EXECUTION", "0")
    int node_port = runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_NODE_PORT", master_port), runtime_parse_int(master_port, 29500))
    int world_size = runtime_parse_int(world_size_text, 0)
    int rank = runtime_parse_int(rank_text, -1)
    int local_rank = runtime_parse_int(local_rank_text, -1)
    if worker_bin == "" || master_addr == "" || world_size <= 0 || rank < 0 || rank >= world_size || local_rank < 0 {
        println("[neurx-worker] NEURX_WORKER_BIN, MASTER_ADDR, WORLD_SIZE, RANK, and LOCAL_RANK must be valid")
        return 2
    }
    cluster_orchestration_state orch = new_demo_cluster_state()
    cluster_deployment_spec spec = new_cluster_deployment_spec(
        cluster_name,
        neurx.runtime.command.runtime_env_get("NEURX_IMAGE", "neurx:latest"),
        neurx.runtime.command.runtime_env_get("NEURX_BACKEND", "nccl"),
        master_addr,
        runtime_parse_int(master_port, 29500),
        runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_REPLICA_COUNT", "4"), 4),
        world_size,
        neurx.runtime.command.runtime_env_get("NEURX_CHECKPOINT_DIR", "./artifact/checkpoints"),
        neurx.runtime.command.runtime_env_get("NEURX_DATA_DIR", "./dataset/pretrain"),
        neurx.runtime.command.runtime_env_get("NEURX_OUTPUT_DIR", "./artifact/train_output")
    )
    cluster_runtime_bridge_result probe = bridge_probe_runtime(orch)
    println("[neurx-worker] " + bridge_deployment_summary(orch, spec))
    if !probe.ready {
        println("[neurx-worker] runtime bridge placement failed")
        return 4
    }
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(cluster_name, neurx.runtime.command.runtime_env_get("NEURX_HEARTBEAT_DIR", "/tmp/neurx_cluster/heartbeat"))
    runtime_make_dirs(neurx.runtime.command.runtime_env_get("NEURX_HEARTBEAT_DIR", "/tmp/neurx_cluster/heartbeat"))
    heartbeat = cluster_heartbeat_write(heartbeat, runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_NODE_ID", "1"), 1), node_name, node_host, rank, local_rank, 1000, true, "ready")
    if enable_relaunch == "1" {
        heartbeat = cluster_heartbeat_write(heartbeat, runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_NODE_ID", "1"), 1), node_name, node_host, rank, local_rank, 1001, true, "relaunching")
        heartbeat = cluster_heartbeat_write(heartbeat, runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_NODE_ID", "1"), 1), node_name, node_host, rank, local_rank, 1002, true, "ready")
    }
    println("[neurx-worker] heartbeat=" + cluster_heartbeat_summary(heartbeat))
    if neurx.runtime.command.runtime_run_command_exit_code("test -x " + neurx.runtime.command.runtime_shell_escape(worker_bin)) != 0 {
        println("[neurx-worker] worker binary is not executable: " + worker_bin)
        return 3
    }
    println("[neurx-worker] rank=" + rank_text + " local_rank=" + local_rank_text + " master=" + master_addr + ":" + master_port)
    string command = "WORLD_SIZE=" + neurx.runtime.command.runtime_shell_escape(world_size_text)
        + " RANK=" + neurx.runtime.command.runtime_shell_escape(rank_text)
        + " LOCAL_RANK=" + neurx.runtime.command.runtime_shell_escape(local_rank_text)
        + " MASTER_ADDR=" + neurx.runtime.command.runtime_shell_escape(master_addr)
        + " MASTER_PORT=" + neurx.runtime.command.runtime_shell_escape(master_port)
        + " exec " + neurx.runtime.command.runtime_shell_escape(worker_bin)
    int exit_code = neurx.runtime.command.runtime_run_command_exit_code(command)
    if exit_code != 0 {
        println("[neurx-worker] execution failed")
        return exit_code
    }
    0
}
