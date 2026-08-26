package neurx.drivers.cpufreq.cpufreq_core

use std.vec.vec
use std.option.option

struct frequency_entry {
  frequency_mhz: int,
  power_watts: int
}

struct cpufreq_policy {
  policy_id: int,
  min_frequency_mhz: int,
  max_frequency_mhz: int,
  current_frequency_mhz: int,
  governor_name: &str,
  turbo_enabled: bool
}

struct cpu_frequency_table {
  cpu_id: int,
  frequencies: &mut vec[frequency_entry],
  num_frequencies: int
}

struct frequency_governor {
  name: &str,
  min_freq_percent: int,
  max_freq_percent: int,
  target_utilization_percent: int,
  ramp_up_step_percent: int,
  ramp_down_step_percent: int
}

struct cpufreq_core {
  policies: &mut vec[cpufreq_policy],
  frequency_tables: &mut vec[cpu_frequency_table],
  governors: &mut vec[frequency_governor],
  current_governor_name: &str,
  power_limit_watts: int,
  total_power_saved_mwh: int,
  frequency_change_count: int
}

func (core: &mut cpufreq_core) init(num_cpus: int, max_freq_mhz: int) {
  core.policies = vec[cpufreq_policy]()
  core.frequency_tables = vec[cpu_frequency_table]()
  core.governors = vec[frequency_governor]()
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

func (core: &mut cpufreq_core) build_frequency_table(cpu_id: int, max_freq_mhz: int, base_power_watts: int) {
  let mut freq_table = cpu_frequency_table {
    cpu_id: cpu_id,
    frequencies: &mut vec[frequency_entry](),
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

func (core: &mut cpufreq_core) register_governor(name: &str, target_util: int, ramp_up: int, ramp_down: int) {
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

func (core: &mut cpufreq_core) get_governor(name: &str) option[&mut frequency_governor] {
  for i in 0..core.governors.len() {
    if core.governors[i].name == name {
      return option::some(&mut core.governors[i])
    }
  }
  option::none()
}

func (core: &mut cpufreq_core) set_frequency(policy_id: int, target_freq_mhz: int) result[int, &str] {
  if policy_id >= core.policies.len() as int {
    return result::err("Invalid policy ID")
  }
  
  let policy = &mut core.policies[policy_id as int]
  
  if target_freq_mhz < policy.min_frequency_mhz || target_freq_mhz > policy.max_frequency_mhz {
    return result::err("Frequency out of bounds")
  }
  
  let old_freq = policy.current_frequency_mhz
  policy.current_frequency_mhz = target_freq_mhz
  core.frequency_change_count = core.frequency_change_count + 1
  
  result::ok(old_freq)
}

func (core: &mut cpufreq_core) get_frequency_scaling_step(policy_id: int, current_utilization_percent: int) int {
  if policy_id >= core.policies.len() as int {
    return 0
  }
  
  let policy = &core.policies[policy_id as int]
  let governor_opt = core.get_governor(policy.governor_name)
  
  switch governor_opt {
    option::some(governor) : {
      if current_utilization_percent > governor.target_utilization_percent {
        let step = (policy.max_frequency_mhz * governor.ramp_up_step_percent) / 100
        step
      } else if current_utilization_percent < (governor.target_utilization_percent - 10) {
        let step = (policy.max_frequency_mhz * governor.ramp_down_step_percent) / 100
        -step
      } else {
        0
      }
    },
    option::none : {
      0
    }
  }
}

func (core: &mut cpufreq_core) scale_frequency_dynamic(policy_id: int, utilization_percent: int) result[int, &str] {
  if policy_id >= core.policies.len() as int {
    return result::err("Invalid policy ID")
  }
  
  let policy = &mut core.policies[policy_id as int]
  let step = core.get_frequency_scaling_step(policy_id, utilization_percent)
  
  if step == 0 {
    return result::ok(policy.current_frequency_mhz)
  }
  
  let new_freq = policy.current_frequency_mhz + step
  let clamped_freq = if new_freq > policy.max_frequency_mhz {
    policy.max_frequency_mhz
  } else if new_freq < policy.min_frequency_mhz {
    policy.min_frequency_mhz
  } else {
    new_freq
  }
  
  core.set_frequency(policy_id, clamped_freq)
}

func (core: &core) get_current_frequency(policy_id: int) option[int] {
  if policy_id >= core.policies.len() as int {
    return option::none()
  }
  option::some(core.policies[policy_id as int].current_frequency_mhz)
}

func (core: &core) get_power_consumption(policy_id: int) option[int] {
  if policy_id >= core.frequency_tables.len() as int {
    return option::none()
  }
  
  let table = &core.frequency_tables[policy_id as int]
  let policy = &core.policies[policy_id as int]
  
  for i in 0..table.frequencies.len() {
    if table.frequencies[i].frequency_mhz == policy.current_frequency_mhz {
      return option::some(table.frequencies[i].power_watts)
    }
  }
  
  option::none()
}

func (core: &mut cpufreq_core) set_turbo_boost(policy_id: int, enabled: bool) {
  if policy_id < core.policies.len() as int {
    core.policies[policy_id as int].turbo_enabled = enabled
  }
}

func (core: &mut cpufreq_core) set_power_limit(watts: int) {
  core.power_limit_watts = watts
}

func (core: &core) get_power_limit() int {
  core.power_limit_watts
}

func (core: &core) estimate_total_power_consumption() int {
  let mut total_power = 0
  for i in 0..core.policies.len() {
    let power_opt = core.get_power_consumption(i as int)
    switch power_opt {
      option::some(power) : {
        total_power = total_power + power
      },
      option::none : {}
    }
  }
  total_power
}

func (core: &core) is_power_budget_exceeded() bool {
  if core.power_limit_watts <= 0 {
    return false
  }
  core.estimate_total_power_consumption() > core.power_limit_watts
}

func (core: &mut cpufreq_core) apply_power_budget_scaling() {
  if !core.is_power_budget_exceeded() {
    return
  }
  
  for i in 0..core.policies.len() {
    let policy = &mut core.policies[i]
    let reduction_percent = 20
    let new_max = (policy.max_frequency_mhz * (100 - reduction_percent)) / 100
    policy.max_frequency_mhz = new_max
    
    if policy.current_frequency_mhz > new_max {
      policy.current_frequency_mhz = new_max
    }
  }
}

func (core: &core) get_frequency_change_count() int {
  core.frequency_change_count
}

func (core: &core) get_governor_name() &str {
  core.current_governor_name
}
