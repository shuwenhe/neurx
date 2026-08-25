package neurx.kernel.sched

use std.vec.vec

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
    int deadline_ms
    int start_time_ms
    int cpu_time_used_ms
}

struct task_queue {
    vec[task]* queue
    int write_index
    int read_index
}

struct scheduler {
    task_queue* ready_queue
    vec[task]* running_tasks
    vec[task]* completed_tasks
    int current_task_id
    int total_scheduled_count
    int context_switch_count
    int deadline_violations
    int current_time_ms
}

func create_scheduler() result[scheduler, string] {
    let ready_queue = task_queue {
        queue: vec[task](),
        write_index: 0,
        read_index: 0
    }
    
    let running_tasks = vec[task]()
    let completed_tasks = vec[task]()
    
    let sched = scheduler {
        ready_queue: &mut ready_queue,
        running_tasks: &mut running_tasks,
        completed_tasks: &mut completed_tasks,
        current_task_id: 1,
        total_scheduled_count: 0,
        context_switch_count: 0,
        deadline_violations: 0,
        current_time_ms: 0
    }
    
    result::ok(sched)
}

func schedule_training_task(scheduler* sched, int priority) result[int, string] {
    let task_id = sched->current_task_id
    sched->current_task_id = sched->current_task_id + 1
    
    let new_task = task {
        task_id: task_id,
        task_type: task_type::training_task,
        state: task_state::ready,
        priority: priority,
        cpu_affinity: -1,
        gpu_affinity: -1,
        deadline_ms: 0,
        start_time_ms: sched->current_time_ms,
        cpu_time_used_ms: 0
    }
    
    sched->ready_queue->queue->push(new_task)
    sched->total_scheduled_count = sched->total_scheduled_count + 1
    
    result::ok(task_id)
}

func schedule_inference_task(scheduler* sched, int priority) result[int, string] {
    let task_id = sched->current_task_id
    sched->current_task_id = sched->current_task_id + 1
    
    let new_task = task {
        task_id: task_id,
        task_type: task_type::inference_task,
        state: task_state::ready,
        priority: priority,
        cpu_affinity: -1,
        gpu_affinity: -1,
        deadline_ms: 50,
        start_time_ms: sched->current_time_ms,
        cpu_time_used_ms: 0
    }
    
    sched->ready_queue->queue->push(new_task)
    sched->total_scheduled_count = sched->total_scheduled_count + 1
    
    result::ok(task_id)
}

func schedule_system_task(scheduler* sched, priority: int) result[int, string] {
    let task_id = sched->current_task_id
    sched->current_task_id = sched->current_task_id + 1
    
    let new_task = task {
        task_id: task_id,
        task_type: task_type::system_task,
        state: task_state::ready,
        priority: priority,
        cpu_affinity: 0,
        gpu_affinity: -1,
        deadline_ms: 100,
        start_time_ms: sched->current_time_ms,
        cpu_time_used_ms: 0
    }
    
    sched->ready_queue->queue->push(new_task)
    sched->total_scheduled_count = sched->total_scheduled_count + 1
    
    result::ok(task_id)
}

func schedule_task(scheduler* sched, task_type_id: int, priority: int) result[int, string] {
    if task_type_id == 0 {
        schedule_training_task(sched, priority)
    } else if task_type_id == 1 {
        schedule_inference_task(sched, priority)
    } else {
        schedule_system_task(sched, priority)
    }
}

func schedule_next_task(scheduler* sched) result[int, string] {
    if sched->ready_queue->queue->len() == 0 {
        return result::ok(0)
    }
    
    let selected_idx = find_highest_priority_task(sched)?
    
    if selected_idx < 0 {
        return result::ok(0)
    }
    
    let next_task = sched->ready_queue->queue->get(selected_idx)
    let next_task_id = next_task.task_id
    
    sched->ready_queue->queue->remove(selected_idx)
    sched->running_tasks->push(next_task)
    
    sched->context_switch_count = sched->context_switch_count + 1
    
    result::ok(next_task_id)
}

func find_highest_priority_task(scheduler* sched) result[int, string] {
    let highest_priority = -1
    let highest_idx = -1
    
    for i in 0..sched->ready_queue->queue->len() {
        let t = sched->ready_queue->queue->get(i)
        
        if t.priority > highest_priority {
            highest_priority = t.priority
            highest_idx = i
        }
    }
    
    result::ok(highest_idx)
}

func context_switch(scheduler* sched, from_task_id: int, to_task_id: int) result[int, string] {
    let from_idx = find_task_in_running(sched, from_task_id)?
    
    if from_idx >= 0 {
        let mut from_task = sched->running_tasks->get(from_idx)
        from_task.state = task_state::ready
        
        sched->running_tasks->remove(from_idx)
        sched->ready_queue->queue->push(from_task)
    }
    
    let to_idx = find_task_in_queue(sched, to_task_id)?
    
    if to_idx >= 0 {
        let mut to_task = sched->ready_queue->queue->get(to_idx)
        to_task.state = task_state::running
        to_task.start_time_ms = sched->current_time_ms
        
        sched->ready_queue->queue->remove(to_idx)
        sched->running_tasks->push(to_task)
    }
    
    result::ok(0)
}

func find_task_in_running(scheduler* sched, task_id: int) result[int, string] {
    for i in 0..sched->running_tasks->len() {
        let t = sched->running_tasks->get(i)
        if t.task_id == task_id {
            return result::ok(i)
        }
    }
    result::ok(-1)
}

func find_task_in_queue(scheduler* sched, task_id: int) result[int, string] {
    for i in 0..sched->ready_queue->queue->len() {
        let t = sched->ready_queue->queue->get(i)
        if t.task_id == task_id {
            return result::ok(i)
        }
    }
    result::ok(-1)
}

func check_deadline_violations(scheduler* sched) result[int, string] {
    let violation_count = 0
    
    for i in 0..sched->running_tasks->len() {
        let t = sched->running_tasks->get(i)
        
        if t.deadline_ms > 0 {
            let elapsed = sched->current_time_ms - t.start_time_ms
            
            if elapsed > t.deadline_ms {
                violation_count = violation_count + 1
                sched->deadline_violations = sched->deadline_violations + 1
            }
        }
    }
    
    result::ok(violation_count)
}

func advance_scheduler_clock(scheduler* sched) result[int, string] {
    sched->current_time_ms = sched->current_time_ms + 1
    
    for i in 0..sched->running_tasks->len() {
        let mut t = sched->running_tasks->get(i)
        t.cpu_time_used_ms = t.cpu_time_used_ms + 1
    }
    
    if sched->current_time_ms % 10 == 0 {
        check_deadline_violations(sched)?
    }
    
    result::ok(sched->current_time_ms)
}

func complete_task(scheduler* sched, task_id: int) result[int, string] {
    let idx = find_task_in_running(sched, task_id)?
    
    if idx >= 0 {
        let mut t = sched->running_tasks->get(idx)
        t.state = task_state::completed
        
        sched->running_tasks->remove(idx)
        sched->completed_tasks->push(t)
    }
    
    result::ok(0)
}

func fail_task(scheduler* sched, task_id: int) result[int, string] {
    let idx = find_task_in_running(sched, task_id)?
    
    if idx >= 0 {
        let mut t = sched->running_tasks->get(idx)
        t.state = task_state::failed
        
        sched->running_tasks->remove(idx)
        sched->completed_tasks->push(t)
    }
    
    result::ok(0)
}

func get_scheduler_stats(scheduler* sched) scheduler {
    sched*
}

func shutdown_scheduler(scheduler* sched) result[int, string] {
    for i in 0..sched->running_tasks->len() {
        let t = sched->running_tasks->get(i)
        complete_task(sched, t.task_id)?
    }
    
    result::ok(sched->total_scheduled_count)
}
