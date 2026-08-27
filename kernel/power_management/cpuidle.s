package neurx.kernel.power_management.cpuidle

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

enum c_state_type {
    c0,
    c1,
    c1e,
    c2,
    c3,
    c6,
    c7,
    c8,
    c9,
    c10,
}

struct c_state {
    state_type: c_state_type,
    exit_latency_us: u32,
    power_usage_mw: u32,
    target_residency_us: u32,
    description: *string,
    enabled: bool,
}

struct cpu_idle_state {
    cpu_id: u32,
    current_c_state: c_state_type,
    available_states: c_state[],
    residency_time: u64,
    wake_time: u64,
    state_transitions: u64,
}

struct idle_governor {
    name: *string,
    predict_fn: *fn(cpu_id: u32) -> c_state_type,
    enter_fn: *fn(cpu_id: u32, state: c_state_type) -> result[void, string],
}

struct cpuidle_engine {
    cpus: cpu_idle_state[],
    governors: idle_governor[],
    active_governor: option[*string],
    lock: spinlock::spinlock[void],
    total_idle_time: u64,
}

func new_cpuidle_engine(num_cpus: u32) (*cpuidle_engine, string) {
    cpus := cpu_idle_state[]()

    i := 0
    while i < num_cpus {
        idle_state := cpu_idle_state{
            cpu_id: i,
            current_c_state: c_state_type::c0,
            available_states: c_state[](),
            residency_time: 0,
            wake_time: 0,
            state_transitions: 0,
        }

        cpus = append(cpus, idle_state)
        i = i + 1
    }

    engine := *cpuidle_engine{
        cpus: cpus,
        governors: idle_governor[](),
        active_governor: option::none,
        lock: spinlock::new(),
        total_idle_time: 0,
    } as *cpuidle_engine

return     (engine, "")
}

func (cpuidle_engine* engine) register_c_state(
    cpu_id: u32,
    state: *c_state,
) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state
    cpu_state.available_states = append(cpu_state.available_states, state)

    return (), ""
}

func (cpuidle_engine* engine) enable_c_state(
    cpu_id: u32,
    state_type: c_state_type,
) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    for state in cpu_state.available_states {
        if state.state_type == state_type {
            state.enabled = true
            return return (), ""
        }
    }

    ((), "c-state not found")
}

func (cpuidle_engine* engine) disable_c_state(
    cpu_id: u32,
    state_type: c_state_type,
) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    for state in cpu_state.available_states {
        if state.state_type == state_type {
            state.enabled = false
            return return (), ""
        }
    }

    ((), "c-state not found")
}

func (cpuidle_engine* engine) enter_idle_state(
    cpu_id: u32,
    target_state: c_state_type,
) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    found := false
    for state in cpu_state.available_states {
        if state.state_type == target_state && state.enabled {
            found = true
            break
        }
    }

    if !found {
        return ((), "target c-state not available or disabled")
    }

    cpu_state.current_c_state = target_state
    cpu_state.state_transitions = cpu_state.state_transitions + 1

    return (), ""
}

func (cpuidle_engine* engine) exit_idle_state(cpu_id: u32) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    cpu_state.current_c_state = c_state_type::c0
    cpu_state.wake_time = 0

    return (), ""
}

func (cpuidle_engine* engine) predict_next_c_state(
    cpu_id: u32,
) (c_state_type, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    deepest_state := c_state_type::c0

    for state in cpu_state.available_states {
        if state.enabled {
            deepest_state = state.state_type
        }
    }

return     (deepest_state, "")
}

func (cpuidle_engine* engine) register_governor(
    governor: *idle_governor,
) (void, string) {
    _guard := engine.lock.lock()?

    engine.governors = append(engine.governors, governor)
    return (), ""
}

func (cpuidle_engine* engine) set_governor(string* name) (void, string) {
    _guard := engine.lock.lock()?

    for governor in engine.governors {
        if governor.name == name {
            engine.active_governor = option::some(*governor.name)
            return return (), ""
        }
    }

    ((), "governor not found")
}

struct idle_statistics {
    total_cpus: u32,
    cpus_in_idle: u32,
    total_idle_time: u64,
    average_idle_depth: f32,
    state_transitions_total: u64,
    deepest_state_reached: c_state_type,
}

func (cpuidle_engine* engine) get_statistics() (idle_statistics, string) {
    _guard := engine.lock.lock()?

    idle_count := 0
    total_transitions := 0
    total_residency := 0

    for cpu_state in engine.cpus {
        if cpu_state.current_c_state != c_state_type::c0 {
            idle_count = idle_count + 1
        }
        total_transitions = total_transitions + cpu_state.state_transitions
        total_residency = total_residency + cpu_state.residency_time
    }

    stats := idle_statistics{
        total_cpus: len(engine.cpus) as u32,
        cpus_in_idle: idle_count,
        total_idle_time: engine.total_idle_time,
        average_idle_depth: 0.0,
        state_transitions_total: total_transitions,
        deepest_state_reached: c_state_type::c10,
    }

return     (stats, "")
}

func (cpuidle_engine* engine) update_residency_time(
    cpu_id: u32,
    residency_us: u64,
) (void, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state
    cpu_state.residency_time = cpu_state.residency_time + residency_us
    engine.total_idle_time = engine.total_idle_time + residency_us

    return (), ""
}

func (cpuidle_engine* engine) get_c_state_info(
    cpu_id: u32,
    state_type: c_state_type,
) (c_state, string) {
    _guard := engine.lock.lock()?

    if (cpu_id as u32) >= len(engine.cpus) as u32 {
        return ((), "invalid cpu id")
    }

    cpu_state := *engine.cpus.get(cpu_id) as *cpu_idle_state

    for state in cpu_state.available_states {
        if state.state_type == state_type {
            return state, ""
        }
    }

    ((), "c-state not found")
}

func calculate_power_saving(c_state* state) f32 {
    power_mw := state.power_usage_mw as f32
    latency_us := state.exit_latency_us as f32

    (100.0 - (power_mw / 1000.0)) * (1.0 - (latency_us / 1000.0))
}
