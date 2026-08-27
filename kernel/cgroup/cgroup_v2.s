package neurx.kernel.cgroup

struct resource_type {
    int value
}

func resource_type_cpu_shares() resource_type { resource_type { value: 0 } }
func resource_type_cpu_quota() resource_type { resource_type { value: 1 } }
func resource_type_memory_limit() resource_type { resource_type { value: 2 } }
func resource_type_memory_soft_limit() resource_type { resource_type { value: 3 } }
func resource_type_io_weight() resource_type { resource_type { value: 4 } }
func resource_type_io_max_bandwidth() resource_type { resource_type { value: 5 } }
func resource_type_pids_max() resource_type { resource_type { value: 6 } }

struct cgroup_cpu_stats {
    int total_cpu_time_us
    int user_time_us
    int system_time_us
    int nr_periods
    int nr_throttled
    int throttled_time_us
}

struct cgroup_memory_stats {
    int total_memory_bytes
    int max_memory_bytes
    int rss_bytes
    int page_cache_bytes
    int swap_bytes
    int oom_count
}

struct cgroup_io_stats {
    int total_io_read_bytes
    int total_io_write_bytes
    int total_io_operations
    int io_wait_time_us
}

struct cgroup_pids_stats {
    int current_pids
    int max_pids
    int total_forks
    int fork_limit_exceeded
}

struct cgroup_v2 {
    string name
    string path
    int id
    int parent_id
    int level
    vec[resource_type] enabled_controllers
    cgroup_cpu_stats cpu_stats
    cgroup_memory_stats mem_stats
    cgroup_io_stats io_stats
    cgroup_pids_stats pids_stats
    int pressure_cpu
    int pressure_memory
    int pressure_io
}

struct cgroup_hierarchy_v2 {
    string name
    vec[cgroup_v2] cgroups
    int total_cgroups
    int max_cgroups
    int root_cgroup_id
}

func cgroup_v2_create(string name, int id) cgroup_v2 {
    cg := cgroup_v2 {
        name: name,
        path: "/sys/fs/cgroup/" + name,
        id: id,
        parent_id: 0,
        level: 1,
        enabled_controllers: vec[resource_type](),
        cpu_stats: cgroup_cpu_stats {
            total_cpu_time_us: 0,
            user_time_us: 0,
            system_time_us: 0,
            nr_periods: 0,
            nr_throttled: 0,
            throttled_time_us: 0
        },
        mem_stats: cgroup_memory_stats {
            total_memory_bytes: 0,
            max_memory_bytes: 0,
            rss_bytes: 0,
            page_cache_bytes: 0,
            swap_bytes: 0,
            oom_count: 0
        },
        io_stats: cgroup_io_stats {
            total_io_read_bytes: 0,
            total_io_write_bytes: 0,
            total_io_operations: 0,
            io_wait_time_us: 0
        },
        pids_stats: cgroup_pids_stats {
            current_pids: 0,
            max_pids: 0,
            total_forks: 0,
            fork_limit_exceeded: 0
        },
        pressure_cpu: 0,
        pressure_memory: 0,
        pressure_io: 0
    }
    return cg
}

func (cg: *cgroup_v2) enable_controller(resource_type res_type) (bool, string) {
    cg.enabled_controllers.push(res_type)
    return result::ok(true)
}

func (cg: *cgroup_v2) set_cpu_max(int quota_us, int period_us) (bool, string) {
    if quota_us <= 0 || period_us <= 0 {
        return result::err("Invalid CPU max parameters")
    }
    cg.cpu_stats.nr_periods = cg.cpu_stats.nr_periods + 1
    return result::ok(true)
}

func (cg: *cgroup_v2) set_memory_max(int bytes) (bool, string) {
    if bytes <= 0 {
        return result::err("Invalid memory max")
    }
    cg.mem_stats.max_memory_bytes = bytes
    return result::ok(true)
}

func (cg: *cgroup_v2) set_memory_high(int bytes) (bool, string) {
    if bytes <= 0 {
        return result::err("Invalid memory high")
    }
    return result::ok(true)
}

func (cg: *cgroup_v2) set_memory_low(int bytes) (bool, string) {
    if bytes <= 0 {
        return result::err("Invalid memory low")
    }
    return result::ok(true)
}

func (cg: *cgroup_v2) set_io_max(string device, string limits) (bool, string) {
    cg.io_stats.total_io_operations = cg.io_stats.total_io_operations + 1
    return result::ok(true)
}

func (cg: *cgroup_v2) set_pids_max(int max) (bool, string) {
    if max <= 0 {
        return result::err("Invalid pids max")
    }
    cg.pids_stats.max_pids = max
    return result::ok(true)
}

func (cg: *cgroup_v2) update_cpu_stats(int delta_user_us, int delta_system_us) {
    cg.cpu_stats.total_cpu_time_us = cg.cpu_stats.total_cpu_time_us + delta_user_us + delta_system_us
    cg.cpu_stats.user_time_us = cg.cpu_stats.user_time_us + delta_user_us
    cg.cpu_stats.system_time_us = cg.cpu_stats.system_time_us + delta_system_us
}

func (cg: *cgroup_v2) update_memory_stats(int delta_rss, int delta_cache) {
    cg.mem_stats.rss_bytes = cg.mem_stats.rss_bytes + delta_rss
    cg.mem_stats.page_cache_bytes = cg.mem_stats.page_cache_bytes + delta_cache
    cg.mem_stats.total_memory_bytes = cg.mem_stats.rss_bytes + cg.mem_stats.page_cache_bytes
    
    if cg.mem_stats.total_memory_bytes > cg.mem_stats.max_memory_bytes {
        cg.mem_stats.oom_count = cg.mem_stats.oom_count + 1
    }
}

func (cg: *cgroup_v2) update_io_stats(int read_bytes, int write_bytes) {
    cg.io_stats.total_io_read_bytes = cg.io_stats.total_io_read_bytes + read_bytes
    cg.io_stats.total_io_write_bytes = cg.io_stats.total_io_write_bytes + write_bytes
    cg.io_stats.total_io_operations = cg.io_stats.total_io_operations + 1
}

func (cg: *cgroup_v2) get_cpu_pressure() int {
    return cg.pressure_cpu
}

func (cg: *cgroup_v2) get_memory_pressure() int {
    return cg.pressure_memory
}

func (cg: *cgroup_v2) get_io_pressure() int {
    return cg.pressure_io
}

func cgroup_hierarchy_v2_create(string name) cgroup_hierarchy_v2 {
    hier := cgroup_hierarchy_v2 {
        name: name,
        cgroups: vec[cgroup_v2](),
        total_cgroups: 0,
        max_cgroups: 4096,
        root_cgroup_id: 0
    }
    return hier
}

func (hier: *cgroup_hierarchy_v2) add_cgroup(string cg_name, int parent_id) (int, string) {
    if hier.total_cgroups >= hier.max_cgroups {
        return result::err("Cgroup hierarchy limit exceeded")
    }
    
    new_cg := cgroup_v2_create(cg_name, hier.total_cgroups)
    new_cg.parent_id = parent_id
    new_cg.level = if parent_id == 0 { 0 } else { 1 }
    
    hier.cgroups.push(new_cg)
    new_id := hier.total_cgroups
    hier.total_cgroups = hier.total_cgroups + 1
    
    return result::ok(new_id)
}

func (hier: *cgroup_hierarchy_v2) get_cgroup(int cg_id) option[cgroup_v2] {
    if cg_id < 0 || cg_id >= hier.total_cgroups {
        return option::none
    }
    return option::some(hier.cgroups[cg_id])
}

func (hier: *cgroup_hierarchy_v2) total_cpu_usage() int {
    total := 0
    i := 0
    while i < hier.total_cgroups {
        total = total + hier.cgroups[i].cpu_stats.total_cpu_time_us
        i = i + 1
    }
    return total
}

func (hier: *cgroup_hierarchy_v2) total_memory_used() int {
    total := 0
    i := 0
    while i < hier.total_cgroups {
        total = total + hier.cgroups[i].mem_stats.total_memory_bytes
        i = i + 1
    }
    return total
}
