package neurx.deployment.cluster_runtime_bridge

use neurx.deployment.cluster_orchestration.{cluster_orchestration_state, cluster_deployment_spec, cluster_recommended_world_size, cluster_state_summary}
use neurx.distributed.cluster.{cluster_runtime_state, create_cluster_runtime, cluster_default_cuda_capability, cluster_default_rocm_capability, cluster_default_npu_capability, cluster_default_cpu_capability, cluster_register_node, cluster_select_node, cluster_workload_request, cluster_mark_node_failed, cluster_summary, cluster_failed_node_count}
use neurx.distributed.cluster.parallel_plan.{cluster_parallel_request, cluster_parallel_plan, cluster_parallel_plan_for, cluster_parallel_plan_summary, cluster_parallel_plan_ready, cluster_parallel_assign_to_nodes, cluster_parallel_assignment_summary, cluster_parallel_build_launch_plan, cluster_parallel_launch_plan, cluster_parallel_launch_summary, cluster_parallel_group_launch_plan, cluster_parallel_grouped_launch_plan, cluster_parallel_grouped_launch_summary, cluster_parallel_execute_launch_plan, cluster_parallel_execution_batch, cluster_parallel_execution_summary, cluster_parallel_build_execution_script, cluster_parallel_execution_script, cluster_parallel_execution_script_summary, cluster_parallel_filter_launch_plan, cluster_parallel_rank_filter_summary}
use neurx.distributed.cluster.heartbeat.{create_cluster_heartbeat_state, cluster_heartbeat_scan, cluster_heartbeat_scan_summary}
use neurx.runtime.command.{runtime_env_get, runtime_run_command_exit_code, runtime_shell_escape}

struct cluster_runtime_bridge_result {
    cluster_runtime_state runtime
    string summary
    bool ready
    int selected_node_id
    string selected_node_name
    string selected_backend
    cluster_parallel_plan parallel_plan
    string assignment_summary
    cluster_parallel_launch_plan launch_plan
    string launch_summary
    cluster_parallel_grouped_launch_plan grouped_launch_plan
    string grouped_launch_summary
    cluster_parallel_execution_batch execution_batch
    string execution_summary
    cluster_parallel_execution_script execution_script
    string execution_script_summary
    string heartbeat_summary
    string recovery_summary
}

struct cluster_fault_injection_result {
    cluster_heartbeat_scan_result heartbeat_scan
    cluster_parallel_rank_filter_result filter_meta
    cluster_parallel_launch_plan relaunch_plan
    cluster_parallel_execution_batch relaunch_execution_batch
    cluster_parallel_execution_script relaunch_execution_script
    string recovery_summary
    string scan_summary
}

func bridge_seed_runtime(cluster_orchestration_state state) cluster_runtime_state {
    cluster_runtime_state runtime = create_cluster_runtime(state.cluster_name, cluster_recommended_world_size(state))
    int i = 0
    for i < len(state.nodes) {
        if state.nodes[i].status == "failed" {
            i = i + 1
            continue
        }
        if state.nodes[i].gpu_type == "MI300" || state.nodes[i].gpu_type == "ROCM" {
            runtime = cluster_register_node(runtime, state.nodes[i].node_name, state.nodes[i].ip_address, 9000 + i, i, 0, cluster_default_rocm_capability(state.nodes[i].gpu_count, state.nodes[i].memory_gb))
        } else if state.nodes[i].gpu_type == "ASCEND" || state.nodes[i].gpu_type == "NPU" {
            runtime = cluster_register_node(runtime, state.nodes[i].node_name, state.nodes[i].ip_address, 9000 + i, i, 0, cluster_default_npu_capability(state.nodes[i].gpu_count, state.nodes[i].memory_gb))
        } else if state.nodes[i].gpu_type == "CPU" {
            runtime = cluster_register_node(runtime, state.nodes[i].node_name, state.nodes[i].ip_address, 9000 + i, i, 0, cluster_default_cpu_capability(state.nodes[i].memory_gb))
        } else {
            runtime = cluster_register_node(runtime, state.nodes[i].node_name, state.nodes[i].ip_address, 9000 + i, i, 0, cluster_default_cuda_capability(state.nodes[i].gpu_count, state.nodes[i].memory_gb))
        }
        i = i + 1
    }
    runtime
}

func bridge_ssh_host(string host) string {
    string ssh_user = runtime_env_get("NEURX_SSH_USER", "")
    if ssh_user == "" || host == "" {
        return host
    }
    if cluster_find_substring(host, "@") >= 0 {
        return host
    }
    ssh_user + "@" + host
}

func bridge_probe_runtime(cluster_orchestration_state state) cluster_runtime_bridge_result {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-probe",
        model_id: "neurx-probe",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: false,
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-probe",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: false,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{cap: len(state.nodes)}
    string[] node_names = string[]{cap: len(state.nodes)}
    string[] node_hosts = string[]{cap: len(state.nodes)}
    int j = 0
    for j < len(state.nodes) {
        node_ids = append(node_ids, state.nodes[j].node_id)
        node_names = append(node_names, state.nodes[j].node_name)
        node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[j].ip_address))
        j = j + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    cluster_parallel_grouped_launch_plan grouped_launch = cluster_parallel_group_launch_plan(launch_plan)
    cluster_parallel_execution_batch execution_batch = cluster_parallel_execute_launch_plan(launch_plan)
    cluster_parallel_execution_script execution_script = cluster_parallel_build_execution_script(execution_batch, true)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(state.cluster_name, "/tmp/neurx_cluster/heartbeat")
    cluster_heartbeat_scan_result heartbeat_scan = cluster_heartbeat_scan(heartbeat, plan.topology.world_size)
    cluster_parallel_rank_filter_result filter_meta
    filter_meta = cluster_parallel_filter_launch_plan(launch_plan, heartbeat_scan.failed_rank_ids)
    cluster_parallel_launch_plan filtered_launch = filter_meta.plan
    cluster_parallel_grouped_launch_plan filtered_grouped = cluster_parallel_group_launch_plan(filtered_launch)
    cluster_parallel_execution_batch filtered_execution = cluster_parallel_execute_launch_plan(filtered_launch)
    cluster_parallel_execution_script filtered_script = cluster_parallel_build_execution_script(filtered_execution, true)
    cluster_runtime_bridge_result {
        runtime: runtime,
        summary: cluster_summary(runtime),
        ready: placement.scheduled,
        selected_node_id: placement.node_id,
        selected_node_name: placement.node_name,
        selected_backend: placement.backend,
        parallel_plan: plan,
        assignment_summary: cluster_parallel_assignment_summary(assignment),
        launch_plan: launch_plan,
        launch_summary: cluster_parallel_launch_summary(launch_plan),
        grouped_launch_plan: grouped_launch,
        grouped_launch_summary: cluster_parallel_grouped_launch_summary(grouped_launch),
        execution_batch: execution_batch,
        execution_summary: cluster_parallel_execution_summary(execution_batch),
        execution_script: execution_script,
        execution_script_summary: cluster_parallel_execution_script_summary(execution_script),
        heartbeat_summary: cluster_heartbeat_scan_summary(heartbeat_scan),
        recovery_summary: cluster_parallel_rank_filter_summary(filter_meta) + cluster_parallel_launch_summary(filtered_launch) + cluster_parallel_grouped_launch_summary(filtered_grouped) + cluster_parallel_execution_summary(filtered_execution) + cluster_parallel_execution_script_summary(filtered_script)
    }
}

func bridge_deployment_summary(cluster_orchestration_state state, cluster_deployment_spec spec) string {
    cluster_state_summary(state, spec) + "\n" + cluster_summary(bridge_seed_runtime(state))
}

func bridge_parallel_plan_summary(cluster_orchestration_state state) string {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-plan",
        model_id: "neurx-plan",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-plan",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    cluster_parallel_plan_summary(plan)
}

func bridge_launch_plan(cluster_orchestration_state state) string {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-launch",
        model_id: "neurx-launch",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-launch",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{}
    string[] node_names = string[]{}
    string[] node_hosts = string[]{}
    int i = 0
    for i < len(state.nodes) {
        node_ids = append(node_ids, state.nodes[i].node_id)
        node_names = append(node_names, state.nodes[i].node_name)
        node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[i].ip_address))
        i = i + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    cluster_parallel_grouped_launch_plan grouped_launch = cluster_parallel_group_launch_plan(launch_plan)
    cluster_parallel_execution_batch execution_batch = cluster_parallel_execute_launch_plan(launch_plan)
    string out = ""
    out = out + "[bridge-launch] backend=" + placement.backend + "\n"
    out = out + cluster_parallel_launch_summary(launch_plan)
    out = out + cluster_parallel_grouped_launch_summary(grouped_launch)
    out = out + cluster_parallel_execution_summary(execution_batch)
    out
}

func bridge_execute_launch_plan(cluster_orchestration_state state) string {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-execute",
        model_id: "neurx-execute",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-execute",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{}
    string[] node_names = string[]{}
    string[] node_hosts = string[]{}
    int i = 0
    for i < len(state.nodes) {
        node_ids = append(node_ids, state.nodes[i].node_id)
        node_names = append(node_names, state.nodes[i].node_name)
        node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[i].ip_address))
        i = i + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    cluster_parallel_grouped_launch_plan grouped_launch = cluster_parallel_group_launch_plan(launch_plan)
    cluster_parallel_execution_batch execution_batch = cluster_parallel_execute_launch_plan(launch_plan)
    cluster_parallel_execution_script execution_script = cluster_parallel_build_execution_script(execution_batch, true)
    string out = ""
    out = out + "[bridge-execute] backend=" + placement.backend + "\n"
    out = out + cluster_parallel_launch_summary(launch_plan)
    out = out + cluster_parallel_grouped_launch_summary(grouped_launch)
    out = out + cluster_parallel_execution_summary(execution_batch)
    out = out + cluster_parallel_execution_script_summary(execution_script)
    out
}

func bridge_remote_execution_commands(cluster_orchestration_state state, bool use_ssh) string {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-remote",
        model_id: "neurx-remote",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-remote",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{}
    string[] node_names = string[]{}
    string[] node_hosts = string[]{}
    int i = 0
    for i < len(state.nodes) {
        node_ids = append(node_ids, state.nodes[i].node_id)
        node_names = append(node_names, state.nodes[i].node_name)
        node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[i].ip_address))
        i = i + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    cluster_parallel_execution_batch execution_batch = cluster_parallel_execute_launch_plan(launch_plan)
    cluster_parallel_execution_script script = cluster_parallel_build_execution_script(execution_batch, use_ssh)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(state.cluster_name, "/tmp/neurx_cluster/heartbeat")
    cluster_heartbeat_scan_result heartbeat_scan = cluster_heartbeat_scan(heartbeat, plan.topology.world_size)
    string out = ""
    out = out + "[bridge-remote] backend=" + placement.backend + "\n"
    out = out + cluster_parallel_execution_script_summary(script)
    out = out + cluster_heartbeat_scan_summary(heartbeat_scan)
    out = out + script.script
    out
}

func bridge_recover_failed_nodes(cluster_orchestration_state state) string {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(state.cluster_name, "/tmp/neurx_cluster/heartbeat")
    cluster_heartbeat_scan_result scan = cluster_heartbeat_scan(heartbeat, cluster_recommended_world_size(state))
    int i = 0
    for i < len(scan.failed_rank_ids) {
        runtime = cluster_mark_node_failed(runtime, scan.failed_rank_ids[i] + 1)
        i = i + 1
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-recover",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-recover",
        model_id: "neurx-recover",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{}
    string[] node_names = string[]{}
    string[] node_hosts = string[]{}
    int j = 0
    for j < len(state.nodes) {
        if state.nodes[j].healthy {
            node_ids = append(node_ids, state.nodes[j].node_id)
            node_names = append(node_names, state.nodes[j].node_name)
            node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[j].ip_address))
        }
        j = j + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    string out = ""
    out = out + "[bridge-recovery] " + cluster_heartbeat_scan_summary(scan)
    out = out + cluster_summary(runtime)
    cluster_parallel_rank_filter_result filter_meta = cluster_parallel_filter_launch_plan(launch_plan, scan.failed_rank_ids)
    out = out + cluster_parallel_rank_filter_summary(filter_meta)
    out
}

func bridge_fault_injection_recovery(cluster_orchestration_state state) cluster_fault_injection_result {
    cluster_runtime_state runtime = bridge_seed_runtime(state)
    cluster_heartbeat_state heartbeat = create_cluster_heartbeat_state(state.cluster_name, "/tmp/neurx_cluster/heartbeat")
    cluster_heartbeat_scan_result scan = cluster_heartbeat_scan(heartbeat, cluster_recommended_world_size(state))
    int i = 0
    for i < len(scan.failed_rank_ids) {
        runtime = cluster_mark_node_failed(runtime, scan.failed_rank_ids[i] + 1)
        i = i + 1
    }
    cluster_parallel_request parallel_request = cluster_parallel_request {
        model_id: "neurx-fault-injection",
        num_layers: 80,
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_workload_request request = cluster_workload_request {
        workload_id: "bridge-fault-injection",
        model_id: "neurx-fault-injection",
        min_device_count: 1,
        min_memory_gb: 1,
        require_graph_capture: false,
        require_speculative_decode: false,
        require_fp8: false,
        require_distributed: true,
    }
    cluster_placement_result placement = cluster_select_node(runtime, request)
    cluster_parallel_plan plan = cluster_parallel_plan_for(parallel_request, 8, 1, 1, cluster_recommended_world_size(state), placement.backend)
    int[] node_ids = int[]{}
    string[] node_names = string[]{}
    string[] node_hosts = string[]{}
    int j = 0
    for j < len(state.nodes) {
        if state.nodes[j].healthy {
            node_ids = append(node_ids, state.nodes[j].node_id)
            node_names = append(node_names, state.nodes[j].node_name)
            node_hosts = append(node_hosts, bridge_ssh_host(state.nodes[j].ip_address))
        }
        j = j + 1
    }
    cluster_parallel_assignment_plan assignment = cluster_parallel_assign_to_nodes(plan, node_ids, node_names, node_hosts)
    cluster_parallel_launch_plan launch_plan = cluster_parallel_build_launch_plan(assignment, "neurx-worker", "127.0.0.1", 29500, plan.topology.world_size)
    cluster_parallel_rank_filter_result filter_meta = cluster_parallel_filter_launch_plan(launch_plan, scan.failed_rank_ids)
    cluster_parallel_launch_plan filtered_launch = filter_meta.plan
    cluster_parallel_execution_batch filtered_execution = cluster_parallel_execute_launch_plan(filtered_launch)
    cluster_parallel_execution_script filtered_script = cluster_parallel_build_execution_script(filtered_execution, true)
    cluster_fault_injection_result {
        heartbeat_scan: scan,
        filter_meta: filter_meta,
        relaunch_plan: filtered_launch,
        relaunch_execution_batch: filtered_execution,
        relaunch_execution_script: filtered_script,
        recovery_summary: cluster_heartbeat_scan_summary(scan) + cluster_parallel_rank_filter_summary(filter_meta) + cluster_parallel_launch_summary(filtered_launch) + cluster_parallel_execution_summary(filtered_execution) + cluster_parallel_execution_script_summary(filtered_script),
        scan_summary: cluster_heartbeat_scan_summary(scan)
    }
}

func bridge_fault_injection_relaunch_commands(cluster_orchestration_state state) string {
    cluster_fault_injection_result result = bridge_fault_injection_recovery(state)
    result.relaunch_execution_script.script
}

func bridge_fault_injection_relaunch_execute(cluster_orchestration_state state) int {
    cluster_fault_injection_result result = bridge_fault_injection_recovery(state)
    string script_path = "/tmp/neurx_cluster/relaunch.sh"
    string command = "sh " + runtime_shell_escape(script_path)
    runtime_run_command_exit_code(command)
}

func bridge_fault_injection_worker_relaunch_commands(cluster_orchestration_state state) string {
    cluster_fault_injection_result result = bridge_fault_injection_recovery(state)
    result.relaunch_execution_script.script
}
