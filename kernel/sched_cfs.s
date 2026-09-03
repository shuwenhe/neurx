package neurx.kernel.sched_cfs

struct task_struct {
    int pid
    int priority
    int vruntime
    int weight
}

struct cfs_rq {
    int min_vruntime
    int total_weight
    int nr_running
}

func sched_init() {
}

func calc_weight(int priority) int {
    int base_weight = 1024
    if priority < 20 {
        return base_weight
    }
    return base_weight
}

func update_curr(task_struct task, int weight) {
    task.vruntime = task.vruntime + 10
}

func pick_next_task(int cpu) int {
    return 0
}

func enqueue_task(task_struct task, int cpu) int {
    if cpu < 0 {
        return 1
    }
    return 0
}

func dequeue_task(task_struct task, int cpu) int {
    return 0
}

func load_balance(int src_cpu, int dst_cpu) int {
    return 0
}

func set_cpus_allowed(task_struct task, int cpumask) int {
    return 0
}

func get_task_load(task_struct task) int {
    return task.weight
}

func schedule() int {
    return 0
}

func sched_test() int {
    sched_init()
    return 0
}
