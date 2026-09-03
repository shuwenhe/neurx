package neurx.backend.platform.robot

use std.slices
use std.io.println

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
    float[] joint_positions
    float[] joint_velocities
    int monitoring_hz
}

func new_safety_monitor(int hz) safety_monitor {
    return safety_monitor{
        state: safety_state_safe,
        joint_limits_margin: 0.1,
        collision_distance_threshold: 0.05,
        emergency_stop_triggered: false,
        joint_positions: float[](),
        joint_velocities: float[](),
        monitoring_hz: hz,
    }
}

func (safety_monitor* monitor) check_joint_limits(float[] positions, float[] limits_min, float[] limits_max) bool {    if len(positions) != len(limits_min) || len(positions) != len(limits_max) {
        return false
    }
    
    for i in len(0..positions) {
        margin := (limits_max[i] - limits_min[i]) * monitor.joint_limits_margin
        if positions[i] < limits_min[i] + margin || positions[i] > limits_max[i] - margin {
            monitor.state = safety_state_warning
            return false
        }
    }
    
    true
}

func (safety_monitor* monitor) check_joint_velocities(float[] velocities, float max_velocity) bool {    for i in len(0..velocities) {
        if velocities[i] > max_velocity {
            monitor.state = safety_state_critical
            return false
        }
    }
    true
}

func (safety_monitor* monitor) trigger_emergency_stop() {
    monitor.emergency_stop_triggered = true
    monitor.state = safety_state_emergency_stop
}

func (safety_monitor* monitor) reset_emergency_stop() {
    monitor.emergency_stop_triggered = false
    monitor.state = safety_state_safe
}

func (monitor* monitor) get_state() safety_state {    monitor.state
}

func (monitor* monitor) is_emergency_stop_active() bool {    monitor.emergency_stop_triggered
}

func (monitor* monitor) get_monitoring_hz() int {    monitor.monitoring_hz
}
