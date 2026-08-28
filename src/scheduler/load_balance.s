package neurx.scheduler.load_balance

use std.vec.vec

struct load_balance_policy {
    int policy_type
    int rebalance_threshold
    int check_interval_ms
}

struct gpu_utilization {
    int group_id
    int64 compute_time_us
    int64 communication_time_us
    int queue_depth
    float utilization_percent
}

struct load_balancer_state {
    vec[gpu_utilization] group_metrics
    load_balance_policy policy
    int64 last_check_time
    int rebalance_count
}

var g_load_balancer load_balancer_state

func load_balancer_init(
    num_groups: int,
    policy_type: int
) (bool, string) {
    if num_groups <= 0 {
        return false, "Invalid num_groups"
    }

    if policy_type < 0 || policy_type > 2 {
        return false, "Invalid policy_type (0=static, 1=dynamic, 2=adaptive)"
    }

    g_load_balancer = load_balancer_state {
        group_metrics: vec[gpu_utilization](),
        policy: load_balance_policy {
            policy_type: policy_type,
            rebalance_threshold: 30,
            check_interval_ms: 100,
        },
        last_check_time: 0,
        rebalance_count: 0,
    }

    for i := 0; i < num_groups; i = i + 1 {
        metric := gpu_utilization {
            group_id: i,
            compute_time_us: 0,
            communication_time_us: 0,
            queue_depth: 0,
            utilization_percent: 0.0,
        }

        g_load_balancer.group_metrics.push(metric)
    }

    return true, ""
}

func update_group_metrics(
    group_id: int,
    compute_time_us: int64,
    comm_time_us: int64,
    queue_depth: int
) (bool, string) {
    if group_id < 0 || group_id >= g_load_balancer.group_metrics.len() {
        return false, "Invalid group_id"
    }

    total_time_us := compute_time_us + comm_time_us
    if total_time_us <= 0 {
        g_load_balancer.group_metrics[group_id].utilization_percent = 0.0
    } else {
        util := float(compute_time_us * 100) / float(total_time_us)
        g_load_balancer.group_metrics[group_id].utilization_percent = util
    }

    g_load_balancer.group_metrics[group_id].compute_time_us = compute_time_us
    g_load_balancer.group_metrics[group_id].communication_time_us = comm_time_us
    g_load_balancer.group_metrics[group_id].queue_depth = queue_depth

    return true, ""
}

func check_load_imbalance() (bool, string) {
    if g_load_balancer.group_metrics.len() <= 1 {
        return false, "Single group, no balancing needed"
    }

    max_util := 0.0
    min_util := 100.0

    for i := 0; i < g_load_balancer.group_metrics.len(); i = i + 1 {
        util := g_load_balancer.group_metrics[i].utilization_percent
        if util > max_util {
            max_util = util
        }
        if util < min_util {
            min_util = util
        }
    }

    diff := max_util - min_util
    threshold := float(g_load_balancer.policy.rebalance_threshold)

    if diff > threshold {
        return true, ""
    }

    return false, ""
}

func get_most_loaded_group() (int, bool, string) {
    if g_load_balancer.group_metrics.len() <= 0 {
        return -1, false, "No groups"
    }

    max_load := 0
    max_idx := 0

    for i := 0; i < g_load_balancer.group_metrics.len(); i = i + 1 {
        if g_load_balancer.group_metrics[i].queue_depth > max_load {
            max_load = g_load_balancer.group_metrics[i].queue_depth
            max_idx = i
        }
    }

    return max_idx, true, ""
}

func get_least_loaded_group() (int, bool, string) {
    if g_load_balancer.group_metrics.len() <= 0 {
        return -1, false, "No groups"
    }

    min_load := 10000
    min_idx := 0

    for i := 0; i < g_load_balancer.group_metrics.len(); i = i + 1 {
        if g_load_balancer.group_metrics[i].queue_depth < min_load {
            min_load = g_load_balancer.group_metrics[i].queue_depth
            min_idx = i
        }
    }

    return min_idx, true, ""
}

func suggest_migration(src_group: int, dest_group: int) (bool, string) {
    if src_group < 0 || src_group >= g_load_balancer.group_metrics.len() {
        return false, "Invalid src_group"
    }

    if dest_group < 0 || dest_group >= g_load_balancer.group_metrics.len() {
        return false, "Invalid dest_group"
    }

    src_queue := g_load_balancer.group_metrics[src_group].queue_depth
    dest_queue := g_load_balancer.group_metrics[dest_group].queue_depth

    if dest_queue < src_queue {
        return true, ""
    }

    return false, ""
}

func compute_optimal_allocation(
    batch_size: int,
    num_available_groups: int
) (int, bool, string) {
    if batch_size <= 0 || num_available_groups <= 0 {
        return 1, false, "Invalid parameters"
    }

    tasks_per_group := (batch_size + num_available_groups - 1) / num_available_groups

    return tasks_per_group, true, ""
}

func get_group_metrics(group_id: int) (gpu_utilization, bool, string) {
    if group_id < 0 || group_id >= g_load_balancer.group_metrics.len() {
        return gpu_utilization{}, false, "Invalid group_id"
    }

    return g_load_balancer.group_metrics[group_id], true, ""
}

func get_all_metrics() (vec[gpu_utilization], bool, string) {
    return g_load_balancer.group_metrics, true, ""
}

func reset_metrics() (bool, string) {
    for i := 0; i < g_load_balancer.group_metrics.len(); i = i + 1 {
        g_load_balancer.group_metrics[i].compute_time_us = 0
        g_load_balancer.group_metrics[i].communication_time_us = 0
        g_load_balancer.group_metrics[i].queue_depth = 0
        g_load_balancer.group_metrics[i].utilization_percent = 0.0
    }

    return true, ""
}

func get_balancer_status() (int, int, bool, string) {
    rebalances := g_load_balancer.rebalance_count
    groups := g_load_balancer.group_metrics.len()

    return rebalances, groups, true, ""
}
