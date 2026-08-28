struct ipc_message {
    int    msg_id
    int    from_pid
    int    to_pid
    string msg_type
    string payload
    int    sent_at_ms
}
struct msg_queue {
    int            qid
    string         name
    []ipc_message  messages
    int            max_depth
}
struct ipc_state {
    []msg_queue  queues
    int          next_qid
    int          next_msg_id
}
func new_ipc_state() ipc_state {
    return ipc_state{queues: [], next_qid: 1, next_msg_id: 1}
}
func msgget(is ipc_state, string name, int max_depth) (ipc_state, int) {
    int i = 0
    for i < len(is.queues) {
        if is.queues[i].name == name {
            return is, is.queues[i].qid
        }
        i = i + 1
    }
    msg_queue q = msg_queue{qid: is.next_qid, name: name, messages: [], max_depth: max_depth}
    is.queues = append(is.queues, q)
    int qid = is.next_qid
    is.next_qid = is.next_qid + 1
    return is, qid
}
func msgsnd(is ipc_state, int qid, int from_pid, int to_pid, string msg_type, string payload) ipc_state {
    int i = 0
    for i < len(is.queues) {
        if is.queues[i].qid == qid {
            ipc_message m = ipc_message{
                msg_id:    is.next_msg_id,
                from_pid:  from_pid,
                to_pid:    to_pid,
                msg_type:  msg_type,
                payload:   payload,
                sent_at_ms: 0,
            }
            is.queues[i].messages = append(is.queues[i].messages, m)
            is.next_msg_id = is.next_msg_id + 1
        }
        i = i + 1
    }
    return is
}
func msgrcv(is ipc_state, int qid, int to_pid) (ipc_state, ipc_message, bool) {
    int qi = 0
    for qi < len(is.queues) {
        if is.queues[qi].qid == qid {
            int mi = 0
            for mi < len(is.queues[qi].messages) {
                ipc_message m = is.queues[qi].messages[mi]
                if m.to_pid == to_pid || m.to_pid == -1 {
                    []ipc_message remaining = []
                    int k = 0
                    for k < len(is.queues[qi].messages) {
                        if k != mi {
                            remaining = append(remaining, is.queues[qi].messages[k])
                        }
                        k = k + 1
                    }
                    is.queues[qi].messages = remaining
                    return is, m, true
                }
                mi = mi + 1
            }
        }
        qi = qi + 1
    }
    return is, ipc_message{}, false
}
struct semaphore {
    int    sem_id
    string name
    int    value
    int    max_value
}
struct sem_state {
    []semaphore sems
    int         next_sem_id
}
func new_sem_state() sem_state {
    return sem_state{sems: [], next_sem_id: 1}
}
func sem_create(ss sem_state, string name, int initial, int max_val) (sem_state, int) {
    semaphore s = semaphore{sem_id: ss.next_sem_id, name: name, value: initial, max_value: max_val}
    ss.sems = append(ss.sems, s)
    int id = ss.next_sem_id
    ss.next_sem_id = ss.next_sem_id + 1
    return ss, id
}
func sem_down(ss sem_state, int sem_id) (sem_state, bool) {
    int i = 0
    for i < len(ss.sems) {
        if ss.sems[i].sem_id == sem_id {
            if ss.sems[i].value > 0 {
                ss.sems[i].value = ss.sems[i].value - 1
                return ss, true
            }
            return ss, false
        }
        i = i + 1
    }
    return ss, false
}
func sem_up(ss sem_state, int sem_id) sem_state {
    int i = 0
    for i < len(ss.sems) {
        if ss.sems[i].sem_id == sem_id {
            if ss.sems[i].value < ss.sems[i].max_value {
                ss.sems[i].value = ss.sems[i].value + 1
            }
        }
        i = i + 1
    }
    return ss
}
