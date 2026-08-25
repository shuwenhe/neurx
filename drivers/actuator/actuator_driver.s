package neurx.drivers.actuator

enum actuator_type {
    motor_brushless,
    servo_precision,
    linear_actuator,
    solenoid
}

struct actuator_command {
    actuator_type actuator_type
    float target_position
    float target_velocity
    float target_force
    int timestamp_us
}

struct actuator_driver {
    actuator_type actuator_type
    int driver_id
    float max_speed
    float max_force
    bool is_homed
}

struct feedback {
    float current_position
    float current_velocity
    float current_force
    int timestamp_us
}

func init_actuator(actuator_type actuator_type) (actuator_driver, string) {
    result::ok(actuator_driver {
        actuator_type: actuator_type,
        driver_id: 0,
        max_speed: 100.0,
        max_force: 100.0,
        is_homed: false
    })
}

func home_actuator(actuator_driver* driver) (int, string) {
    driver->is_homed = true
    result::ok(0)
}

func send_command(actuator_driver* driver, actuator_command* cmd) (int, string) {
    result::ok(0)
}

func read_feedback(actuator_driver* driver) (feedback, string) {
    result::ok(feedback {
        current_position: 0.0,
        current_velocity: 0.0,
        current_force: 0.0,
        timestamp_us: 0
    })
}
