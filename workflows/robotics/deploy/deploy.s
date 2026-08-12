package neurx.workflows.robotics.deploy
struct robotics_deploy_state {
    string target_name
    bool running
    bool emergency_stop
}


func new_robotics_deploy_state(string target_name) robotics_deploy_state {
    robotics_deploy_state {
        target_name: target_name,
        running: false,
        emergency_stop: false,
    }
}


func robotics_deploy_state_dict(robotics_deploy_state state) robotics_deploy_state {
    state
}


func robotics_deploy_load_state_dict(robotics_deploy_state state, robotics_deploy_state other) robotics_deploy_state {
    other
}


func robotics_deploy_start(robotics_deploy_state state) robotics_deploy_state {
    robotics_deploy_state {
        target_name: state.target_name,
        running: true,
        emergency_stop: state.emergency_stop,
    }
}


func robotics_deploy_stop(robotics_deploy_state state) robotics_deploy_state {
    robotics_deploy_state {
        target_name: state.target_name,
        running: false,
        emergency_stop: state.emergency_stop,
    }
}


func robotics_deploy_trigger_emergency_stop(robotics_deploy_state state) robotics_deploy_state {
    robotics_deploy_state {
        target_name: state.target_name,
        running: false,
        emergency_stop: true,
    }
}

