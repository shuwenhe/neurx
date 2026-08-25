package neurx.kernel.ipc

use std.vec.vec as std_vec

struct message {
    msg_type: int
    sender_pid: int
    data_len: int
    payload: string
}

struct msg_queue {
    queue_id: int
    messages: vec[message]
    max_size: int
    creator_pid: int
    created_at: int
}

func msg_queue_create(int id, int max_msgs) msg_queue {
    queue := msg_queue {
        queue_id: id,
        messages: std_vec[message](),
        max_size: max_msgs,
        creator_pid: 1,
        created_at: 0
    }
    queue
}

func (msg_queue* mq) msg_send(message msg) int {    if mq.messages.len() >= mq.max_size {
        -1
    } else {
        mq.messages.push(msg)
        mq.messages.len() - 1
    }
}

func (msg_queue* mq) msg_receive(int msg_type) message {    i := 0
    empty_msg := message {
        msg_type: 0,
        sender_pid: 0,
        data_len: 0,
        payload: ""
    }
    
    while i < mq.messages.len() {
        msg := mq.messages[i]
        if msg.msg_type == msg_type {
            mq.messages[i] = empty_msg
            msg
        } else {
            i = i + 1
        }
    }
    
    empty_msg
}

struct semaphore {
    sem_id: int
    value: int
    owner_pid: int
}

func semaphore_create(int id, int initial_value) semaphore {
    sem := semaphore {
        sem_id: id,
        value: initial_value,
        owner_pid: 1
    }
    sem
}

func (semaphore* sem) sem_wait() int {    if sem.value > 0 {
        sem.value = sem.value - 1
        0
    } else {
        -1
    }
}

func (semaphore* sem) sem_post() int {    sem.value = sem.value + 1
    0
}

func (semaphore* sem) sem_getvalue() int {    sem.value
}

struct shared_memory {
    shm_id: int
    size: int
    address: int
    owner_pid: int
    attach_count: int
}

func shm_create(int id, int size) shared_memory {
    shm := shared_memory {
        shm_id: id,
        size: size,
        address: id * 4096,
        owner_pid: 1,
        attach_count: 0
    }
    shm
}

func (shared_memory* shm) shm_attach() int {    shm.attach_count = shm.attach_count + 1
    shm.address
}

func (shared_memory* shm) shm_detach() int {    if shm.attach_count > 0 {
        shm.attach_count = shm.attach_count - 1
        0
    } else {
        -1
    }
}

func (shared_memory* shm) shm_get_size() int {    shm.size
}

struct ipc_subsystem {
    msg_queues: vec[msg_queue]
    semaphores: vec[semaphore]
    shared_mems: vec[shared_memory]
}

func ipc_subsystem_init() ipc_subsystem {
    ipc := ipc_subsystem {
        msg_queues: std_vec[msg_queue](),
        semaphores: std_vec[semaphore](),
        shared_mems: std_vec[shared_memory]()
    }
    ipc
}

func (ipc_subsystem* ipc) ipc_get_status() int {    status := ipc.msg_queues.len() + ipc.semaphores.len() + ipc.shared_mems.len()
    status
}
