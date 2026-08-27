package neurx.sys.scheduler

use std.slices

struct inference_task {
    int64 task_id
    string model_id
    int batch_size
    int priority
    int device_id
    int status
}

struct task_queue {
    inference_task[] tasks
    int64 next_task_id
    int max_tasks
}

struct scheduler_stats {
    int total_tasks
    int pending_tasks
    int running_tasks
    int completed_tasks
}

func create_task_queue(max_tasks: int) task_queue {
    queue := task_queue {
        tasks: inference_task[](),
        next_task_id: 1,
        max_tasks max_tasks
    }
    queue
}

func enqueue_task(task_queue* queue, model_id: string, batch_size: int, priority: int, device_id: int) int64 {
    if len(queue.tasks) >= queue.max_tasks {
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
    queue.tasks = append(queue.tasks, task)
    task_id
}

func dequeue_task(task_queue* queue) option[inference_task] {
    if len(queue.tasks) == 0 {
        return nil
    }
    
    max_priority_idx := 0
    max_priority := queue.tasks.data[0].priority
    
    i := 1
    for i < len(queue.tasks) {
        if queue.tasks.data[i].priority > max_priority {
            max_priority_idx = i
            max_priority = queue.tasks.data[i].priority
        }
        i = i + 1
    }
    
    task := queue.tasks.data[max_priority_idx]
    
    j := max_priority_idx
    for j < len(queue.tasks) - 1 {
        queue.tasks.data[j] = queue.tasks.data[j + 1]
        j = j + 1
    }
    
    some(task)
}

func get_queue_size(task_queue* queue) int {
    len(queue.tasks)
}

func update_task_status(task_queue* queue, task_id: int64, status: int) bool {
    i := 0
    for i < len(queue.tasks) {
        if queue.tasks.data[i].task_id == task_id {
            queue.tasks.data[i].status = status
            return true
        }
        i = i + 1
    }
    false
}

func get_task_status(task_queue* queue, task_id: int64) int {
    i := 0
    for i < len(queue.tasks) {
        if queue.tasks.data[i].task_id == task_id {
            return queue.tasks.data[i].status
        }
        i = i + 1
    }
    -1
}

func clear_queue(task_queue* queue) {
    queue.tasks = inference_task[]()
}

func get_scheduler_stats(task_queue* queue) scheduler_stats {
    pending := 0
    running := 0
    
    i := 0
    for i < len(queue.tasks) {
        if queue.tasks.data[i].status == 0 {
            pending = pending + 1
        } else if queue.tasks.data[i].status == 1 {
            running = running + 1
        }
        i = i + 1
    }
    
    stats := scheduler_stats {
        total_tasks: len(queue.tasks),
        pending_tasks: pending,
        running_tasks: running,
        completed_tasks: 0
    }
    stats
}

func reorder_by_priority(task_queue* queue) {
    i := 0
    for i < len(queue.tasks) - 1 {
        j := 0
        for j < len(queue.tasks) - 1 - i {
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
