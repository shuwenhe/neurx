package neurx.scheduler.kernel_sched
int SCHED_RT     = 0
int SCHED_NORMAL = 1
int SCHED_BATCH  = 2
int SCHED_IDLE   = 3
struct task_struct {
    int     pid
    string  name
    int     sched_class
    int     priority
    int     deadline_ms
    int     state
    int     cpu_affinity
    int     gpu_affinity
    int     vruntime
    string  owner_agent
    int     created_at_ms
}

struct run_queue {
    []task_struct  rt_queue
    []task_struct  normal_queue
    []task_struct  batch_queue
    []task_struct  idle_queue
    int            current_pid
    int            clock_ms
}

func new_run_queue() run_queue {
    return run_queue{
        rt_queue:     [],
        normal_queue: [],
        batch_queue:  [],
        idle_queue:   [],
        current_pid:  -1,
        clock_ms:     0,
    }
}

func enqueue_task(rq run_queue, t task_struct) run_queue {
    if t.sched_class == SCHED_RT {
        rq.rt_queue = append(rq.rt_queue, t)
    } else if t.sched_class == SCHED_NORMAL {
        rq.normal_queue = append(rq.normal_queue, t)
    } else if t.sched_class == SCHED_BATCH {
        rq.batch_queue = append(rq.batch_queue, t)
    } else {
        rq.idle_queue = append(rq.idle_queue, t)
    }
    return rq
}

func pick_next_task(rq run_queue) (run_queue, task_struct, bool) {
    if len(rq.rt_queue) > 0 {
        task_struct t = rq.rt_queue[0]
        rq.rt_queue = rq.rt_queue[1:]
        rq.current_pid = t.pid
        return (rq, t, true)
    }
    if len(rq.normal_queue) > 0 {
        task_struct t = rq.normal_queue[0]
        rq.normal_queue = rq.normal_queue[1:]
        rq.current_pid = t.pid
        return (rq, t, true)
    }
    if len(rq.batch_queue) > 0 {
        task_struct t = rq.batch_queue[0]
        rq.batch_queue = rq.batch_queue[1:]
        rq.current_pid = t.pid
        return (rq, t, true)
    }
    if len(rq.idle_queue) > 0 {
        task_struct t = rq.idle_queue[0]
        rq.idle_queue = rq.idle_queue[1:]
        rq.current_pid = t.pid
        return (rq, t, true)
    }
    return (rq, task_struct{}, false)
}

