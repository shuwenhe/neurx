package neurx.kernel

use std.slices


struct cpu_affinity {
    int cpu_mask  
    int cpu_id
    int preferred_cpu
}


struct task {
    int task_id
    string name
    int priority  
    int cpu_affinity_mask
    int assigned_cpu
    int runtime  
    int state  
}


struct cpu_scheduler {
    task[] run_queue
    task[] blocked_queue
    int num_cpus
    int current_task_id
}


func (cpu_scheduler* sched) init(int num_cpus) (int, string) {
    sched.run_queue = {}
    sched.blocked_queue = {}
    sched.num_cpus = num_cpus
    sched.current_task_id = 0
    return 0, ""
}


func (cpu_scheduler* sched) create_task(string name, int priority) (task, string) {
    new_task := task{
        task_id: sched.current_task_id,
        name: name,
        priority: priority,
        cpu_affinity_mask: 255,  
        assigned_cpu: -1,
        runtime: 0,
        state: 0  
    }
    
    sched.current_task_id = sched.current_task_id + 1
    sched.run_queue = append(sched.run_queue, new_task)
    
    return new_task, ""
}


func (cpu_scheduler* sched) set_affinity(int task_id, int cpu_mask) (int, string) {
    i := 0
    for i < len(sched.run_queue) {
        t := sched.run_queue[i]
        if t.task_id == task_id {
            t.cpu_affinity_mask = cpu_mask
            sched.run_queue[i] = t
            return 0, ""
        }
        i = i + 1
    }
    return -1, "Task not found"
}


func (cpu_scheduler* sched) select_cpu_for_task(int task_id) (int, string) {
    i := 0
    for i < len(sched.run_queue) {
        t := sched.run_queue[i]
        if t.task_id == task_id {
            cpu_mask := t.cpu_affinity_mask
            cpu_id := 0
            
            j := 0
            for j < sched.num_cpus {
                if cpu_mask & (1 << j) != 0 {
                    cpu_id = j
                    break
                }
                j = j + 1
            }
            
            t.assigned_cpu = cpu_id
            sched.run_queue[i] = t
            return cpu_id, ""
        }
        i = i + 1
    }
    return -1, "Task not found"
}


func (cpu_scheduler* sched) schedule() (task, string) {
    if len(sched.run_queue) == 0 {
        return task{}, "No runnable tasks"
    }
    
    
    next_task := sched.run_queue[0]
    
    
    next_task.state = 1  
    next_task.runtime = next_task.runtime + 10  
    
    
    i := 1
    for i < len(sched.run_queue) {
        sched.run_queue[i - 1] = sched.run_queue[i]
        i = i + 1
    }
    sched.run_queue[len(sched.run_queue) - 1] = next_task
    
    return next_task, ""
}


func (cpu_scheduler* sched) block_task(int task_id) (int, string) {
    i := 0
    for i < len(sched.run_queue) {
        t := sched.run_queue[i]
        if t.task_id == task_id {
            t.state = 2  
            sched.blocked_queue = append(sched.blocked_queue, t)
            
            
            j := i
            for j < len(sched.run_queue) - 1 {
                sched.run_queue[j] = sched.run_queue[j + 1]
                j = j + 1
            }
            return 0, ""
        }
        i = i + 1
    }
    return -1, "Task not found"
}


func (cpu_scheduler* sched) wake_task(int task_id) (int, string) {
    i := 0
    for i < len(sched.blocked_queue) {
        t := sched.blocked_queue[i]
        if t.task_id == task_id {
            t.state = 0  
            sched.run_queue = append(sched.run_queue, t)
            
            
            j := i
            for j < len(sched.blocked_queue) - 1 {
                sched.blocked_queue[j] = sched.blocked_queue[j + 1]
                j = j + 1
            }
            return 0, ""
        }
        i = i + 1
    }
    return -1, "Task not found"
}


func (cpu_scheduler sched) get_stats() (int, int) {
    return len(sched.run_queue), len(sched.blocked_queue)
}


func (cpu_scheduler sched) get_task_info(int task_id) (int, int, int, string) {
    i := 0
    for i < len(sched.run_queue) {
        t := sched.run_queue[i]
        if t.task_id == task_id {
            return t.priority, t.assigned_cpu, t.runtime, t.name
        }
        i = i + 1
    }
    return 0, 0, 0, "Task not found"
}
