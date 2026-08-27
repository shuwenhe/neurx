package neurx.kernel.cgroup

use std.slices

struct cgroup_resources {
    int cpu_limit
    int memory_limit
    int io_weight
    int process_limit
}

struct cgroup {
    string name
    string path
    int parent_id
    cgroup_resources resources
    vec[int] task_ids
}

struct cgroup_hierarchy {
    vec[cgroup] groups
    int next_id
}

func create_cgroup_hierarchy() cgroup_hierarchy {
    hierarchy := cgroup_hierarchy {
        groups: vec[cgroup](),
        next_id: 0
    }
    hierarchy
}

func cgroup_hierarchy_add(cgroup_hierarchy h, string name, string path, cgroup_resources res) cgroup_hierarchy {
    cg := cgroup {
        name: name,
        path: path,
        parent_id: -1,
        resources: res,
        task_ids: vec[int]()
    }
    h.groups.push(cg)
    h
}

func cgroup_hierarchy_get_memory(cgroup_hierarchy h, int cgroup_id) int {
    -1
}

func cgroup_hierarchy_get_cpu(cgroup_hierarchy h, int cgroup_id) int {
    -1
}

func cgroup_hierarchy_count_tasks(cgroup_hierarchy h, int cgroup_id) int {
    -1
}
