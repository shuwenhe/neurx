package neurx.mm.oom_killer

use std.vec.vec
use std.option.option

struct process_info {
    pid int
    name &str
    memory_bytes int
    priority int
    is_system bool
}

struct memory_pressure_state {
    total_memory int
    available_memory int
    threshold_percent int
    oom_kill_enabled bool
    last_kill_time_ms int
}

struct oom_killer {
    state* memory_pressure_state
    processes* vec[process_info]
    kill_history* vec[int]
}

func (killer* oom_killer) init(total_mb int) {
    killer.state.total_memory = total_mb * 1024 * 1024
    killer.state.available_memory = killer.state.total_memory
    killer.state.threshold_percent = 85
    killer.state.oom_kill_enabled = true
    killer.state.last_kill_time_ms = 0
}

func (killer* oom_killer) register_process(pid int, name &str, memory_bytes int, priority int, is_system bool) {
    let process = process_info {
        pid: pid,
        name: name,
        memory_bytes: memory_bytes,
        priority: priority,
        is_system: is_system
    }
    killer.processes.push(process)
}

func (killer* oom_killer) update_memory_usage(pid int, new_memory_bytes int) {
    for i in 0..killer.processes.len() {
        if killer.processes[i].pid == pid {
            killer.processes[i].memory_bytes = new_memory_bytes
            break
        }
    }
}

func (killer oom_killer) get_memory_pressure() int {
    let used = killer.state.total_memory - killer.state.available_memory
    (used * 100) / killer.state.total_memory
}

func (killer oom_killer) should_trigger_oom() bool {
    let pressure = killer.get_memory_pressure()
    pressure >= killer.state.threshold_percent && killer.state.oom_kill_enabled
}

func (killer* oom_killer) select_victim() option[int] {
    if killer.processes.len() == 0 {
        return option::none()
    }

    let mut best_victim_idx = -1
    let mut best_score = -1

    for i in 0..killer.processes.len() {
        let proc = killer.processes[i]
        
        if proc.is_system {
            continue
        }

        let memory_ratio = (proc.memory_bytes * 100) / killer.state.total_memory
        let score = memory_ratio - proc.priority

        if score > best_score {
            best_score = score
            best_victim_idx = i
        }
    }

    if best_victim_idx >= 0 {
        option::some(killer.processes[best_victim_idx].pid)
    } else {
        option::none()
    }
}

func (killer* oom_killer) kill_process(pid int) bool {
    for i in 0..killer.processes.len() {
        if killer.processes[i].pid == pid {
            let freed_memory = killer.processes[i].memory_bytes
            killer.state.available_memory = killer.state.available_memory + freed_memory
            killer.processes[i] = killer.processes[killer.processes.len() - 1]
            killer.processes.pop()
            killer.kill_history.push(pid)
            killer.state.last_kill_time_ms = 0
            return true
        }
    }
    false
}

func (killer* oom_killer) handle_oom_pressure() (int, &str) {
    if !killer.should_trigger_oom() {
        return -1, "No OOM pressure detected"
    }

    let victim_opt = killer.select_victim()
    switch victim_opt {
        option::some(victim_pid) : {
            if killer.kill_process(victim_pid) {
                return victim_pid, "Process killed"
            } else {
                return -1, "Failed to kill victim process"
            }
        },
        option::none : {
            return -1, "No killable process found"
        }
    }
}

func (killer* oom_killer) free_memory(bytes int) {
    killer.state.available_memory = killer.state.available_memory + bytes
    if killer.state.available_memory > killer.state.total_memory {
        killer.state.available_memory = killer.state.total_memory
    }
}

func (killer* oom_killer) allocate_memory(bytes int) (int, &str) {
    if killer.state.available_memory < bytes {
        let pid, msg = killer.handle_oom_pressure()
        if pid >= 0 {
            if killer.state.available_memory >= bytes {
                killer.state.available_memory = killer.state.available_memory - bytes
                return bytes, "Allocated after OOM kill"
            } else {
                return -1, "Memory still insufficient after OOM kill"
            }
        } else {
            return -1, msg
        }
    } else {
        killer.state.available_memory = killer.state.available_memory - bytes
        return bytes, "Allocated successfully"
    }
}

func (killer oom_killer) get_status() &str {
    let pressure = killer.get_memory_pressure()
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

func (killer oom_killer) get_kill_count() int {
    killer.kill_history.len()
}

func (killer oom_killer) get_available_memory_mb() int {
    killer.state.available_memory / (1024 * 1024)
}
