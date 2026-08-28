package neurx.ipc
use std.slices
struct semaphore {
    int sem_id
    int value
    int owner_pid
    int wait_count
    int[] waiters  
}

struct semaphore_set {
    semaphore[] semaphores
    int total_sems
}

func (semaphore_set* ss) init(int max_sems) (int, string) {
    ss.semaphores = semaphore[]{}
    ss.total_sems = max_sems
    return 0, ""
}

func (semaphore_set* ss) create_semaphore(int initial_value) (semaphore, string) {
    if len(ss.semaphores) >= ss.total_sems {
        return semaphore{}, "Semaphore set full"
    }
    sem := semaphore{
        sem_id: len(ss.semaphores),
        value: initial_value,
        owner_pid: 0,
        wait_count: 0,
        waiters: int[]{}
    }
    ss.semaphores = append(ss.semaphores, sem)
    return sem, ""
}

func (semaphore_set* ss) wait_semaphore(int sem_id, int pid) (int, string) {
    if sem_id >= len(ss.semaphores) {
        return -1, "Invalid semaphore"
    }
    sem := ss.semaphores[sem_id]
    if sem.value > 0 {
        sem.value = sem.value - 1
        ss.semaphores[sem_id] = sem
        return 0, ""
    }
    sem.wait_count = sem.wait_count + 1
    sem.waiters = append(sem.waiters, pid)
    ss.semaphores[sem_id] = sem
    return 1, "BLOCKED"  
}

func (semaphore_set* ss) signal_semaphore(int sem_id) (int, string) {
    if sem_id >= len(ss.semaphores) {
        return -1, "Invalid semaphore"
    }
    sem := ss.semaphores[sem_id]
    sem.value = sem.value + 1
    if sem.wait_count > 0 && len(sem.waiters) > 0 {
        woken_pid := sem.waiters[0]
        i := 1
        for i < len(sem.waiters) {
            sem.waiters[i - 1] = sem.waiters[i]
            i = i + 1
        }
        sem.wait_count = sem.wait_count - 1
    }
    ss.semaphores[sem_id] = sem
    return 0, ""
}

func (semaphore_set ss) get_semaphore_value(int sem_id) (int, string) {
    if sem_id >= len(ss.semaphores) {
        return 0, "Invalid semaphore"
    }
    sem := ss.semaphores[sem_id]
    return sem.value, ""
}

struct message {
    int msg_id
    int sender_pid
    string content
    int timestamp
    int priority
}

struct message_queue {
    int queue_id
    message[] messages
    int max_messages
    int receiver_pid
    int sender_pid
}

struct message_queue_manager {
    message_queue[] queues
    int next_queue_id
}

func (message_queue_manager* mqm) init() (int, string) {
    mqm.queues = message_queue[]{}
    mqm.next_queue_id = 0
    return 0, ""
}

func (message_queue_manager* mqm) create_queue(int max_msgs) (message_queue, string) {
    mq := message_queue{
        queue_id: mqm.next_queue_id,
        messages: message[]{},
        max_messages: max_msgs,
        receiver_pid: 0,
        sender_pid: 0
    }
    mqm.queues = append(mqm.queues, mq)
    mqm.next_queue_id = mqm.next_queue_id + 1
    return mq, ""
}

func (message_queue_manager* mqm) send_message(int queue_id, int sender_pid, string content, int priority) (int, string) {
    if queue_id >= len(mqm.queues) {
        return -1, "Invalid queue"
    }
    mq := mqm.queues[queue_id]
    if len(mq.messages) >= mq.max_messages {
        return -1, "Queue full"
    }
    msg := message{
        msg_id: len(mq.messages),
        sender_pid: sender_pid,
        content: content,
        timestamp: 0,
        priority priority
    }
    mq.messages = append(mq.messages, msg)
    mqm.queues[queue_id] = mq
    return msg.msg_id, ""
}

func (message_queue_manager* mqm) receive_message(int queue_id) (message, string) {
    if queue_id >= len(mqm.queues) {
        return message{}, "Invalid queue"
    }
    mq := mqm.queues[queue_id]
    if len(mq.messages) == 0 {
        return message{}, "Queue empty"
    }
    msg := mq.messages[0]
    i := 1
    for i < len(mq.messages) {
        mq.messages[i - 1] = mq.messages[i]
        i = i + 1
    }
    mqm.queues[queue_id] = mq
    return msg, ""
}

struct shared_memory_segment {
    int shmid
    int size
    int owner_pid
    int attach_count
    int* memory_ptr
    int permissions  
}

struct shared_memory_manager {
    shared_memory_segment[] segments
    int next_shmid
}

func (shared_memory_manager* smm) init() (int, string) {
    smm.segments = shared_memory_segment[]{}"
    smm.next_shmid = 0
    return 0, ""
}

func (shared_memory_manager* smm) create_shared_memory(int size) (shared_memory_segment, string) {
    shm := shared_memory_segment{
        shmid: smm.next_shmid,
        size: size,
        owner_pid: 0,
        attach_count: 0,
        memory_ptr: new int[size / 4],
        permissions: 3
    }
    smm.segments = append(smm.segments, shm)
    smm.next_shmid = smm.next_shmid + 1
    return shm, ""
}

func (shared_memory_manager* smm) attach_shared_memory(int shmid) (int, string) {
    if shmid >= len(smm.segments) {
        return -1, "Invalid shared memory"
    }
    seg := smm.segments[shmid]
    seg.attach_count = seg.attach_count + 1
    smm.segments[shmid] = seg
    return shmid, ""
}

func (shared_memory_manager* smm) detach_shared_memory(int shmid) (int, string) {
    if shmid >= len(smm.segments) {
        return -1, "Invalid shared memory"
    }
    seg := smm.segments[shmid]
    if seg.attach_count > 0 {
        seg.attach_count = seg.attach_count - 1
    }
    smm.segments[shmid] = seg
    return 0, ""
}

func (shared_memory_manager* smm) remove_shared_memory(int shmid) (int, string) {
    if shmid >= len(smm.segments) {
        return -1, "Invalid shared memory"
    }
    seg := smm.segments[shmid]
    if seg.attach_count > 0 {
        return -1, "Shared memory still attached"
    }
    seg.shmid = -1  
    smm.segments[shmid] = seg
    return 0, ""
}

func (shared_memory_manager smm) get_shm_stats() (int, int) {
    total_attached := 0
    total_size := 0
    i := 0
    for i < len(smm.segments) {
        seg := smm.segments[i]
        if seg.shmid >= 0 {
            total_attached = total_attached + seg.attach_count
            total_size = total_size + seg.size
        }
        i = i + 1
    }
    return total_attached, total_size
}
