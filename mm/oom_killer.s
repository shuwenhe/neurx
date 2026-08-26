package neurx.mm.oom_killer

struct process_info {
    int pid
    string name
    int memory_bytes
    int priority
    bool is_system
}

struct oom_killer {
    int total_memory
    int available_memory
    int threshold_percent
    bool oom_kill_enabled
    int last_kill_time_ms
    process_info[] processes
    int[] kill_history
}

func new_oom_killer() oom_killer {
    let procs = new process_info[256]
    let hist = new int[1024]
    oom_killer {
        total_memory: 0,
        available_memory: 0,
        threshold_percent: 85,
        oom_kill_enabled: true,
        last_kill_time_ms: 0,
        processes: procs,
        kill_history: hist
    }
}

func (oom_killer* k) init(total_mb int) {
    k.total_memory = total_mb * 1024 * 1024
    k.available_memory = k.total_memory
    k.threshold_percent = 85
    k.oom_kill_enabled = true
    k.last_kill_time_ms = 0
}

func (oom_killer* k) register_process(pid int, name string, memory_bytes int, priority int, is_system bool) {
    let idx = 0
    while idx < 256 {
        if k.processes[idx].pid == 0 {
            k.processes[idx].pid = pid
            k.processes[idx].name = name
            k.processes[idx].memory_bytes = memory_bytes
            k.processes[idx].priority = priority
            k.processes[idx].is_system = is_system
            idx = 256
        }
        idx = idx + 1
    }
}

func (oom_killer* k) update_memory_usage(pid int, new_memory_bytes int) {
    let idx = 0
    while idx < 256 {
        if k.processes[idx].pid == pid {
            k.processes[idx].memory_bytes = new_memory_bytes
            idx = 256
        }
        idx = idx + 1
    }
}

func (oom_killer k) get_memory_pressure() int {
    let used = k.total_memory - k.available_memory
    (used * 100) / k.total_memory
}

func (oom_killer k) should_trigger_oom() bool {
    let pressure = k.get_memory_pressure()
    if pressure >= k.threshold_percent {
        k.oom_kill_enabled
    } else {
        false
    }
}

func (oom_killer* k) select_victim() int {
    let mut best_victim_pid = 0
    let mut best_score = -1
    
    let idx = 0
    while idx < 256 {
        let proc = k.processes[idx]
        
        if proc.pid != 0 {
            if !proc.is_system {
                let memory_ratio = (proc.memory_bytes * 100) / k.total_memory
                let score = memory_ratio - proc.priority
                
                if score > best_score {
                    best_score = score
                    best_victim_pid = proc.pid
                }
            }
        }
        idx = idx + 1
    }
    
    best_victim_pid
}

func (oom_killer* k) kill_process(pid int) bool {
    let idx = 0
    while idx < 256 {
        if k.processes[idx].pid == pid {
            let freed_memory = k.processes[idx].memory_bytes
            k.available_memory = k.available_memory + freed_memory
            k.processes[idx].pid = 0
            return true
        }
        idx = idx + 1
    }
    false
}

func (oom_killer* k) handle_oom_pressure() int {
    if !k.should_trigger_oom() {
        return 0
    }
    
    let victim_pid = k.select_victim()
    if victim_pid != 0 {
        if k.kill_process(victim_pid) {
            return victim_pid
        }
    }
    
    0
}

func (oom_killer* k) free_memory(bytes int) {
    k.available_memory = k.available_memory + bytes
    if k.available_memory > k.total_memory {
        k.available_memory = k.total_memory
    }
}

func (oom_killer* k) allocate_memory(bytes int) bool {
    if k.available_memory >= bytes {
        k.available_memory = k.available_memory - bytes
        true
    } else {
        false
    }
}

func (oom_killer k) get_status() string {
    let pressure = k.get_memory_pressure()
    if pressure > 95 {
        "Critical"
    } else if pressure > 85 {
        "High"
    } else if pressure > 70 {
        "Medium"
    } else {
        "Normal"
    }
}

func (oom_killer k) get_available_memory_mb() int {
    k.available_memory / (1024 * 1024)
}
