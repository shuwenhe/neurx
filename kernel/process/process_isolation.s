package neurx.kernel.process

func PROCESS_OK() int { 0 }
func PROCESS_NOT_FOUND() int { 1 }
func PROCESS_PERMISSION_DENIED() int { 2 }
func PROCESS_LIMIT() int { 3 }
func PROCESS_INVALID_NAMESPACE() int { 4 }

struct process_isolation {
    int namespace_count
    [64]int namespace_id
    [64]int parent_namespace
    [64]int user_namespace
    [64]int pid_namespace
    [64]int mount_namespace
    [64]int network_namespace
    int next_namespace_component

    int process_count
    [1024]int pid
    [1024]int parent_pid
    [1024]int namespace_id_for_process
    [1024]int uid
    [1024]int gid
    [1024]bool cap_sys_admin
    [1024]bool cap_net_admin
    [1024]bool cap_accelerator
    [1024]int resource_domain
    [1024]int scheduler_task
    [1024]bool runnable
    int last_result
}

func process_isolation_create() process_isolation {
    isolation := process_isolation {
        namespace_count: 1,
        namespace_id: [64]int{}, parent_namespace: [64]int{},
        user_namespace: [64]int{}, pid_namespace: [64]int{},
        mount_namespace: [64]int{}, network_namespace: [64]int{},
        next_namespace_component: 2,
        process_count: 1,
        pid: [1024]int{}, parent_pid: [1024]int{},
        namespace_id_for_process: [1024]int{}, uid: [1024]int{}, gid: [1024]int{},
        cap_sys_admin: [1024]bool{}, cap_net_admin: [1024]bool{},
        cap_accelerator: [1024]bool{}, resource_domain: [1024]int{},
        scheduler_task: [1024]int{}, runnable: [1024]bool{},
        last_result: PROCESS_OK()
    }
    isolation.namespace_id[0] = 1
    isolation.parent_namespace[0] = 0
    isolation.user_namespace[0] = 1
    isolation.pid_namespace[0] = 1
    isolation.mount_namespace[0] = 1
    isolation.network_namespace[0] = 1
    isolation.pid[0] = 1
    isolation.parent_pid[0] = 0
    isolation.namespace_id_for_process[0] = 1
    isolation.uid[0] = 0
    isolation.gid[0] = 0
    isolation.cap_sys_admin[0] = true
    isolation.cap_net_admin[0] = true
    isolation.cap_accelerator[0] = true
    isolation.resource_domain[0] = 0
    isolation.scheduler_task[0] = 1
    isolation.runnable[0] = true
    return isolation
}

func find_namespace(process_isolation isolation, int id) int {
    int i = 0
    for i < isolation.namespace_count {
        if isolation.namespace_id[i] == id { return i }
        i = i + 1
    }
    return -1
}

func find_process(process_isolation isolation, int pid) int {
    int i = 0
    for i < isolation.process_count {
        if isolation.pid[i] == pid { return i }
        i = i + 1
    }
    return -1
}

func clone_namespace(process_isolation isolation, int id, int parent,
                     bool new_user, bool new_pid, bool new_mount,
                     bool new_network) process_isolation {
    parent_slot := find_namespace(isolation, parent)
    if parent_slot < 0 || isolation.namespace_count >= 64 {
        isolation.last_result = PROCESS_INVALID_NAMESPACE()
        return isolation
    }
    slot := isolation.namespace_count
    isolation.namespace_id[slot] = id
    isolation.parent_namespace[slot] = parent
    isolation.user_namespace[slot] = isolation.user_namespace[parent_slot]
    isolation.pid_namespace[slot] = isolation.pid_namespace[parent_slot]
    isolation.mount_namespace[slot] = isolation.mount_namespace[parent_slot]
    isolation.network_namespace[slot] = isolation.network_namespace[parent_slot]
    if new_user { isolation.user_namespace[slot] = isolation.next_namespace_component; isolation.next_namespace_component = isolation.next_namespace_component + 1 }
    if new_pid { isolation.pid_namespace[slot] = isolation.next_namespace_component; isolation.next_namespace_component = isolation.next_namespace_component + 1 }
    if new_mount { isolation.mount_namespace[slot] = isolation.next_namespace_component; isolation.next_namespace_component = isolation.next_namespace_component + 1 }
    if new_network { isolation.network_namespace[slot] = isolation.next_namespace_component; isolation.next_namespace_component = isolation.next_namespace_component + 1 }
    isolation.namespace_count = isolation.namespace_count + 1
    isolation.last_result = PROCESS_OK()
    return isolation
}

func spawn_isolated_process(process_isolation isolation, int pid, int parent_pid,
                            int namespace_id, int domain, int scheduler_task,
                            int child_uid, int child_gid) process_isolation {
    parent := find_process(isolation, parent_pid)
    if parent < 0 || find_namespace(isolation, namespace_id) < 0 {
        isolation.last_result = PROCESS_INVALID_NAMESPACE()
        return isolation
    }
    if isolation.process_count >= 1024 || find_process(isolation, pid) >= 0 {
        isolation.last_result = PROCESS_LIMIT()
        return isolation
    }
    slot := isolation.process_count
    isolation.pid[slot] = pid
    isolation.parent_pid[slot] = parent_pid
    isolation.namespace_id_for_process[slot] = namespace_id
    isolation.uid[slot] = child_uid
    isolation.gid[slot] = child_gid
    isolation.cap_sys_admin[slot] = false
    isolation.cap_net_admin[slot] = false
    isolation.cap_accelerator[slot] = false
    isolation.resource_domain[slot] = domain
    isolation.scheduler_task[slot] = scheduler_task
    isolation.runnable[slot] = true
    isolation.process_count = isolation.process_count + 1
    isolation.last_result = PROCESS_OK()
    return isolation
}

func grant_capabilities(process_isolation isolation, int actor_pid, int target_pid,
                        bool sys_admin, bool net_admin, bool accelerator) process_isolation {
    actor := find_process(isolation, actor_pid)
    target := find_process(isolation, target_pid)
    if actor < 0 || target < 0 || !isolation.cap_sys_admin[actor] {
        isolation.last_result = PROCESS_PERMISSION_DENIED()
        return isolation
    }
    isolation.cap_sys_admin[target] = sys_admin
    isolation.cap_net_admin[target] = net_admin
    isolation.cap_accelerator[target] = accelerator
    isolation.last_result = PROCESS_OK()
    return isolation
}

func may_manage_network(process_isolation isolation, int pid, int namespace_id) bool {
    slot := find_process(isolation, pid)
    if slot < 0 || !isolation.cap_net_admin[slot] { return false }
    return isolation.namespace_id_for_process[slot] == namespace_id
}

func may_use_accelerator(process_isolation isolation, int pid, int domain) bool {
    slot := find_process(isolation, pid)
    if slot < 0 || !isolation.cap_accelerator[slot] { return false }
    return isolation.resource_domain[slot] == domain
}
