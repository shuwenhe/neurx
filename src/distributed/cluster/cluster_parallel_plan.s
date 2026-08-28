package neurx.distributed.cluster.parallel_plan
struct cluster_parallel_topology {
    int tensor_parallel_size
    int pipeline_parallel_size
    int data_parallel_size
    int world_size
}

struct cluster_parallel_rank {
    int global_rank
    int tensor_rank
    int pipeline_rank
    int data_rank
}

struct cluster_parallel_stage {
    int stage_id
    int start_layer
    int end_layer
    int replica_count
}

struct cluster_parallel_request {
    string model_id
    int num_layers
    int min_device_count
    int min_memory_gb
    bool require_graph_capture
    bool require_speculative_decode
    bool require_fp8
    bool require_distributed
}

struct cluster_parallel_plan {
    cluster_parallel_topology topology
    cluster_parallel_stage[] stages
    cluster_parallel_rank[] ranks
    bool valid
    string backend
    string reason
}

struct cluster_parallel_node_assignment {
    int node_id
    string node_name
    string host
    int global_rank
    int tensor_rank
    int pipeline_rank
    int data_rank
    int stage_id
    int replica_id
}

struct cluster_parallel_assignment_plan {
    cluster_parallel_node_assignment[] assignments
    bool valid
    string reason
}

struct cluster_parallel_launch_command {
    int node_id
    string node_name
    string host
    int global_rank
    string command
}

struct cluster_parallel_launch_plan {
    cluster_parallel_launch_command[] commands
    bool valid
    string reason
}

struct cluster_parallel_host_bundle {
    string host
    string node_name
    int command_count
}

struct cluster_parallel_grouped_launch_plan {
    cluster_parallel_host_bundle[] bundles
    bool valid
    string reason
}

struct cluster_parallel_execution_line {
    string host
    string node_name
    int global_rank
    string command
}

struct cluster_parallel_execution_batch {
    cluster_parallel_execution_line[] lines
    bool valid
    string reason
}

struct cluster_parallel_execution_script {
    string script
    bool valid
    string reason
}

struct cluster_parallel_rank_filter_result {
    cluster_parallel_launch_plan plan
    int kept_count
    int dropped_count
    bool valid
    string reason
}

func cluster_parallel_normalize(int tp, int pp, int dp, int world_size) cluster_parallel_topology {
    if tp <= 0 { tp = 1 }
    if pp <= 0 { pp = 1 }
    if dp <= 0 { dp = 1 }
    int expected = tp * pp * dp
    if world_size <= 0 {
        world_size = expected
    }
    if world_size != expected {
        world_size = expected
    }
    cluster_parallel_topology {
        tensor_parallel_size: tp,
        pipeline_parallel_size: pp,
        data_parallel_size: dp,
        world_size: world_size
    }
}

func cluster_parallel_rank_of(cluster_parallel_topology topology, int global_rank) cluster_parallel_rank {
    int tp = topology.tensor_parallel_size
    int pp = topology.pipeline_parallel_size
    int dp = topology.data_parallel_size
    int per_data = tp * pp
    int data_rank = global_rank / per_data
    int rem = global_rank - data_rank * per_data
    int pipeline_rank = rem / tp
    int tensor_rank = rem - pipeline_rank * tp
    cluster_parallel_rank {
        global_rank: global_rank,
        tensor_rank: tensor_rank,
        pipeline_rank: pipeline_rank,
        data_rank: data_rank
    }
}

func cluster_parallel_build_stages(cluster_parallel_topology topology, int num_layers) cluster_parallel_stage[] {
    if topology.pipeline_parallel_size <= 0 { topology.pipeline_parallel_size = 1 }
    cluster_parallel_stage[] stages = cluster_parallel_stage[]{cap: topology.pipeline_parallel_size}
    int per_stage = num_layers / topology.pipeline_parallel_size
    int remainder = num_layers - per_stage * topology.pipeline_parallel_size
    int stage = 0
    int cursor = 0
    for stage < topology.pipeline_parallel_size {
        int extra = 0
        if stage < remainder { extra = 1 }
        int start_layer = cursor
        int end_layer = cursor + per_stage + extra - 1
        if end_layer < start_layer { end_layer = start_layer }
        stages = append(stages, cluster_parallel_stage {
            stage_id: stage,
            start_layer: start_layer,
            end_layer: end_layer,
            replica_count: topology.tensor_parallel_size * topology.data_parallel_size
        })
        cursor = end_layer + 1
        stage = stage + 1
    }
    stages
}

func cluster_parallel_build_ranks(cluster_parallel_topology topology) cluster_parallel_rank[] {
    cluster_parallel_rank[] ranks = cluster_parallel_rank[]{cap: topology.world_size}
    int global_rank = 0
    for global_rank < topology.world_size {
        ranks = append(ranks, cluster_parallel_rank_of(topology, global_rank))
        global_rank = global_rank + 1
    }
    ranks
}

func cluster_parallel_plan_for(cluster_parallel_request request, int tp, int pp, int dp, int world_size, string backend) cluster_parallel_plan {
    cluster_parallel_topology topology = cluster_parallel_normalize(tp, pp, dp, world_size)
    bool valid = true
    string reason = ""
    if request.num_layers <= 0 {
        valid = false
        reason = "num_layers must be positive"
    }
    if request.min_device_count <= 0 {
        valid = false
        reason = "min_device_count must be positive"
    }
    if request.min_memory_gb <= 0 {
        valid = false
        reason = "min_memory_gb must be positive"
    }
    if topology.world_size != topology.tensor_parallel_size * topology.pipeline_parallel_size * topology.data_parallel_size {
        valid = false
        reason = "world_size mismatch"
    }
    cluster_parallel_plan {
        topology: topology,
        stages: cluster_parallel_build_stages(topology, request.num_layers),
        ranks: cluster_parallel_build_ranks(topology),
        valid: valid,
        backend: backend,
        reason: reason
    }
}

func cluster_parallel_plan_summary(cluster_parallel_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "backend=" + plan.backend + "\n"
    out = out + "world_size=" + itoa(plan.topology.world_size) + "\n"
    out = out + "tp=" + itoa(plan.topology.tensor_parallel_size) + "\n"
    out = out + "pp=" + itoa(plan.topology.pipeline_parallel_size) + "\n"
    out = out + "dp=" + itoa(plan.topology.data_parallel_size) + "\n"
    out = out + "stages=" + itoa(len(plan.stages)) + "\n"
    out = out + "ranks=" + itoa(len(plan.ranks)) + "\n"
    out
}

func cluster_parallel_plan_ready(cluster_parallel_plan plan) bool {
    plan.valid && len(plan.stages) > 0 && len(plan.ranks) > 0
}

func cluster_parallel_assign_to_nodes(cluster_parallel_plan plan, int[] node_ids, string[] node_names, string[] node_hosts) cluster_parallel_assignment_plan {
    cluster_parallel_assignment_plan result
    if !cluster_parallel_plan_ready(plan) {
        result.assignments = cluster_parallel_node_assignment[]{cap: 0}
        result.valid = false
        result.reason = "parallel plan not ready"
        return result
    }
    int available_nodes = len(node_ids)
    if available_nodes <= 0 {
        result.assignments = cluster_parallel_node_assignment[]{cap: 0}
        result.valid = false
        result.reason = "no nodes available"
        return result
    }
    cluster_parallel_node_assignment[] assignments = cluster_parallel_node_assignment[]{}
    int i = 0
    for i < len(plan.ranks) {
        cluster_parallel_rank rank = plan.ranks[i]
        int node_index = i - (i / available_nodes) * available_nodes
        int stage_id = rank.pipeline_rank
        int replica_id = rank.data_rank
        assignments = append(assignments, cluster_parallel_node_assignment {
            node_id: node_ids[node_index],
            node_name: node_names[node_index],
            host: node_hosts[node_index],
            global_rank: rank.global_rank,
            tensor_rank: rank.tensor_rank,
            pipeline_rank: rank.pipeline_rank,
            data_rank: rank.data_rank,
            stage_id: stage_id,
            replica_id: replica_id
        })
        i = i + 1
    }
    result.assignments = assignments
    result.valid = true
    result.reason = ""
    result
}

func cluster_parallel_assignment_summary(cluster_parallel_assignment_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "assignments=" + itoa(len(plan.assignments)) + "\n"
    if len(plan.assignments) > 0 {
        out = out + "first_node=" + plan.assignments[0].node_name + "\n"
        out = out + "first_rank=" + itoa(plan.assignments[0].global_rank) + "\n"
    }
    out
}

func cluster_parallel_build_launch_plan(cluster_parallel_assignment_plan assignment, string worker_bin, string master_addr, int master_port, int world_size) cluster_parallel_launch_plan {
    cluster_parallel_launch_plan result
    if !assignment.valid {
        result.commands = cluster_parallel_launch_command[]{cap: 0}
        result.valid = false
        result.reason = assignment.reason
        return result
    }
    if worker_bin == "" || master_addr == "" || master_port <= 0 || world_size <= 0 {
        result.commands = cluster_parallel_launch_command[]{cap: 0}
        result.valid = false
        result.reason = "invalid launch parameters"
        return result
    }
    cluster_parallel_launch_command[] commands = cluster_parallel_launch_command[]{}
    int i = 0
    for i < len(assignment.assignments) {
        cluster_parallel_node_assignment a = assignment.assignments[i]
        string cmd = "WORLD_SIZE=" + itoa(world_size)
        cmd = cmd + " RANK=" + itoa(a.global_rank)
        cmd = cmd + " LOCAL_RANK=" + itoa(a.pipeline_rank)
        cmd = cmd + " MASTER_ADDR=" + master_addr
        cmd = cmd + " MASTER_PORT=" + itoa(master_port)
        cmd = cmd + " NEURX_NODE_ID=" + itoa(a.node_id)
        cmd = cmd + " NEURX_NODE_NAME=" + a.node_name
        cmd = cmd + " NEURX_NODE_HOST=" + a.host
        cmd = cmd + " exec " + worker_bin
        commands = append(commands, cluster_parallel_launch_command {
            node_id: a.node_id,
            node_name: a.node_name,
            host: a.host,
            global_rank: a.global_rank,
            command: cmd
        })
        i = i + 1
    }
    result.commands = commands
    result.valid = true
    result.reason = ""
    result
}

func cluster_parallel_launch_summary(cluster_parallel_launch_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "commands=" + itoa(len(plan.commands)) + "\n"
    if len(plan.commands) > 0 {
        out = out + "first_node=" + plan.commands[0].node_name + "\n"
        out = out + "first_rank=" + itoa(plan.commands[0].global_rank) + "\n"
    }
    out
}

func cluster_parallel_group_launch_plan(cluster_parallel_launch_plan plan) cluster_parallel_grouped_launch_plan {
    cluster_parallel_grouped_launch_plan result
    if !plan.valid {
        result.bundles = cluster_parallel_host_bundle[]{cap: 0}
        result.valid = false
        result.reason = plan.reason
        return result
    }
    cluster_parallel_host_bundle[] bundles = cluster_parallel_host_bundle[]{}
    int i = 0
    for i < len(plan.commands) {
        cluster_parallel_launch_command cmd = plan.commands[i]
        int j = 0
        int found = 0 - 1
        for j < len(bundles) {
            if bundles[j].host == cmd.host {
                found = j
                break
            }
            j = j + 1
        }
        if found < 0 {
            bundles = append(bundles, cluster_parallel_host_bundle {
                host: cmd.host,
                node_name: cmd.node_name,
                command_count: 1
            })
        } else {
            bundles[found].command_count = bundles[found].command_count + 1
        }
        i = i + 1
    }
    result.bundles = bundles
    result.valid = true
    result.reason = ""
    result
}

func cluster_parallel_grouped_launch_summary(cluster_parallel_grouped_launch_plan plan) string {
    string out = ""
    out = out + "valid=" + itoa(plan.valid ? 1 : 0) + "\n"
    out = out + "bundles=" + itoa(len(plan.bundles)) + "\n"
    if len(plan.bundles) > 0 {
        out = out + "first_host=" + plan.bundles[0].host + "\n"
        out = out + "first_count=" + itoa(plan.bundles[0].command_count) + "\n"
    }
    out
}

func cluster_parallel_execute_launch_plan(cluster_parallel_launch_plan plan) cluster_parallel_execution_batch {
    cluster_parallel_execution_batch result
    if !plan.valid {
        result.lines = cluster_parallel_execution_line[]{cap: 0}
        result.valid = false
        result.reason = plan.reason
        return result
    }
    cluster_parallel_execution_line[] lines = cluster_parallel_execution_line[]{}
    int i = 0
    for i < len(plan.commands) {
        cluster_parallel_launch_command cmd = plan.commands[i]
        lines = append(lines, cluster_parallel_execution_line {
            host: cmd.host,
            node_name: cmd.node_name,
            global_rank: cmd.global_rank,
            command: cmd.command
        })
        i = i + 1
    }
    result.lines = lines
    result.valid = true
    result.reason = ""
    result
}

func cluster_parallel_execution_summary(cluster_parallel_execution_batch batch) string {
    string out = ""
    out = out + "valid=" + itoa(batch.valid ? 1 : 0) + "\n"
    out = out + "lines=" + itoa(len(batch.lines)) + "\n"
    if len(batch.lines) > 0 {
        out = out + "first_host=" + batch.lines[0].host + "\n"
        out = out + "first_rank=" + itoa(batch.lines[0].global_rank) + "\n"
    }
    out
}

func cluster_parallel_build_execution_script(cluster_parallel_execution_batch batch, bool use_ssh) cluster_parallel_execution_script {
    cluster_parallel_execution_script result
    if !batch.valid {
        result.script = ""
        result.valid = false
        result.reason = batch.reason
        return result
    }
    string script = "#!/bin/sh\nset -e\n"
    int i = 0
    for i < len(batch.lines) {
        cluster_parallel_execution_line line = batch.lines[i]
        if use_ssh {
            script = script + "ssh " + line.host + " '" + line.command + "'\n"
        } else {
            script = script + line.command + "\n"
        }
        i = i + 1
    }
    result.script = script
    result.valid = true
    result.reason = ""
    result
}

func cluster_parallel_filter_launch_plan(cluster_parallel_launch_plan plan, int[] failed_ranks) cluster_parallel_rank_filter_result {
    cluster_parallel_rank_filter_result meta
    if !plan.valid {
        meta.plan.commands = cluster_parallel_launch_command[]{cap: 0}
        meta.plan.valid = false
        meta.plan.reason = plan.reason
        meta.kept_count = 0
        meta.dropped_count = 0
        meta.valid = false
        meta.reason = plan.reason
        return meta
    }
    cluster_parallel_launch_command[] commands = cluster_parallel_launch_command[]{}
    int kept = 0
    int dropped = 0
    int i = 0
    for i < len(plan.commands) {
        cluster_parallel_launch_command cmd = plan.commands[i]
        bool should_drop = false
        int j = 0
        for j < len(failed_ranks) {
            if failed_ranks[j] == cmd.global_rank {
                should_drop = true
                break
            }
            j = j + 1
        }
        if should_drop {
            dropped = dropped + 1
        } else {
            commands = append(commands, cmd)
            kept = kept + 1
        }
        i = i + 1
    }
    meta.plan.commands = commands
    meta.plan.valid = true
    meta.plan.reason = ""
    meta.kept_count = kept
    meta.dropped_count = dropped
    meta.valid = true
    meta.reason = ""
    meta
}

func cluster_parallel_rank_filter_summary(cluster_parallel_rank_filter_result meta) string {
    string out = ""
    out = out + "valid=" + itoa(meta.valid ? 1 : 0) + "\n"
    out = out + "reason=" + meta.reason + "\n"
    out = out + "kept_count=" + itoa(meta.kept_count) + "\n"
    out = out + "dropped_count=" + itoa(meta.dropped_count) + "\n"
    out = out + cluster_parallel_launch_summary(meta.plan)
    out
}

func cluster_parallel_execution_script_summary(cluster_parallel_execution_script script) string {
    string out = ""
    out = out + "valid=" + itoa(script.valid ? 1 : 0) + "\n"
    out = out + "length=" + itoa(len(script.script)) + "\n"
    if len(script.script) > 0 {
        out = out + "prefix=" + script.script[0] + "\n"
    }
    out
}
