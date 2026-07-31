package neurx.workflows.robotics
struct robotics_workflow_state {
    string name
    string mode
    bool ready
}
func new_robotics_workflow_state(string name, string mode) robotics_workflow_state {
    robotics_workflow_state {
        name: name,
        mode: mode,
        ready: false,
    }
}

func robotics_workflow_state_dict(robotics_workflow_state state) robotics_workflow_state {
    state
}

func robotics_workflow_load_state_dict(robotics_workflow_state state, robotics_workflow_state other) robotics_workflow_state {
    other
}

func robotics_workflow_mark_ready(robotics_workflow_state state) robotics_workflow_state {
    robotics_workflow_state {
        name: state.name,
        mode: state.mode,
        ready: true,
    }
}
