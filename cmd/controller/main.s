package main
import (
    "neurx.deployment.cluster_orchestration"
    "neurx.deployment.cluster_runtime_bridge"
    "neurx.deployment.hetero_runtime_bridge"
    "neurx.distributed.cluster.heartbeat"
    "neurx.runtime.command"
    "neurx.runtime.io"
)

func main() int {
    string cluster_name = neurx.runtime.command.runtime_env_get("NEURX_CLUSTER_NAME", "neurx-inference")
    string worker_host = neurx.runtime.command.runtime_env_get("NEURX_WORKER_HOST", "")
    string worker_bin = neurx.runtime.command.runtime_env_get("NEURX_REMOTE_WORKER_BIN", "")
    string master_addr_env = neurx.runtime.command.runtime_env_get("MASTER_ADDR", "")
    string enable_hetero_launch = neurx.runtime.command.runtime_env_get("NEURX_ENABLE_HETERO_LAUNCH", "0")
    string enable_relaunch = neurx.runtime.command.runtime_env_get("NEURX_ENABLE_RELAUNCH_EXECUTION", "0")
    string master_port_text = neurx.runtime.command.runtime_env_get("MASTER_PORT", "29500")
    string world_size_text = neurx.runtime.command.runtime_env_get("WORLD_SIZE", "")
    cluster_orchestration_state orch = new_cluster_orchestration_state(cluster_name, "./production_deployment", neurx.runtime.command.runtime_env_get("NEURX_BACKEND", "nccl"))
    orch = cluster_discover_nodes(orch)
    int world_size = runtime_parse_int(world_size_text, cluster_recommended_world_size(orch))
    int master_port = runtime_parse_int(master_port_text, 29500)
    println("[neurx-controller] discovery result:\n" + cluster_discovery_summary(orch))

    string master_addr = neurx.runtime.command.runtime_env_get("NEURX_MASTER_ADDR", master_addr_env)
    if master_addr == "" {
        if len(orch.nodes) > 0 && orch.nodes[0].ip_address != "" {
            master_addr = orch.nodes[0].ip_address
        } else {
            master_addr = neurx.runtime.command.runtime_env_get("HOSTNAME", "localhost")
        }
    }
    cluster_deployment_spec spec = new_cluster_deployment_spec(
        cluster_name,
        neurx.runtime.command.runtime_env_get("NEURX_IMAGE", "neurx:latest"),
        neurx.runtime.command.runtime_env_get("NEURX_BACKEND", "nccl"),
        master_addr,
        master_port,
        runtime_parse_int(neurx.runtime.command.runtime_env_get("NEURX_REPLICA_COUNT", cluster_int_to_string(len(orch.nodes))), len(orch.nodes)),
        world_size,
        neurx.runtime.command.runtime_env_get("NEURX_CHECKPOINT_DIR", "./artifact/checkpoints"),
        neurx.runtime.command.runtime_env_get("NEURX_DATA_DIR", "./dataset/pretrain"),
        neurx.runtime.command.runtime_env_get("NEURX_OUTPUT_DIR", "./artifact/train_output")
    )
    cluster_runtime_bridge_result probe = bridge_probe_runtime(orch)
    println("[neurx-controller] " + bridge_deployment_summary(orch, spec))
    if !probe.ready {
        println("[neurx-controller] placement failed")
        return 3
    }
    println("[neurx-controller] selected node=" + probe.selected_node_name + " backend=" + probe.selected_backend)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(cluster_name, neurx.runtime.command.runtime_env_get("NEURX_HEARTBEAT_DIR", "/tmp/neurx_cluster/heartbeat"))
    println("[neurx-controller] heartbeat=" + cluster_heartbeat_summary(heartbeat))
    if !cluster_heartbeat_is_live(heartbeat, 0) {
        println("[neurx-controller] heartbeat missing for rank 0")
    }
    if worker_host == "" || worker_bin == "" || master_addr == "" {
        println("[neurx-controller] dry control-plane pass complete; set NEURX_WORKER_HOST, NEURX_REMOTE_WORKER_BIN and MASTER_ADDR to launch workers")
        string dry_script = bridge_remote_execution_commands(orch, true)
        string dry_relaunch = bridge_fault_injection_relaunch_commands(orch)
        runtime_make_dirs("/tmp/neurx_cluster")
        runtime_write_text_file("/tmp/neurx_cluster/launch.sh", dry_script)
        runtime_write_text_file("/tmp/neurx_cluster/relaunch.sh", dry_relaunch)
        if enable_hetero_launch == "1" {
            runtime_write_text_file("/tmp/neurx_cluster/hetero_launch.sh", bridge_hetero_demo_script("neurx-worker", neurx.runtime.command.runtime_env_get("MASTER_ADDR", neurx.runtime.command.runtime_env_get("HOSTNAME", "localhost")), master_port))
        }
        println(dry_script)
        return 0
    }
    string command_script = bridge_remote_execution_commands(orch, true)
    string relaunch_script = bridge_fault_injection_relaunch_commands(orch)
    runtime_make_dirs("/tmp/neurx_cluster")
    runtime_write_text_file("/tmp/neurx_cluster/launch.sh", command_script)
    runtime_write_text_file("/tmp/neurx_cluster/relaunch.sh", relaunch_script)
    if enable_hetero_launch == "1" {
        runtime_write_text_file("/tmp/neurx_cluster/hetero_launch.sh", bridge_hetero_demo_script(worker_bin, master_addr, master_port))
        int hetero_exit_code = bridge_hetero_demo_execute(worker_bin, master_addr, master_port)
        if hetero_exit_code != 0 {
            println("[neurx-controller] hetero launch failed")
            return hetero_exit_code
        }
    }
    int exit_code = neurx.runtime.command.runtime_run_command_exit_code("sh /tmp/neurx_cluster/launch.sh")
    if exit_code != 0 {
        println("[neurx-controller] worker launch failed")
        return exit_code
    }
    if enable_relaunch == "1" {
        int relaunch_exit_code = bridge_fault_injection_relaunch_execute(orch)
        if relaunch_exit_code != 0 {
            println("[neurx-controller] worker relaunch failed")
            return relaunch_exit_code
        }
    }
    0
}
