package neurx.kernel.sched.realtime

use std.slices

struct rt_task {
    int task_id
    int priority
    int deadline
    int period
    int cpu_affinity
    int status
}

struct rt_scheduler {
    rt_task[] ready_queue
    int current_task_id
    int preemption_enabled
    int scheduling_point
}

struct deadline_tracker {
    int task_id
    int deadline
    int execution_time
    int missed_count
}

struct priority_level {
    int level
    rt_task[] tasks
    int quantum
}

func create_rt_task(int pid, int priority, int deadline, int period) rt_task {
    task := rt_task {
        task_id: pid,
        priority: priority,
        deadline: deadline,
        period: period,
        cpu_affinity: 0,
        status: 0
    }
    task
}

func create_rt_scheduler() rt_scheduler {
    scheduler := rt_scheduler {
        ready_queue: rt_task[](),
        current_task_id: 0,
        preemption_enabled: 1,
        scheduling_point: 0
    }
    scheduler
}

func rt_scheduler_add_task(rt_scheduler sched, rt_task task) rt_scheduler {
    sched.ready_queue = append(sched.ready_queue, task)
    sched
}

func rt_scheduler_preempt(rt_scheduler sched) rt_scheduler {
    sched.scheduling_point = 1
    sched
}

func rt_enable_preemption(rt_scheduler sched) rt_scheduler {
    sched.preemption_enabled = 1
    sched
}

func rt_disable_preemption(rt_scheduler sched) rt_scheduler {
    sched.preemption_enabled = 0
    sched
}

func create_deadline_tracker(int task_id, int deadline) deadline_tracker {
    tracker := deadline_tracker {
        task_id: task_id,
        deadline: deadline,
        execution_time: 0,
        missed_count: 0
    }
    tracker
}

func deadline_tracker_check(deadline_tracker tracker) int {
    i := 0
    if tracker.execution_time > tracker.deadline {
        i = 1
        tracker.missed_count = tracker.missed_count + 1
    }
    i
}

func create_priority_level(int level) priority_level {
    pl := priority_level {
        level: level,
        tasks: rt_task[](),
        quantum: 0
    }
    pl
}

func rt_get_queue_length(rt_scheduler sched) int {
    len(sched.ready_queue)
}

func rt_get_current_task(rt_scheduler sched) int {
    sched.current_task_id
}
