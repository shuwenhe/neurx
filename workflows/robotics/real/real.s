package neurx.workflows.robotics.real
struct robotics_real_state {
    string robot_name
    bool connected
    bool emergency_stop
}

func new_robotics_real_state(string robot_name) robotics_real_state {
    robotics_real_state {
        robot_name: robot_name,
        connected: false,
        emergency_stop: false,
    }
}

func robotics_real_state_dict(robotics_real_state state) robotics_real_state {
    state
}

func robotics_real_load_state_dict(robotics_real_state state, robotics_real_state other) robotics_real_state {
    other
}

func robotics_real_connect(robotics_real_state state) robotics_real_state {
    robotics_real_state {
        robot_name: state.robot_name,
        connected: true,
        emergency_stop: state.emergency_stop,
    }
}

func robotics_real_trigger_emergency_stop(robotics_real_state state) robotics_real_state {
    robotics_real_state {
        robot_name: state.robot_name,
        connected: state.connected,
        emergency_stop: true,
    }
}
