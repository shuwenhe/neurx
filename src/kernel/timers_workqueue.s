package neurx.kernel

use std.slices

// 定时器结构
struct timer {
    int timer_id
    int owner_pid
    int expire_time  // ms
    int interval  // ms, 0 表示一次性
    int enabled
    int fired_count
}

// 定时器管理器
struct timer_manager {
    timer[] timers
    int current_time  // ms
    int next_timer_id
}

// 初始化定时器管理器
func (timer_manager* tm) init() (int, string) {
    tm.timers = timer[]{}
    tm.current_time = 0
    tm.next_timer_id = 0
    return 0, ""
}

// 创建定时器
func (timer_manager* tm) create_timer(int owner_pid, int expire_time, int interval) (timer, string) {
    if expire_time <= 0 {
        return timer{}, "Invalid expiration time"
    }
    
    t := timer{
        timer_id: tm.next_timer_id,
        owner_pid: owner_pid,
        expire_time: expire_time,
        interval: interval,
        enabled: 1,
        fired_count: 0
    }
    
    tm.timers = append(tm.timers, t)
    tm.next_timer_id = tm.next_timer_id + 1
    
    return t, ""
}

// 删除定时器
func (timer_manager* tm) delete_timer(int timer_id) (int, string) {
    i := 0
    for i < len(tm.timers) {
        t := tm.timers[i]
        if t.timer_id == timer_id {
            t.enabled = 0
            tm.timers[i] = t
            return 0, ""
        }
        i = i + 1
    }
    
    return -1, "Timer not found"
}

// 更新时间并检查过期的定时器
func (timer_manager* tm) tick(int delta_time) (vec, string) {
    tm.current_time = tm.current_time + delta_time
    expired_timers := {}
    
    i := 0
    for i < len(tm.timers) {
        t := tm.timers[i]
        
        if t.enabled == 1 && tm.current_time >= t.expire_time {
            t.fired_count = t.fired_count + 1
            expired_timers = append(expired_timers, t)
            
            // 如果是周期定时器，重新设置过期时间
            if t.interval > 0 {
                t.expire_time = t.expire_time + t.interval
            } else {
                t.enabled = 0  // 一次性定时器，禁用
            }
        }
        
        tm.timers[i] = t
        i = i + 1
    }
    
    return expired_timers, ""
}

// 获取定时器统计
func (timer_manager tm) get_timer_stats() (int, int) {
    active_timers := 0
    total_fired := 0
    
    i := 0
    for i < len(tm.timers) {
        t := tm.timers[i]
        if t.enabled == 1 {
            active_timers = active_timers + 1
        }
        total_fired = total_fired + t.fired_count
        i = i + 1
    }
    
    return active_timers, total_fired
}

// 工作队列项
struct work_item {
    int work_id
    int worker_pid
    int queue_id
    int priority
    int status  // 0=pending, 1=running, 2=completed
}

// 工作队列
struct workqueue {
    int queue_id
    work_item[] work_items
    int max_workers
    int active_workers
}

// 工作队列管理器
struct workqueue_manager {
    workqueue[] workqueues
    int next_queue_id
}

// 初始化工作队列管理器
func (workqueue_manager* wqm) init() (int, string) {
    wqm.workqueues = {}
    wqm.next_queue_id = 0
    return 0, ""
}

// 创建工作队列
func (workqueue_manager* wqm) create_workqueue(int max_workers) (workqueue, string) {
    wq := workqueue{
        queue_id: wqm.next_queue_id,
        work_items: {},
        max_workers: max_workers,
        active_workers: 0
    }
    
    wqm.workqueues = append(wqm.workqueues, wq)
    wqm.next_queue_id = wqm.next_queue_id + 1
    
    return wq, ""
}

// 队列工作项
func (workqueue_manager* wqm) queue_work(int queue_id, int priority) (int, string) {
    if queue_id >= len(wqm.workqueues) {
        return -1, "Invalid queue"
    }
    
    wq := wqm.workqueues[queue_id]
    
    work := work_item{
        work_id: len(wq.work_items),
        worker_pid: 0,
        queue_id: queue_id,
        priority: priority,
        status: 0  // pending
    }
    
    wq.work_items = append(wq.work_items, work)
    wqm.workqueues[queue_id] = wq
    
    return work.work_id, ""
}

// 获取下一个工作项
func (workqueue_manager* wqm) get_work(int queue_id) (work_item, string) {
    if queue_id >= len(wqm.workqueues) {
        return work_item{}, "Invalid queue"
    }
    
    wq := wqm.workqueues[queue_id]
    
    if len(wq.work_items) == 0 {
        return work_item{}, "No work items"
    }
    
    work := wq.work_items[0]
    work.status = 1  // running
    
    // 移除第一个项目
    i := 1
    for i < len(wq.work_items) {
        wq.work_items[i - 1] = wq.work_items[i]
        i = i + 1
    }
    
    wqm.workqueues[queue_id] = wq
    
    return work, ""
}

// 完成工作项
func (workqueue_manager* wqm) complete_work(int queue_id, int work_id) (int, string) {
    if queue_id >= len(wqm.workqueues) {
        return -1, "Invalid queue"
    }
    
    // 工作项已在 get_work 中移除，标记为完成
    return 0, ""
}

// 获取工作队列统计
func (workqueue_manager wqm) get_workqueue_stats(int queue_id) (int, int) {
    if queue_id >= len(wqm.workqueues) {
        return 0, 0
    }
    
    wq := wqm.workqueues[queue_id]
    return len(wq.work_items), wq.active_workers
}
