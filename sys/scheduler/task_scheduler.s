package neurx.sys.scheduler

use std.vec.vec

struct inference_task {
    task_id: int64
    model_id: string
    batch_size: int
    priority: int
    device_id: int
    status: int
}

struct task_queue {
    tasks: vec[inference_task]
    next_task_id: int64
    max_tasks: int
}

struct scheduler_stats {
    total_tasks: int
    pending_tasks: int
    running_tasks: int
    completed_tasks: int
}

func create_task_queue(max_tasks: int) task_queue {
    queue := task_queue {
        tasks: vec[inference_task](),
        next_task_id: 1,
        max_tasks: max_tasks
    }
    queue
}

func enqueue_task(queue: &mut task_queue, model_id: string, batch_size: int, priority: int, device_id: int) int64 {
    if queue.tasks.len() >= queue.max_tasks {
        return 0
    }
    
    task_id := queue.next_task_id
    queue.next_task_id = queue.next_task_id + 1
    
    task := inference_task {
        task_id: task_id,
        model_id: model_id,
        batch_size: batch_size,
        priority: priority,
        device_id: device_id,
        status: 0
    }
    queue.tasks.push(task)
    task_id
}

func dequeue_task(queue: &mut task_queue) option[inference_task] {
    if queue.tasks.len() == 0 {
        return option::none
    }
    
    max_priority_idx := 0
    max_priority := queue.tasks.data[0].priority
    
    i := 1
    for i < queue.tasks.len() {
        if queue.tasks.data[i].priority > max_priority {
            max_priority_idx = i
            max_priority = queue.tasks.data[i].priority
        }
        i = i + 1
    }
    
    task := queue.tasks.data[max_priority_idx]
    
    j := max_priority_idx
    for j < queue.tasks.len() - 1 {
        queue.tasks.data[j] = queue.tasks.data[j + 1]
        j = j + 1
    }
    
    option::some(task)
}

func get_queue_size(queue: &task_queue) int {
    queue.tasks.len()
}

func update_task_status(queue: &mut task_queue, task_id: int64, status: int) bool {
    i := 0
    for i < queue.tasks.len() {
        if queue.tasks.data[i].task_id == task_id {
            queue.tasks.data[i].status = status
            return true
        }
        i = i + 1
    }
    false
}

func get_task_status(queue: &task_queue, task_id: int64) int {
    i := 0
    for i < queue.tasks.len() {
        if queue.tasks.data[i].task_id == task_id {
            return queue.tasks.data[i].status
        }
        i = i + 1
    }
    -1
}

func clear_queue(queue: &mut task_queue) {
    queue.tasks = vec[inference_task]()
}

func get_scheduler_stats(queue: &task_queue) scheduler_stats {
    pending := 0
    running := 0
    
    i := 0
    for i < queue.tasks.len() {
        if queue.tasks.data[i].status == 0 {
            pending = pending + 1
        } else if queue.tasks.data[i].status == 1 {
            running = running + 1
        }
        i = i + 1
    }
    
    stats := scheduler_stats {
        total_tasks: queue.tasks.len(),
        pending_tasks: pending,
        running_tasks: running,
        completed_tasks: 0
    }
    stats
}

func reorder_by_priority(queue: &mut task_queue) {
    i := 0
    for i < queue.tasks.len() - 1 {
        j := 0
        for j < queue.tasks.len() - 1 - i {
            if queue.tasks.data[j].priority < queue.tasks.data[j + 1].priority {
                temp := queue.tasks.data[j]
                queue.tasks.data[j] = queue.tasks.data[j + 1]
                queue.tasks.data[j + 1] = temp
            }
            j = j + 1
        }
        i = i + 1
    }
}
