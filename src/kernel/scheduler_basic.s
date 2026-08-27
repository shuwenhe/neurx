package kernel.scheduler

use std.io.eprintln

struct task {
    int pid
    int prio
    int state
}

task[] run_queue

func init_scheduler() int {
    run_queue = task[]{}
    0
}

func add_task(int pid, int prio) int {
    run_queue = append(run_queue, task{pid:pid, prio:prio, state:0})
    0
}

func schedule() int {
    if len(run_queue) == 0 {
        return 0
    }
    // naive scheduler: pick highest priority
    best := 0
    i := 0
    for i < len(run_queue) {
        if run_queue[i].prio > run_queue[best].prio {
            best = i
        }
        i = i + 1
    }
    eprintln("schedule: chosen pid=" + run_queue[best].pid)
    0
}
