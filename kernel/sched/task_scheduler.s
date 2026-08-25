package neurx.kernel.sched

enum task_type {
    training_task,
    inference_task,
    system_task
}

enum task_state {
    ready,
    running,
    blocked,
    completed,
    failed
}

struct task {
    int task_id
    task_type task_type
    task_state state
    int priority
    int cpu_affinity
    int gpu_affinity
}

struct scheduler {
    vec[task]* ready_queue
    vec[task]* running_tasks
    int current_task_id
}

func create_scheduler() scheduler {
    scheduler {
        ready_queue: vec[task](),
        running_tasks: vec[task](),
        current_task_id: 0
    }
}

func schedule_training_task(sched: scheduler*, priority: int) int {
    let task_id = sched*.current_task_id
    sched*.current_task_id = sched*.current_task_id + 1
    task_id
}

func schedule_inference_task(sched: scheduler*, priority: int) int {
    let task_id = sched*.current_task_id
    sched*.current_task_id = sched*.current_task_id + 1
    task_id
}
