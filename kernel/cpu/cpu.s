int CPUFREQ_POWERSAVE    = 0
int CPUFREQ_ONDEMAND     = 1
int CPUFREQ_PERFORMANCE  = 2

struct cpu_info {
    int    cpu_id
    int    numa_node
    int    base_freq_mhz
    int    max_freq_mhz
    int    cur_freq_mhz
    bool   online
    int    governor
}

struct worker {
    int    worker_id
    int    cpu_affinity
    int    numa_affinity
    bool   busy
    string current_task
    int    tasks_completed
}

struct cpu_state {
    []cpu_info cpus
    []worker   workers
    int        next_worker_id
}

func new_cpu_state() cpu_state {
    return cpu_state{
        cpus:           [],
        workers:        [],
        next_worker_id: 0,
    }
}

func cpu_register(cs cpu_state, cpu_id int, numa_node int, base_mhz int, max_mhz int) cpu_state {
    cpu_info c = cpu_info{
        cpu_id:       cpu_id,
        numa_node:    numa_node,
        base_freq_mhz: base_mhz,
        max_freq_mhz: max_mhz,
        cur_freq_mhz: base_mhz,
        online:       true,
        governor:     CPUFREQ_ONDEMAND,
    }
    cs.cpus = append(cs.cpus, c)
    return cs
}

func cpu_spawn_worker(cs cpu_state, cpu_affinity int, numa_affinity int) (cpu_state, int) {
    worker w = worker{
        worker_id:       cs.next_worker_id,
        cpu_affinity:    cpu_affinity,
        numa_affinity:   numa_affinity,
        busy:            false,
        current_task:    "",
        tasks_completed: 0,
    }
    cs.workers = append(cs.workers, w)
    int id = cs.next_worker_id
    cs.next_worker_id = cs.next_worker_id + 1
    return (cs, id)
}

func cpu_assign_task(cs cpu_state, worker_id int, task_name string) (cpu_state, bool) {
    int i = 0
    while i < len(cs.workers) {
        if cs.workers[i].worker_id == worker_id && !cs.workers[i].busy {
            cs.workers[i].busy         = true
            cs.workers[i].current_task = task_name
            return (cs, true)
        }
        i = i + 1
    }
    return (cs, false)
}

func cpu_complete_task(cs cpu_state, worker_id int) cpu_state {
    int i = 0
    while i < len(cs.workers) {
        if cs.workers[i].worker_id == worker_id {
            cs.workers[i].busy            = false
            cs.workers[i].current_task    = ""
            cs.workers[i].tasks_completed = cs.workers[i].tasks_completed + 1
        }
        i = i + 1
    }
    return cs
}

func cpu_pick_idle_worker(cs cpu_state, prefer_cpu int, prefer_numa int) (worker, bool) {
    int i = 0
    while i < len(cs.workers) {
        worker w = cs.workers[i]
        if !w.busy && w.cpu_affinity == prefer_cpu {
            return (w, true)
        }
        i = i + 1
    }
    i = 0
    while i < len(cs.workers) {
        worker w = cs.workers[i]
        if !w.busy && w.numa_affinity == prefer_numa {
            return (w, true)
        }
        i = i + 1
    }
    i = 0
    while i < len(cs.workers) {
        if !cs.workers[i].busy {
            return (cs.workers[i], true)
        }
        i = i + 1
    }
    return (worker{}, false)
}

func cpu_set_governor(cs cpu_state, cpu_id int, governor int) cpu_state {
    int i = 0
    while i < len(cs.cpus) {
        if cs.cpus[i].cpu_id == cpu_id {
            cs.cpus[i].governor = governor
            if governor == CPUFREQ_PERFORMANCE {
                cs.cpus[i].cur_freq_mhz = cs.cpus[i].max_freq_mhz
            } else if governor == CPUFREQ_POWERSAVE {
                cs.cpus[i].cur_freq_mhz = cs.cpus[i].base_freq_mhz
            }
        }
        i = i + 1
    }
    return cs
}

