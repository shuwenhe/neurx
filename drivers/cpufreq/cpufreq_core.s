package neurx.drivers.cpufreq

use std.vec.vec
use std.option.option

struct frequency_entry {
    frequency_mhz int
    power_watts int
}

struct cpufreq_policy {
    policy_id int
    min_frequency_mhz int
    max_frequency_mhz int
    current_frequency_mhz int
    governor_name &str
    turbo_enabled bool
}

struct cpu_frequency_table {
    cpu_id int
    frequencies* vec[frequency_entry]
    num_frequencies int
}

struct frequency_governor {
    name &str
    min_freq_percent int
    max_freq_percent int
    target_utilization_percent int
    ramp_up_step_percent int
    ramp_down_step_percent int
}

struct cpufreq_core {
    policies* vec[cpufreq_policy]
    frequency_tables* vec[cpu_frequency_table]
    governors* vec[frequency_governor]
    current_governor_name &str
    power_limit_watts int
    total_power_saved_mwh int
    frequency_change_count int
}

func (core* cpufreq_core) init(num_cpus int, max_freq_mhz int) {
    core.current_governor_name = "performance"
    core.power_limit_watts = 0
    core.total_power_saved_mwh = 0
    core.frequency_change_count = 0
    
    for i in 0..num_cpus {
        let policy = cpufreq_policy {
            policy_id: i,
            min_frequency_mhz: max_freq_mhz / 8,
            max_frequency_mhz: max_freq_mhz,
            current_frequency_mhz: max_freq_mhz / 2,
            governor_name: "performance",
            turbo_enabled: false
        }
        core.policies.push(policy)
    }
}

func (core* cpufreq_core) build_frequency_table(cpu_id int, max_freq_mhz int, base_power_watts int) {
    let mut freq_table = cpu_frequency_table {
        cpu_id: cpu_id,
        frequencies: nil,
        num_frequencies: 0
    }
    
    let step_size = max_freq_mhz / 8
    let mut freq = max_freq_mhz
    
    while freq >= (max_freq_mhz / 8) {
        let power = (base_power_watts * freq) / max_freq_mhz
        let entry = frequency_entry {
            frequency_mhz: freq,
            power_watts: power
        }
        freq_table.frequencies.push(entry)
        freq_table.num_frequencies = freq_table.num_frequencies + 1
        freq = freq - step_size
    }
    
    core.frequency_tables.push(freq_table)
}

func (core* cpufreq_core) register_governor(name &str, target_util int, ramp_up int, ramp_down int) {
    let governor = frequency_governor {
        name: name,
        min_freq_percent: 12,
        max_freq_percent: 100,
        target_utilization_percent: target_util,
        ramp_up_step_percent: ramp_up,
        ramp_down_step_percent: ramp_down
    }
    core.governors.push(governor)
}

func (core* cpufreq_core) set_frequency(policy_id int, target_freq_mhz int) (int, &str) {
    if policy_id >= core.policies.len() {
        return -1, "Invalid policy ID"
    }
    
    let policy = core.policies[policy_id]
    
    if target_freq_mhz < policy.min_frequency_mhz || target_freq_mhz > policy.max_frequency_mhz {
        return -1, "Frequency out of bounds"
    }
    
    let old_freq = policy.current_frequency_mhz
    core.policies[policy_id].current_frequency_mhz = target_freq_mhz
    core.frequency_change_count = core.frequency_change_count + 1
    
    return old_freq, "Frequency set"
}

func (core cpufreq_core) get_frequency_scaling_step(policy_id int, current_utilization_percent int) int {
    if policy_id >= core.policies.len() {
        return 0
    }
    
    let policy = core.policies[policy_id]
    let mut step = 0
    
    for i in 0..core.governors.len() {
        let governor = core.governors[i]
        if governor.name == policy.governor_name {
            if current_utilization_percent > governor.target_utilization_percent {
                step = (policy.max_frequency_mhz * governor.ramp_up_step_percent) / 100
                break
            } else if current_utilization_percent < (governor.target_utilization_percent - 10) {
                step = -(policy.max_frequency_mhz * governor.ramp_down_step_percent) / 100
                break
            }
        }
    }
    
    step
}

func (core* cpufreq_core) scale_frequency_dynamic(policy_id int, utilization_percent int) (int, &str) {
    if policy_id >= core.policies.len() {
        return -1, "Invalid policy ID"
    }
    
    let policy = core.policies[policy_id]
    let step = core.get_frequency_scaling_step(policy_id, utilization_percent)
    
    if step == 0 {
        return policy.current_frequency_mhz, "No scaling needed"
    }
    
    let new_freq = policy.current_frequency_mhz + step
    let clamped_freq = if new_freq > policy.max_frequency_mhz {
        policy.max_frequency_mhz
    } else if new_freq < policy.min_frequency_mhz {
        policy.min_frequency_mhz
    } else {
        new_freq
    }
    
    return core.set_frequency(policy_id, clamped_freq)
}

func (core cpufreq_core) get_current_frequency(policy_id int) option[int] {
    if policy_id >= core.policies.len() {
        return option::none()
    }
    option::some(core.policies[policy_id].current_frequency_mhz)
}

func (core cpufreq_core) get_power_consumption(policy_id int) option[int] {
    if policy_id >= core.frequency_tables.len() {
        return option::none()
    }
    
    let table = core.frequency_tables[policy_id]
    let policy = core.policies[policy_id]
    
    for i in 0..table.frequencies.len() {
        if table.frequencies[i].frequency_mhz == policy.current_frequency_mhz {
            return option::some(table.frequencies[i].power_watts)
        }
    }
    
    option::none()
}

func (core* cpufreq_core) set_turbo_boost(policy_id int, enabled bool) {
    if policy_id < core.policies.len() {
        core.policies[policy_id].turbo_enabled = enabled
    }
}

func (core* cpufreq_core) set_power_limit(watts int) {
    core.power_limit_watts = watts
}

func (core cpufreq_core) get_power_limit() int {
    core.power_limit_watts
}

func (core cpufreq_core) estimate_total_power_consumption() int {
    let mut total_power = 0
    for i in 0..core.policies.len() {
        let power_opt = core.get_power_consumption(i)
        switch power_opt {
            option::some(power) : {
                total_power = total_power + power
            },
            option::none : {}
        }
    }
    total_power
}

func (core cpufreq_core) is_power_budget_exceeded() bool {
    if core.power_limit_watts <= 0 {
        return false
    }
    core.estimate_total_power_consumption() > core.power_limit_watts
}

func (core* cpufreq_core) apply_power_budget_scaling() {
    if !core.is_power_budget_exceeded() {
        return
    }
    
    for i in 0..core.policies.len() {
        let reduction_percent = 20
        let new_max = (core.policies[i].max_frequency_mhz * (100 - reduction_percent)) / 100
        core.policies[i].max_frequency_mhz = new_max
        
        if core.policies[i].current_frequency_mhz > new_max {
            core.policies[i].current_frequency_mhz = new_max
        }
    }
}

func (core cpufreq_core) get_frequency_change_count() int {
    core.frequency_change_count
}

func (core cpufreq_core) get_governor_name() &str {
    core.current_governor_name
}
