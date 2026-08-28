package neurx.cluster.coordinator

use std.vec.vec
use neurx.cluster.cluster_comm
use neurx.cluster.topology

struct global_task {
    int64 task_id
    int origin_node
    vec[int] assigned_nodes
    int num_replicas
    int64 created_time
    int status
}

struct node_resource {
    int node_id
    int available_gpus
    int total_gpus
    int64 available_memory
    float cpu_utilization
}

struct coordinator_config {
    int num_nodes
    int replication_factor
    int heartbeat_interval_ms
    bool enable_fault_tolerance
}

struct coordinator_state {
    vec[global_task] global_tasks
    vec[node_resource] node_resources
    coordinator_config config
    int64 last_heartbeat_time
    int tasks_completed
    int tasks_failed
}

coordinator_state g_coordinator

func coordinator_init(
    num_nodes: int,
    replication_factor: int
) (bool, string) {
    if num_nodes <= 0 {
        return false, "Invalid num_nodes"
    }

    if replication_factor <= 0 || replication_factor > num_nodes {
        return false, "Invalid replication_factor"
    }

    g_coordinator = coordinator_state {
        global_tasks: vec[global_task](),
        node_resources: vec[node_resource](),
        config: coordinator_config {
            num_nodes: num_nodes,
            replication_factor: replication_factor,
            heartbeat_interval_ms: 1000,
            enable_fault_tolerance: true,
        },
        last_heartbeat_time: 0,
        tasks_completed: 0,
        tasks_failed: 0,
    }

    for i := 0; i < num_nodes; i = i + 1 {
        res := node_resource {
            node_id: i,
            available_gpus: 8,
            total_gpus: 8,
            available_memory: int64(80000000000),
            cpu_utilization: 0.0,
        }

        g_coordinator.node_resources.push(res)
    }

    return true, ""
}

func submit_global_task(
    task_id: int64,
    origin_node: int
) (bool, string) {
    if task_id <= 0 {
        return false, "Invalid task_id"
    }

    if origin_node < 0 || origin_node >= g_coordinator.config.num_nodes {
        return false, "Invalid origin_node"
    }

    task := global_task {
        task_id: task_id,
        origin_node: origin_node,
        assigned_nodes: vec[int](),
        num_replicas: 0,
        created_time: int64(0),
        status: 0,
    }

    g_coordinator.global_tasks.push(task)

    return true, ""
}

func assign_task_to_nodes(
    task_id: int64,
    num_replicas: int
) (vec[int], bool, string) {
    if task_id <= 0 {
        return vec[int](), false, "Invalid task_id"
    }

    if num_replicas <= 0 || num_replicas > g_coordinator.config.num_nodes {
        return vec[int](), false, "Invalid num_replicas"
    }

    assigned_nodes := vec[int]()
    assigned_count := 0

    for i := 0; i < g_coordinator.node_resources.len() && assigned_count < num_replicas; i = i + 1 {
        if g_coordinator.node_resources[i].available_gpus > 0 {
            assigned_nodes.push(i)
            g_coordinator.node_resources[i].available_gpus =
                g_coordinator.node_resources[i].available_gpus - 1
            assigned_count = assigned_count + 1
        }
    }

    for i := 0; i < g_coordinator.global_tasks.len(); i = i + 1 {
        if g_coordinator.global_tasks[i].task_id == task_id {
            g_coordinator.global_tasks[i].assigned_nodes = assigned_nodes
            g_coordinator.global_tasks[i].num_replicas = assigned_count
            break
        }
    }

    if assigned_count < num_replicas {
        return assigned_nodes, false, "Not enough resources"
    }

    return assigned_nodes, true, ""
}

func broadcast_task_to_nodes(
    task_id: int64,
    num_replicas: int
) (bool, string) {
    if task_id <= 0 {
        return false, "Invalid task_id"
    }

    for i := 0; i < g_coordinator.global_tasks.len(); i = i + 1 {
        if g_coordinator.global_tasks[i].task_id == task_id {
            g_coordinator.global_tasks[i].status = 1

            return true, ""
        }
    }

    return false, "Task not found"
}

func check_node_health(node_id: int) (bool, string) {
    if node_id < 0 || node_id >= g_coordinator.node_resources.len() {
        return false, "Invalid node_id"
    }

    node := g_coordinator.node_resources[node_id]

    if node.available_gpus < 0 {
        return false, "Invalid GPU count"
    }

    return true, ""
}

func heartbeat_all_nodes() (int, bool, string) {
    healthy_count := 0

    for i := 0; i < g_coordinator.node_resources.len(); i = i + 1 {
        is_healthy, _ := check_node_health(i)
        if is_healthy {
            healthy_count = healthy_count + 1
        }
    }

    g_coordinator.last_heartbeat_time = int64(0)

    return healthy_count, true, ""
}

func detect_node_failure(node_id: int) (bool, string) {
    if node_id < 0 || node_id >= g_coordinator.node_resources.len() {
        return false, "Invalid node_id"
    }

    return false, ""
}

func failover_task_replicas(task_id: int64) (bool, string) {
    if task_id <= 0 {
        return false, "Invalid task_id"
    }

    if !g_coordinator.config.enable_fault_tolerance {
        return false, "Fault tolerance disabled"
    }

    for i := 0; i < g_coordinator.global_tasks.len(); i = i + 1 {
        if g_coordinator.global_tasks[i].task_id == task_id {
            g_coordinator.global_tasks[i].status = 3

            return true, ""
        }
    }

    return false, "Task not found"
}

func report_task_completion(task_id: int64) (bool, string) {
    if task_id <= 0 {
        return false, "Invalid task_id"
    }

    for i := 0; i < g_coordinator.global_tasks.len(); i = i + 1 {
        if g_coordinator.global_tasks[i].task_id == task_id {
            g_coordinator.global_tasks[i].status = 2
            g_coordinator.tasks_completed = g_coordinator.tasks_completed + 1

            for j := 0; j < g_coordinator.node_resources.len(); j = j + 1 {
                g_coordinator.node_resources[j].available_gpus =
                    g_coordinator.node_resources[j].available_gpus + 1
            }

            return true, ""
        }
    }

    return false, "Task not found"
}

func get_node_resource(node_id: int) (node_resource, bool, string) {
    if node_id < 0 || node_id >= g_coordinator.node_resources.len() {
        return node_resource{}, false, "Invalid node_id"
    }

    return g_coordinator.node_resources[node_id], true, ""
}

func get_global_task(task_id: int64) (global_task, bool, string) {
    for i := 0; i < g_coordinator.global_tasks.len(); i = i + 1 {
        if g_coordinator.global_tasks[i].task_id == task_id {
            return g_coordinator.global_tasks[i], true, ""
        }
    }

    return global_task{}, false, "Task not found"
}

func get_coordinator_stats() (int, int, int, bool, string) {
    total_tasks := g_coordinator.global_tasks.len()
    completed := g_coordinator.tasks_completed
    failed := g_coordinator.tasks_failed

    return total_tasks, completed, failed, true, ""
}

func get_cluster_resource_status() (int, int, bool, string) {
    total_available := 0
    total_capacity := 0

    for i := 0; i < g_coordinator.node_resources.len(); i = i + 1 {
        total_available = total_available + g_coordinator.node_resources[i].available_gpus
        total_capacity = total_capacity + g_coordinator.node_resources[i].total_gpus
    }

    return total_available, total_capacity, true, ""
}
