package main
use neurx.runtime.command.{runtime_env_get, runtime_parse_int, runtime_run_command_exit_code, runtime_shell_escape}
use neurx.runtime.io.{runtime_make_dirs, runtime_write_text_file}
use neurx.deployment.cluster_orchestration.{cluster_orchestration_state, new_demo_cluster_state, new_cluster_deployment_spec}
use neurx.deployment.cluster_runtime_bridge.{cluster_runtime_bridge_result, bridge_probe_runtime, bridge_deployment_summary, bridge_remote_execution_commands}
use neurx.distributed.cluster.heartbeat.{create_cluster_heartbeat_state, cluster_heartbeat_is_live, cluster_heartbeat_summary}

func main() {
    string cluster_name = runtime_env_get("NEURX_CLUSTER_NAME", "neurx-inference")
    string worker_host = runtime_env_get("NEURX_WORKER_HOST", "")
    string worker_bin = runtime_env_get("NEURX_REMOTE_WORKER_BIN", "")
    string master_addr = runtime_env_get("MASTER_ADDR", "")
    string master_port_text = runtime_env_get("MASTER_PORT", "29500")
    string world_size_text = runtime_env_get("WORLD_SIZE", "1")
    int world_size = runtime_parse_int(world_size_text, 1)
    int master_port = runtime_parse_int(master_port_text, 29500)

    cluster_orchestration_state orch = new_demo_cluster_state()
    cluster_deployment_spec spec = new_cluster_deployment_spec(
        cluster_name,
        runtime_env_get("NEURX_IMAGE", "neurx:latest"),
        runtime_env_get("NEURX_BACKEND", "nccl"),
        runtime_env_get("MASTER_ADDR", runtime_env_get("HOSTNAME", "localhost")),
        master_port,
        runtime_parse_int(runtime_env_get("NEURX_REPLICA_COUNT", "4"), 4),
        world_size,
        runtime_env_get("NEURX_CHECKPOINT_DIR", "./artifact/checkpoints"),
        runtime_env_get("NEURX_DATA_DIR", "./dataset/pretrain"),
        runtime_env_get("NEURX_OUTPUT_DIR", "./artifact/train_output")
    )
    cluster_runtime_bridge_result probe = bridge_probe_runtime(orch)
    println("[neurx-controller] " + bridge_deployment_summary(orch, spec))
    if !probe.ready {
        println("[neurx-controller] placement failed")
        return 3
    }
    println("[neurx-controller] selected node=" + probe.selected_node_name + " backend=" + probe.selected_backend)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(cluster_name, runtime_env_get("NEURX_HEARTBEAT_DIR", "/tmp/neurx_cluster/heartbeat"))
    println("[neurx-controller] heartbeat=" + cluster_heartbeat_summary(heartbeat))
    if !cluster_heartbeat_is_live(heartbeat, 0) {
        println("[neurx-controller] heartbeat missing for rank 0")
    }
    if worker_host == "" || worker_bin == "" || master_addr == "" {
        println("[neurx-controller] dry control-plane pass complete; set NEURX_WORKER_HOST, NEURX_REMOTE_WORKER_BIN and MASTER_ADDR to launch workers")
        string dry_script = bridge_remote_execution_commands(orch, true)
        runtime_make_dirs("/tmp/neurx_cluster")
        runtime_write_text_file("/tmp/neurx_cluster/launch.sh", dry_script)
        println(dry_script)
        return 0
    }
    string command_script = bridge_remote_execution_commands(orch, true)
    runtime_make_dirs("/tmp/neurx_cluster")
    runtime_write_text_file("/tmp/neurx_cluster/launch.sh", command_script)
    int exit_code = runtime_run_command_exit_code("sh /tmp/neurx_cluster/launch.sh")
    if exit_code != 0 {
        println("[neurx-controller] worker launch failed")
        return exit_code
    }
    0
}
