package neurx.ipc

use std.vec.vec

// 信号量结构
struct semaphore {
    int sem_id
    int value
    int owner_pid
    int wait_count
    vec waiters  // 等待的进程 ID
}

// 信号量集合
struct semaphore_set {
    vec semaphores
    int total_sems
}

// 初始化信号量集合
func (semaphore_set* ss) init(int max_sems) (int, string) {
    ss.semaphores = vec()
    ss.total_sems = max_sems
    return 0, ""
}

// 创建信号量
func (semaphore_set* ss) create_semaphore(int initial_value) (semaphore, string) {
    if ss.semaphores.len() >= ss.total_sems {
        return semaphore{}, "Semaphore set full"
    }
    
    sem := semaphore{
        sem_id: ss.semaphores.len(),
        value: initial_value,
        owner_pid: 0,
        wait_count: 0,
        waiters: vec()
    }
    
    ss.semaphores.push(sem)
    return sem, ""
}

// P 操作 (等待/减少)
func (semaphore_set* ss) wait_semaphore(int sem_id, int pid) (int, string) {
    if sem_id >= ss.semaphores.len() {
        return -1, "Invalid semaphore"
    }
    
    sem := ss.semaphores[sem_id]
    
    if sem.value > 0 {
        sem.value = sem.value - 1
        ss.semaphores[sem_id] = sem
        return 0, ""
    }
    
    // 进程需要阻塞，加入等待队列
    sem.wait_count = sem.wait_count + 1
    sem.waiters.push(pid)
    ss.semaphores[sem_id] = sem
    return 1, "BLOCKED"  // 返回 1 表示进程应该被阻塞
}

// V 操作 (释放/增加)
func (semaphore_set* ss) signal_semaphore(int sem_id) (int, string) {
    if sem_id >= ss.semaphores.len() {
        return -1, "Invalid semaphore"
    }
    
    sem := ss.semaphores[sem_id]
    sem.value = sem.value + 1
    
    // 唤醒一个等待的进程
    if sem.wait_count > 0 && sem.waiters.len() > 0 {
        woken_pid := sem.waiters[0]
        
        // 移除第一个元素
        i := 1
        for i < sem.waiters.len() {
            sem.waiters[i - 1] = sem.waiters[i]
            i = i + 1
        }
        
        sem.wait_count = sem.wait_count - 1
    }
    
    ss.semaphores[sem_id] = sem
    return 0, ""
}

// 获取信号量值
func (semaphore_set ss) get_semaphore_value(int sem_id) (int, string) {
    if sem_id >= ss.semaphores.len() {
        return 0, "Invalid semaphore"
    }
    
    sem := ss.semaphores[sem_id]
    return sem.value, ""
}

// 消息队列结构
struct message {
    int msg_id
    int sender_pid
    string content
    int timestamp
    int priority
}

// 消息队列
struct message_queue {
    int queue_id
    vec messages
    int max_messages
    int receiver_pid
    int sender_pid
}

// 消息队列管理器
struct message_queue_manager {
    vec queues
    int next_queue_id
}

// 初始化消息队列管理器
func (message_queue_manager* mqm) init() (int, string) {
    mqm.queues = vec()
    mqm.next_queue_id = 0
    return 0, ""
}

// 创建消息队列
func (message_queue_manager* mqm) create_queue(int max_msgs) (message_queue, string) {
    mq := message_queue{
        queue_id: mqm.next_queue_id,
        messages: vec(),
        max_messages: max_msgs,
        receiver_pid: 0,
        sender_pid: 0
    }
    
    mqm.queues.push(mq)
    mqm.next_queue_id = mqm.next_queue_id + 1
    return mq, ""
}

// 发送消息
func (message_queue_manager* mqm) send_message(int queue_id, int sender_pid, string content, int priority) (int, string) {
    if queue_id >= mqm.queues.len() {
        return -1, "Invalid queue"
    }
    
    mq := mqm.queues[queue_id]
    
    if mq.messages.len() >= mq.max_messages {
        return -1, "Queue full"
    }
    
    msg := message{
        msg_id: mq.messages.len(),
        sender_pid: sender_pid,
        content: content,
        timestamp: 0,
        priority: priority
    }
    
    mq.messages.push(msg)
    mqm.queues[queue_id] = mq
    return msg.msg_id, ""
}

// 接收消息
func (message_queue_manager* mqm) receive_message(int queue_id) (message, string) {
    if queue_id >= mqm.queues.len() {
        return message{}, "Invalid queue"
    }
    
    mq := mqm.queues[queue_id]
    
    if mq.messages.len() == 0 {
        return message{}, "Queue empty"
    }
    
    msg := mq.messages[0]
    
    // 移除第一个消息
    i := 1
    for i < mq.messages.len() {
        mq.messages[i - 1] = mq.messages[i]
        i = i + 1
    }
    
    mqm.queues[queue_id] = mq
    return msg, ""
}

// 共享内存段
struct shared_memory_segment {
    int shmid
    int size
    int owner_pid
    int attach_count
    int* memory_ptr
    int permissions  // 0=read, 1=write, 2=execute
}

// 共享内存管理器
struct shared_memory_manager {
    vec segments
    int next_shmid
}

// 初始化共享内存管理器
func (shared_memory_manager* smm) init() (int, string) {
    smm.segments = vec()
    smm.next_shmid = 0
    return 0, ""
}

// 创建共享内存
func (shared_memory_manager* smm) create_shared_memory(int size) (shared_memory_segment, string) {
    shm := shared_memory_segment{
        shmid: smm.next_shmid,
        size: size,
        owner_pid: 0,
        attach_count: 0,
        memory_ptr: new int[size / 4],
        permissions: 3
    }
    
    smm.segments.push(shm)
    smm.next_shmid = smm.next_shmid + 1
    return shm, ""
}

// 挂载共享内存
func (shared_memory_manager* smm) attach_shared_memory(int shmid) (int, string) {
    if shmid >= smm.segments.len() {
        return -1, "Invalid shared memory"
    }
    
    seg := smm.segments[shmid]
    seg.attach_count = seg.attach_count + 1
    smm.segments[shmid] = seg
    
    return shmid, ""
}

// 卸载共享内存
func (shared_memory_manager* smm) detach_shared_memory(int shmid) (int, string) {
    if shmid >= smm.segments.len() {
        return -1, "Invalid shared memory"
    }
    
    seg := smm.segments[shmid]
    if seg.attach_count > 0 {
        seg.attach_count = seg.attach_count - 1
    }
    smm.segments[shmid] = seg
    
    return 0, ""
}

// 删除共享内存
func (shared_memory_manager* smm) remove_shared_memory(int shmid) (int, string) {
    if shmid >= smm.segments.len() {
        return -1, "Invalid shared memory"
    }
    
    seg := smm.segments[shmid]
    if seg.attach_count > 0 {
        return -1, "Shared memory still attached"
    }
    
    seg.shmid = -1  // 标记为删除
    smm.segments[shmid] = seg
    return 0, ""
}

// 获取共享内存统计
func (shared_memory_manager smm) get_shm_stats() (int, int) {
    total_attached := 0
    total_size := 0
    
    i := 0
    for i < smm.segments.len() {
        seg := smm.segments[i]
        if seg.shmid >= 0 {
            total_attached = total_attached + seg.attach_count
            total_size = total_size + seg.size
        }
        i = i + 1
    }
    
    return total_attached, total_size
}
