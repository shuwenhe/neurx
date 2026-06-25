// kernel/sched/sched.s
// AI task scheduler — analogue of Linux kernel/sched/core.c
//
// Linux maps:
//   sched/core.c      → schedule() main loop
//   sched/fair.c      → CFS fair scheduler
//   sched/rt.c        → realtime scheduler
//   sched/deadline.c  → EDF deadline scheduler
//
// NeurX maps:
//   AI workloads are "runnable entities": agent steps, inference requests,
//   training micro-batches, background services.
//   Priority classes mirror Linux sched classes:
//     SCHED_RT       → safety-critical (auto/robot real-time loops)
//     SCHED_NORMAL   → interactive agent steps
//     SCHED_IDLE     → background indexing, logging

// Priority classes (mirrors Linux SCHED_* constants)
int SCHED_RT     = 0   // hard real-time (< 10ms deadline)
int SCHED_NORMAL = 1   // interactive / agent steps
int SCHED_BATCH  = 2   // training micro-batches
int SCHED_IDLE   = 3   // background: indexing, logging, GC

struct task_struct {
    int     pid             // unique task id (agent step, infer req, etc.)
    string  name
    int     sched_class     // SCHED_RT | SCHED_NORMAL | SCHED_BATCH | SCHED_IDLE
    int     priority        // 0 (highest) .. 99
    int     deadline_ms     // 0 = no deadline
    int     state           // 0=runnable 1=running 2=waiting 3=done
    int     cpu_affinity    // -1 = any
    int     gpu_affinity    // -1 = any
    int     vruntime        // virtual runtime (CFS analogue)
    string  owner_agent     // which agent spawned this task
    int     created_at_ms
}

struct run_queue {
    []task_struct  rt_queue      // realtime tasks (sorted by deadline)
    []task_struct  normal_queue  // CFS red-black tree (simplified: sorted list)
    []task_struct  batch_queue
    []task_struct  idle_queue
    int            current_pid
    int            clock_ms
}

func new_run_queue() -> run_queue {
    return run_queue{
        rt_queue:     [],
        normal_queue: [],
        batch_queue:  [],
        idle_queue:   [],
        current_pid:  -1,
        clock_ms:     0,
    }
}

// enqueue_task: add a task to the appropriate queue (like Linux enqueue_task())
func enqueue_task(rq run_queue, t task_struct) -> run_queue {
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

// pick_next_task: select next runnable task (like Linux pick_next_task())
// Priority: RT > NORMAL > BATCH > IDLE
func pick_next_task(rq run_queue) -> (run_queue, task_struct, bool) {
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
