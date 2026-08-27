package neurx.kernel.power_management.cpufreq

use std.slices
use std.option.option
use std.result.result
use neurx.kernel.locking.spinlock

enum frequency_scaling_governor {
    gov_performance,
    gov_powersave,
    gov_ondemand,
    gov_conservative,
    gov_schedutil,
    gov_interactive,
}

enum frequency_scaling_driver {
    drv_intel_pstate,
    drv_amd_pstate,
    drv_acpi_cpufreq,
    drv_generic,
}

struct cpu_frequency {
    cpu_id: u32,
    current_frequency: u64,
    min_frequency: u64,
    max_frequency: u64,
    turbo_enabled: bool,
    transitions: u64,
    scaling_driver: frequency_scaling_driver,
    governor: frequency_scaling_governor,
}

struct frequency_policy {
    cpu_id: u32,
    min: u64,
    max: u64,
    policy: frequency_scaling_governor,
    transition_latency: u32,
}

struct cpufreq_governor {
    name: *string,
    governor_type: frequency_scaling_governor,
    target_fn: *fn(cpu_id: u32, target_freq: u64) -> result[void, string],
    limits_fn: *fn(cpu_id: u32, policy: *frequency_policy) -> result[void, string],
}

struct cpufreq_engine {
    cpus: vec[cpu_frequency],
    policies: vec[frequency_policy],
    governors: vec[cpufreq_governor],
    active_governor: frequency_scaling_governor,
    current_driver: frequency_scaling_driver,
    lock: spinlock::spinlock[void],
}

struct cpu_load {
    cpu_id: u32,
    load_percent: f32,
    frequency_demand: u64,
}

func new_cpufreq_engine(
    num_cpus: u32,
    min_freq: u64,
    max_freq: u64,
) (*cpufreq_engine, string) {
    let mut cpus := vec[cpu_frequency]()

    let mut i := 0
    while i < num_cpus {
        let cpu := cpu_frequency{
            cpu_id: i,
            current_frequency: max_freq,
            min_frequency: min_freq,
            max_frequency: max_freq,
            turbo_enabled: true,
            transitions: 0,
            scaling_driver: frequency_scaling_driver::drv_generic,
            governor: frequency_scaling_governor::gov_ondemand,
        }

        cpus.push(cpu)
        i = i + 1
    }

    let engine := *cpufreq_engine{
        cpus: cpus,
        policies: vec[frequency_policy](),
        governors: vec[cpufreq_governor](),
        active_governor: frequency_scaling_governor::gov_ondemand,
        current_driver: frequency_scaling_driver::drv_generic,
        lock: spinlock::new(),
    } as *cpufreq_engine

    result::ok(engine)
}

func (engine: *cpufreq_engine) register_governor(
    gov: *cpufreq_governor,
) (void, string) {
    let _guard := engine.lock.lock()?

    engine.governors.push(gov)
    result::ok(())
}

func (engine: *cpufreq_engine) set_governor(
    governor: frequency_scaling_governor,
) (void, string) {
    let _guard := engine.lock.lock()?

    let mut found := false

    for gov in engine.governors {
        if gov.governor_type == governor {
            found = true
            break
        }
    }

    if !found {
        return result::err("governor not registered")
    }

    engine.active_governor = governor

    result::ok(())
}

func (engine: *cpufreq_engine) set_cpu_frequency(
    cpu_id: u32,
    target_frequency: u64,
) (void, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency

    if target_frequency < cpu.min_frequency || target_frequency > cpu.max_frequency {
        return result::err("frequency out of range")
    }

    cpu.current_frequency = target_frequency
    cpu.transitions = cpu.transitions + 1

    result::ok(())
}

func (engine: *cpufreq_engine) get_cpu_frequency(cpu_id: u32) (u64, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency
    result::ok(cpu.current_frequency)
}

func (engine: *cpufreq_engine) scale_on_demand(cpu_load: *cpu_load) (void, string) {
    let _guard := engine.lock.lock()?

    if cpu_load.load_percent > 75.0 {
        engine.set_cpu_frequency(cpu_load.cpu_id, cpu_load.frequency_demand)?
    } else if cpu_load.load_percent < 25.0 {
        let cpu := *engine.cpus.get(cpu_load.cpu_id) as *cpu_frequency
        let scale_down_freq := cpu.min_frequency + ((cpu.max_frequency - cpu.min_frequency) / 2)
        engine.set_cpu_frequency(cpu_load.cpu_id, scale_down_freq)?
    }

    result::ok(())
}

func (engine: *cpufreq_engine) enable_turbo(cpu_id: u32) (void, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency
    cpu.turbo_enabled = true

    result::ok(())
}

func (engine: *cpufreq_engine) disable_turbo(cpu_id: u32) (void, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency
    cpu.turbo_enabled = false

    result::ok(())
}

func (engine: *cpufreq_engine) create_policy(
    cpu_id: u32,
    min: u64,
    max: u64,
    governor: frequency_scaling_governor,
) (void, string) {
    let _guard := engine.lock.lock()?

    let policy := frequency_policy{
        cpu_id: cpu_id,
        min: min,
        max: max,
        policy: governor,
        transition_latency: 1000,
    }

    engine.policies.push(policy)
    result::ok(())
}

func (engine: *cpufreq_engine) get_cpu_load(cpu_id: u32) (cpu_load, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency

    let load := cpu_load{
        cpu_id: cpu_id,
        load_percent: 50.0,
        frequency_demand: cpu.max_frequency,
    }

    result::ok(load)
}

struct cpufreq_statistics {
    total_cpus: u32,
    average_frequency: u64,
    total_transitions: u64,
    turbo_enabled_count: u32,
    power_savings: f32,
}

func (engine: *cpufreq_engine) get_statistics() (cpufreq_statistics, string) {
    let _guard := engine.lock.lock()?

    let mut total_freq := 0
    let mut total_trans := 0
    let mut turbo_count := 0

    for cpu in engine.cpus {
        total_freq = total_freq + cpu.current_frequency
        total_trans = total_trans + cpu.transitions

        if cpu.turbo_enabled {
            turbo_count = turbo_count + 1
        }
    }

    let avg_freq := if engine.cpus.len() > 0 {
        total_freq / (engine.cpus.len() as u64)
    } else {
        0
    }

    let stats := cpufreq_statistics{
        total_cpus: engine.cpus.len() as u32,
        average_frequency: avg_freq,
        total_transitions: total_trans,
        turbo_enabled_count: turbo_count,
        power_savings: 25.0,
    }

    result::ok(stats)
}

func (engine: *cpufreq_engine) set_frequency_range(
    cpu_id: u32,
    min_freq: u64,
    max_freq: u64,
) (void, string) {
    let _guard := engine.lock.lock()?

    if (cpu_id as u32) >= engine.cpus.len() as u32 {
        return result::err("invalid cpu id")
    }

    let cpu := *engine.cpus.get(cpu_id) as *cpu_frequency

    if min_freq >= max_freq {
        return result::err("min frequency must be less than max")
    }

    cpu.min_frequency = min_freq
    cpu.max_frequency = max_freq

    if cpu.current_frequency > max_freq {
        cpu.current_frequency = max_freq
    }

    result::ok(())
}

func (engine: *cpufreq_engine) transition_latency(cpu_id: u32) (u32, string) {
    let _guard := engine.lock.lock()?

    for policy in engine.policies {
        if policy.cpu_id == cpu_id {
            return result::ok(policy.transition_latency)
        }
    }

    result::err("policy not found for cpu")
}
