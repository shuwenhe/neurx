package lora

type worker_status string

const (
    worker_idle        worker_status = "idle"
    worker_busy        worker_status = "busy"
    worker_processing  worker_status = "processing"
    worker_failed      worker_status = "failed"
    worker_terminated  worker_status = "terminated"
)

type task_type string

const (
    task_load_adapter      task_type = "load_adapter"
    task_unload_adapter    task_type = "unload_adapter"
    task_inference         task_type = "inference"
    task_training          task_type = "training"
    task_merge_adapters    task_type = "merge_adapters"
)

struct worker_task {
    string task_id
    task_type type
    string adapter_name
    vec[interface{}] task_data
    float32 priority
    int32 retry_count
    int32 max_retries
}

struct worker_process {
    int32 worker_id
    worker_status status
    string assigned_task_id
    int32 completed_tasks
    int32 failed_tasks
    float32 avg_task_time_us
}

struct worker_manager {
    map[string]worker_process* workers
    map[string]worker_task* task_queue
    int32 num_workers
    int32 total_tasks
    int32 completed_tasks
    bool enable_load_balancing
}

func create_worker_manager(int32 num_workers) worker_manager* {
    mgr := worker_manager{
        workers: make(map[string]worker_process*),
        task_queue: make(map[string]worker_task*),
        num_workers: num_workers,
        total_tasks: 0,
        completed_tasks: 0,
        enable_load_balancing: true,
    }

    for i := 0; i < num_workers; i = i + 1 {
        worker_id := "worker_" + string(i)
        worker := &worker_process{
            worker_id: i,
            status: worker_idle,
            assigned_task_id: "",
            completed_tasks: 0,
            failed_tasks: 0,
            avg_task_time_us: 0.0,
        }
        mgr.workers[worker_id] = worker
    }

    return &mgr
}

func (worker_manager* mgr) submit_task(string task_id, task_type type, string adapter_name, float32 priority) bool {
    if _, exists := mgr.task_queue[task_id]; exists {
        return false
    }

    task := &worker_task{
        task_id: task_id,
        type: type,
        adapter_name: adapter_name,
        task_data: make(vec[interface{}]),
        priority: priority,
        retry_count: 0,
        max_retries: 3,
    }

    mgr.task_queue[task_id] = task
    mgr.total_tasks = mgr.total_tasks + 1

    return true
}

func (worker_manager* mgr) cancel_task(string task_id) bool {
    if _, exists := mgr.task_queue[task_id]; exists {
        delete(mgr.task_queue, task_id)
        return true
    }

    return false
}

func (worker_manager* mgr) assign_task(string worker_id, string task_id) bool {
    if worker, exists := mgr.workers[worker_id]; exists {
        if task, task_exists := mgr.task_queue[task_id]; task_exists {
            worker.assigned_task_id = task_id
            worker.status = worker_processing

            task.retry_count = 0

            return true
        }
    }

    return false
}

func (worker_manager* mgr) complete_task(string worker_id, string task_id, bool success) bool {
    if worker, exists := mgr.workers[worker_id]; exists {
        if worker.assigned_task_id == task_id {
            if success {
                worker.completed_tasks = worker.completed_tasks + 1
                mgr.completed_tasks = mgr.completed_tasks + 1
            } else {
                worker.failed_tasks = worker.failed_tasks + 1
            }

            worker.assigned_task_id = ""
            worker.status = worker_idle

            delete(mgr.task_queue, task_id)

            return true
        }
    }

    return false
}

func (worker_manager* mgr) get_idle_worker() string {
    min_load := 999999
    idle_worker := ""

    for worker_id := range mgr.workers {
        worker := mgr.workers[worker_id]
        if worker.status == worker_idle {
            if worker.completed_tasks + worker.failed_tasks < min_load {
                min_load = worker.completed_tasks + worker.failed_tasks
                idle_worker = worker_id
            }
        }
    }

    return idle_worker
}

func (worker_manager* mgr) get_worker_status(string worker_id) worker_status {
    if worker, exists := mgr.workers[worker_id]; exists {
        return worker.status
    }

    return worker_terminated
}

func (worker_manager* mgr) get_pending_tasks() vec[string] {
    tasks := make(vec[string])

    for task_id := range mgr.task_queue {
        tasks = append(tasks, task_id)
    }

    return tasks
}

func (worker_manager* mgr) retry_failed_task(string task_id) bool {
    if task, exists := mgr.task_queue[task_id]; exists {
        if task.retry_count < task.max_retries {
            task.retry_count = task.retry_count + 1
            return true
        }
    }

    return false
}

func (worker_manager* mgr) set_load_balancing(bool enable) {
    mgr.enable_load_balancing = enable
}

func (worker_manager* mgr) process_queue() {
    for task_id := range mgr.task_queue {
        idle_worker := mgr.get_idle_worker()

        if idle_worker != "" {
            mgr.assign_task(idle_worker, task_id)
        }
    }
}

func (worker_manager* mgr) get_worker_stats(string worker_id) map[string]interface{} {
    stats := make(map[string]interface{})

    if worker, exists := mgr.workers[worker_id]; exists {
        stats["worker_id"] = worker.worker_id
        stats["status"] = worker.status
        stats["assigned_task"] = worker.assigned_task_id
        stats["completed_tasks"] = worker.completed_tasks
        stats["failed_tasks"] = worker.failed_tasks
        stats["avg_task_time"] = worker.avg_task_time_us
    }

    return stats
}

func (worker_manager* mgr) get_manager_stats() map[string]interface{} {
    stats := make(map[string]interface{})

    stats["num_workers"] = mgr.num_workers
    stats["total_tasks"] = mgr.total_tasks
    stats["completed_tasks"] = mgr.completed_tasks
    stats["pending_tasks"] = len(mgr.task_queue)
    stats["load_balancing_enabled"] = mgr.enable_load_balancing

    idle_count := 0
    busy_count := 0
    processing_count := 0

    for worker_id := range mgr.workers {
        worker := mgr.workers[worker_id]
        if worker.status == worker_idle {
            idle_count = idle_count + 1
        } else if worker.status == worker_busy {
            busy_count = busy_count + 1
        } else if worker.status == worker_processing {
            processing_count = processing_count + 1
        }
    }

    stats["idle_workers"] = idle_count
    stats["busy_workers"] = busy_count
    stats["processing_workers"] = processing_count

    return stats
}

func (worker_manager* mgr) shutdown() {
    for worker_id := range mgr.workers {
        worker := mgr.workers[worker_id]
        worker.status = worker_terminated
    }

    for task_id := range mgr.task_queue {
        delete(mgr.task_queue, task_id)
    }
}
