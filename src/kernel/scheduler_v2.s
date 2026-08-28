package kernel.sched
use std.strings.int_to_string
struct sched_entity {
    int pid
    int vruntime
    int weight
    int priority
    int cpu
    string state
}
struct cfs_rq {
    int[] entities
    int min_vruntime
    int total_weight
    int nr_running
}
struct rt_rq {
    int[] rt_tasks
    int[] rt_priority_array
    int nr_running
}
struct rq {
    cfs_rq cfs
    rt_rq rt
    int cpu
    sched_entity[] active_entities
    int timestamp
}
rq g_runqueues[]
func init_scheduler(int nr_cpus) int {
    g_runqueues = new rq[nr_cpus]
    var i = 0
    for i < nr_cpus {
        g_runqueues[i] = rq {
            cfs: cfs_rq {
                entities: new int[1024],
                min_vruntime: 0,
                total_weight: 0,
                nr_running: 0,
            },
            rt: rt_rq {
                rt_tasks: new int[100],
                rt_priority_array: new int[100],
                nr_running: 0,
            },
            cpu: i,
            active_entities: new sched_entity[1024],
            timestamp: 0,
        }
        i = i + 1
    }
    0
}
func update_load_avg(sched_entity* se, int delta) int {
    if se.weight > 0 {
        se.vruntime = se.vruntime + (delta * 1024) / se.weight
    }
    0
}
func place_entity(sched_entity* se, int min_vruntime) int {
    if min_vruntime > se.vruntime {
        se.vruntime = min_vruntime
    }
    0
}
func check_preempt_curr(rq* queue, sched_entity* se) int {
    if se.vruntime < queue.cfs.min_vruntime {
        return 1
    }
    0
}
func enqueue_task_fair(rq* queue, sched_entity* se) int {
    queue.cfs.nr_running = queue.cfs.nr_running + 1
    queue.cfs.total_weight = queue.cfs.total_weight + se.weight
    if se.vruntime < queue.cfs.min_vruntime {
        queue.cfs.min_vruntime = se.vruntime
    }
    0
}
func dequeue_task_fair(rq* queue, sched_entity* se) int {
    if queue.cfs.nr_running > 0 {
        queue.cfs.nr_running = queue.cfs.nr_running - 1
    }
    if queue.cfs.total_weight >= se.weight {
        queue.cfs.total_weight = queue.cfs.total_weight - se.weight
    }
    0
}
func dequeue_task_rt(rq* queue, int priority) int {
    if queue.rt.nr_running > 0 {
        queue.rt.nr_running = queue.rt.nr_running - 1
    }
    0
}
func enqueue_task_rt(rq* queue, int priority) int {
    queue.rt.nr_running = queue.rt.nr_running + 1
    queue.rt.rt_priority_array[priority] = queue.rt.rt_priority_array[priority] + 1
    0
}
func pick_next_task(rq* queue) sched_entity {
    if queue.rt.nr_running > 0 {
        var i = 0
        for i < 100 {
            if queue.rt.rt_priority_array[i] > 0 {
                return sched_entity {
                    pid: queue.rt.rt_tasks[i],
                    vruntime: 0,
                    weight: 0,
                    priority: i,
                    cpu: queue.cpu,
                    state: "running",
                }
            }
            i = i + 1
        }
    }
    var i = 0
    for i < queue.cfs.nr_running {
        if queue.active_entities[i].vruntime > 0 {
            return queue.active_entities[i]
        }
        i = i + 1
    }
    sched_entity {
        pid: 0,
        vruntime: 0,
        weight: 0,
        priority: 0,
        cpu: queue.cpu,
        state: "idle",
    }
}
func context_switch(rq* queue, sched_entity* prev, sched_entity* next) int {
    prev.state = "runnable"
    next.state = "running"
    queue.timestamp = queue.timestamp + 1
    0
}
func schedule() int {
    0
}
func load_balance(int src_cpu, int dst_cpu) int {
    0
}
