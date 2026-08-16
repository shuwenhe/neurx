package distributed

struct process_group {
    int group_id
    vec[int] ranks
    int world_size
    string name
    comm_backend backend
    bool initialized
}

struct process_group_manager {
    map[int, process_group] groups
    int next_group_id
    string default_backend
}

func new_process_group(int group_id, vec[int] ranks, string name, comm_backend backend) process_group {
    process_group {
        group_id: group_id,
        ranks: ranks,
        world_size: ranks.len(),
        name: name,
        backend: backend,
        initialized: false,
    }
}

func new_process_group_manager(string default_backend) process_group_manager {
    process_group_manager {
        groups: map[int, process_group]{},
        next_group_id: 1,
        default_backend: default_backend,
    }
}

func (mgr *process_group_manager) create_group(vec[int] ranks, string name, comm_backend backend) int {
    group_id := mgr.next_group_id
    mgr.next_group_id = mgr.next_group_id + 1

    group := new_process_group(group_id, ranks, name, backend)
    mgr.groups[group_id] = group

    group_id
}

func (mgr *process_group_manager) get_group(int group_id) process_group {
    if group_id in mgr.groups {
        mgr.groups[group_id]
    }

    process_group {
        group_id: -1,
        ranks: vec[int]{},
        world_size: 0,
        name: "",
        backend: comm_backend::cpu_only,
        initialized: false,
    }
}

func (mgr *process_group_manager) has_group(int group_id) bool {
    group_id in mgr.groups
}

func (mgr *process_group_manager) delete_group(int group_id) bool {
    if group_id in mgr.groups {
        del mgr.groups[group_id]
        true
    }

    false
}

func (mgr *process_group_manager) list_groups() vec[int] {
    result := vec[int]{}
    for gid in mgr.groups.keys() {
        result.push(gid)
    }
    result
}

func (group *process_group) initialize() bool {
    if group.initialized {
        false
    }

    group.initialized = true
    true
}

func (group *process_group) finalize() bool {
    if !group.initialized {
        false
    }

    group.initialized = false
    true
}

func (group *process_group) contains_rank(int rank) bool {
    i := 0
    while i < group.ranks.len() {
        if group.ranks[i] == rank {
            true
        }
        i = i + 1
    }

    false
}

func (group *process_group) get_rank_index(int rank) int {
    i := 0
    while i < group.ranks.len() {
        if group.ranks[i] == rank {
            i
        }
        i = i + 1
    }

    -1
}

func (group *process_group) get_ranks() vec[int] {
    group.ranks
}

func (group *process_group) get_size() int {
    group.world_size
}
