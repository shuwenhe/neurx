package neurx.scheduler

use std.vec.vec
use neurx.device.abi

struct task_id {
    int64 request_id
    int64 timestamp
}

struct inference_task {
    task_id id
    vec[int] input_ids
    int batch_size
    int seq_len
    int priority
    int status
    int assigned_gpu_group
    int64 created_time
    int64 start_time
    int64 end_time
}

struct gpu_group {
    int group_id
    vec[int] gpu_ids
    int tp_size
    int pp_size
    int current_load
    int max_batch_size
    bool is_available
}

struct scheduler_config {
    int num_gpu_groups
    int max_queue_size
    int queue_timeout_ms
    int load_balance_interval_ms
    bool enable_priority_scheduling
    bool enable_preemption
}

struct scheduler_state {
    vec[inference_task] task_queue
    vec[gpu_group] gpu_groups
    scheduler_config config
    int next_task_id
    int64 last_rebalance_time
    int total_tasks_processed
    int64 total_compute_time
}

var g_scheduler scheduler_state

func scheduler_init(num_groups: int, max_queue: int) (bool, string) {
    if num_groups <= 0 || max_queue <= 0 {
        return false, "Invalid scheduler config"
    }

    g_scheduler = scheduler_state {
        task_queue: vec[inference_task](),
        gpu_groups: vec[gpu_group](),
        config: scheduler_config {
            num_gpu_groups: num_groups,
            max_queue_size: max_queue,
            queue_timeout_ms: 5000,
            load_balance_interval_ms: 100,
            enable_priority_scheduling: true,
            enable_preemption: false,
        },
        next_task_id: 1,
        last_rebalance_time: 0,
        total_tasks_processed: 0,
        total_compute_time: 0,
    }

    for i := 0; i < num_groups; i = i + 1 {
        group := gpu_group {
            group_id: i,
            gpu_ids: vec[int](),
            tp_size: 1,
            pp_size: 1,
            current_load: 0,
            max_batch_size: 128,
            is_available: true,
        }

        g_scheduler.gpu_groups.push(group)
    }

    return true, ""
}

func register_gpu_group(
    group_id: int,
    gpu_ids: vec[int],
    tp_size: int,
    pp_size: int
) (bool, string) {
    if group_id < 0 || group_id >= g_scheduler.gpu_groups.len() {
        return false, "Invalid group_id"
    }

    if gpu_ids.len() != tp_size * pp_size {
        return false, "GPU count mismatch with TP/PP config"
    }

    g_scheduler.gpu_groups[group_id].gpu_ids = gpu_ids
    g_scheduler.gpu_groups[group_id].tp_size = tp_size
    g_scheduler.gpu_groups[group_id].pp_size = pp_size
    g_scheduler.gpu_groups[group_id].is_available = true

    return true, ""
}

func submit_inference_task(
    input_ids: vec[int],
    batch_size: int,
    priority: int
) (int64, bool, string) {
    if input_ids.len() <= 0 {
        return 0, false, "Empty input"
    }

    if batch_size <= 0 {
        return 0, false, "Invalid batch size"
    }

    if g_scheduler.task_queue.len() >= g_scheduler.config.max_queue_size {
        return 0, false, "Queue full"
    }

    if priority < 0 || priority > 3 {
        return 0, false, "Invalid priority (0-3)"
    }

    current_time_ms := int64(0)

    task := inference_task {
        id: task_id {
            request_id: int64(g_scheduler.next_task_id),
            timestamp: current_time_ms,
        },
        input_ids: input_ids,
        batch_size: batch_size,
        seq_len: input_ids.len(),
        priority: priority,
        status: 0,
        assigned_gpu_group: -1,
        created_time: current_time_ms,
        start_time: 0,
        end_time: 0,
    }

    g_scheduler.task_queue.push(task)
    g_scheduler.next_task_id = g_scheduler.next_task_id + 1

    return task.id.request_id, true, ""
}

func get_next_task() (inference_task, bool, string) {
    if g_scheduler.task_queue.len() <= 0 {
        return inference_task{}, false, "Queue empty"
    }

    selected_idx := 0

    if g_scheduler.config.enable_priority_scheduling {
        max_priority := -1
        for i := 0; i < g_scheduler.task_queue.len(); i = i + 1 {
            if g_scheduler.task_queue[i].priority > max_priority {
                max_priority = g_scheduler.task_queue[i].priority
                selected_idx = i
            }
        }
    }

    return g_scheduler.task_queue[selected_idx], true, ""
}

func allocate_gpu_group(required_batch_size: int) (int, bool, string) {
    best_group := -1
    min_load := 10000

    for i := 0; i < g_scheduler.gpu_groups.len(); i = i + 1 {
        group := g_scheduler.gpu_groups[i]

        if !group.is_available {
            continue
        }

        if required_batch_size > group.max_batch_size {
            continue
        }

        if group.current_load < min_load {
            min_load = group.current_load
            best_group = i
        }
    }

    if best_group < 0 {
        return -1, false, "No available GPU group"
    }

    g_scheduler.gpu_groups[best_group].current_load =
        g_scheduler.gpu_groups[best_group].current_load + required_batch_size

    return best_group, true, ""
}

func release_gpu_group(group_id: int, batch_size: int) (bool, string) {
    if group_id < 0 || group_id >= g_scheduler.gpu_groups.len() {
        return false, "Invalid group_id"
    }

    g_scheduler.gpu_groups[group_id].current_load =
        g_scheduler.gpu_groups[group_id].current_load - batch_size

    if g_scheduler.gpu_groups[group_id].current_load < 0 {
        g_scheduler.gpu_groups[group_id].current_load = 0
    }

    return true, ""
}

func rebalance_load() (bool, string) {
    if g_scheduler.gpu_groups.len() <= 1 {
        return true, ""
    }

    total_load := 0
    for i := 0; i < g_scheduler.gpu_groups.len(); i = i + 1 {
        total_load = total_load + g_scheduler.gpu_groups[i].current_load
    }

    avg_load := total_load / g_scheduler.gpu_groups.len()

    for i := 0; i < g_scheduler.gpu_groups.len(); i = i + 1 {
        current := g_scheduler.gpu_groups[i].current_load
        diff := current - avg_load

        if diff > 10 {
            adjustment := diff / 2
            g_scheduler.gpu_groups[i].current_load =
                g_scheduler.gpu_groups[i].current_load - adjustment
        }
    }

    return true, ""
}

func get_group_status(group_id: int) (gpu_group, bool, string) {
    if group_id < 0 || group_id >= g_scheduler.gpu_groups.len() {
        return gpu_group{}, false, "Invalid group_id"
    }

    return g_scheduler.gpu_groups[group_id], true, ""
}

func get_queue_length() int {
    return g_scheduler.task_queue.len()
}

func get_queue_status() (vec[int], bool, string) {
    statuses := vec[int]()

    for i := 0; i < g_scheduler.task_queue.len(); i = i + 1 {
        statuses.push(g_scheduler.task_queue[i].status)
    }

    return statuses, true, ""
}

func set_task_status(task_id_val: int64, status: int) (bool, string) {
    for i := 0; i < g_scheduler.task_queue.len(); i = i + 1 {
        if g_scheduler.task_queue[i].id.request_id == task_id_val {
            g_scheduler.task_queue[i].status = status
            return true, ""
        }
    }

    return false, "Task not found"
}

func remove_completed_task(task_id_val: int64) (bool, string) {
    for i := 0; i < g_scheduler.task_queue.len(); i = i + 1 {
        if g_scheduler.task_queue[i].id.request_id == task_id_val {
            g_scheduler.total_tasks_processed = g_scheduler.total_tasks_processed + 1
            return true, ""
        }
    }

    return false, "Task not found"
}

func get_scheduler_stats() (int, int, int64, bool, string) {
    queue_len := g_scheduler.task_queue.len()
    tasks_done := g_scheduler.total_tasks_processed
    total_time := g_scheduler.total_compute_time

    return queue_len, tasks_done, total_time, true, ""
}
