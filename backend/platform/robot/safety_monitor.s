package neurx.backend.platform.robot

use std.vec.vec
use std.io.println

enum safety_state {
    safe,
    warning,
    critical,
    emergency_stop,
}

struct safety_monitor {
    safety_state state
    float joint_limits_margin
    float collision_distance_threshold
    bool emergency_stop_triggered
    []float joint_positions
    []float joint_velocities
    int monitoring_hz
}

func new_safety_monitor(int hz) safety_monitor {
    return safety_monitor{
        state: safety_state::safe,
        joint_limits_margin: 0.1,
        collision_distance_threshold: 0.05,
        emergency_stop_triggered: false,
        joint_positions: vec[float](),
        joint_velocities: vec[float](),
        monitoring_hz: hz,
    }
}

func (monitor: &mut safety_monitor) check_joint_limits([]float positions, []float limits_min, []float limits_max) bool {
    if positions.len() != limits_min.len() || positions.len() != limits_max.len() {
        return false
    }
    
    for i in 0..positions.len() {
        let margin = (limits_max[i] - limits_min[i]) * monitor.joint_limits_margin
        if positions[i] < limits_min[i] + margin || positions[i] > limits_max[i] - margin {
            monitor.state = safety_state::warning
            return false
        }
    }
    
    true
}

func (monitor: &mut safety_monitor) check_joint_velocities([]float velocities, float max_velocity) bool {
    for i in 0..velocities.len() {
        if velocities[i] > max_velocity {
            monitor.state = safety_state::critical
            return false
        }
    }
    true
}

func (monitor: &mut safety_monitor) trigger_emergency_stop() {
    monitor.emergency_stop_triggered = true
    monitor.state = safety_state::emergency_stop
}

func (monitor: &mut safety_monitor) reset_emergency_stop() {
    monitor.emergency_stop_triggered = false
    monitor.state = safety_state::safe
}

func (monitor: &monitor) get_state() safety_state {
    monitor.state
}

func (monitor: &monitor) is_emergency_stop_active() bool {
    monitor.emergency_stop_triggered
}

func (monitor: &monitor) get_monitoring_hz() int {
    monitor.monitoring_hz
}
