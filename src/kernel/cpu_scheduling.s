package neurx.kernel

use std.slices

// CPU 亲和性掩码
struct cpu_affinity {
    int cpu_mask  // 位掩码表示 CPU 核心
    int cpu_id
    int preferred_cpu
}

// 进程/任务结构
struct task {
    int task_id
    string name
    int priority  // 0-139, 100=normal
    int cpu_affinity_mask
    int assigned_cpu
    int runtime  // ms
    int state  // 0=runnable, 1=running, 2=blocked
}

// CPU 调度器
struct cpu_scheduler {
    task[] run_queue
    task[] blocked_queue
    int num_cpus
    int current_task_id
}

// 初始化 CPU 调度器
func (cpu_scheduler* sched) init(int num_cpus) (int, string) {
    sched.run_queue = {}
    sched.blocked_queue = {}
    sched.num_cpus = num_cpus
    sched.current_task_id = 0
    return 0, ""
}

// 创建任务
func (cpu_scheduler* sched) create_task(string name, int priority) (task, string) {
    new_task := task{
        task_id: sched.current_task_id,
        name: name,
        priority: priority,
        cpu_affinity_mask: 255,  // 所有 CPU 都可用
        assigned_cpu: -1,
        runtime: 0,
        state: 0  // runnable
    }
    
    sched.current_task_id = sched.current_task_id + 1
    sched.run_queue = append(sched.run_queue, new_task)
    
    return new_task, ""
}

// 设置 CPU 亲和性
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

// 选择最合适的 CPU
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

// 调度 (CFS - Completely Fair Scheduler)
func (cpu_scheduler* sched) schedule() (task, string) {
    if len(sched.run_queue) == 0 {
        return task{}, "No runnable tasks"
    }
    
    // 简单轮转调度
    next_task := sched.run_queue[0]
    
    // 更新任务状态
    next_task.state = 1  // running
    next_task.runtime = next_task.runtime + 10  // 10ms 时间片
    
    // 将任务移到队列末尾
    i := 1
    for i < len(sched.run_queue) {
        sched.run_queue[i - 1] = sched.run_queue[i]
        i = i + 1
    }
    sched.run_queue[len(sched.run_queue) - 1] = next_task
    
    return next_task, ""
}

// 阻塞任务
func (cpu_scheduler* sched) block_task(int task_id) (int, string) {
    i := 0
    for i < len(sched.run_queue) {
        t := sched.run_queue[i]
        if t.task_id == task_id {
            t.state = 2  // blocked
            sched.blocked_queue = append(sched.blocked_queue, t)
            
            // 从运行队列移除
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

// 唤醒任务
func (cpu_scheduler* sched) wake_task(int task_id) (int, string) {
    i := 0
    for i < len(sched.blocked_queue) {
        t := sched.blocked_queue[i]
        if t.task_id == task_id {
            t.state = 0  // runnable
            sched.run_queue = append(sched.run_queue, t)
            
            // 从阻塞队列移除
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

// 获取调度统计
func (cpu_scheduler sched) get_stats() (int, int) {
    return len(sched.run_queue), len(sched.blocked_queue)
}

// 获取任务优先级和亲和性
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
