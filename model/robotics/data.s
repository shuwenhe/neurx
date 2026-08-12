package neurx.model.robotics.data
struct robotics_dataset_state {
    string source_name
    int sample_count
    bool normalized
}

func new_robotics_dataset_state(string source_name, int sample_count) robotics_dataset_state {
    robotics_dataset_state {
        source_name: source_name,
        sample_count: sample_count,
        normalized: false,
    }
}

func robotics_dataset_state_dict(robotics_dataset_state state) robotics_dataset_state {
    state
}

func robotics_dataset_load_state_dict(robotics_dataset_state state, robotics_dataset_state other) robotics_dataset_state {
    other
}

func robotics_dataset_mark_normalized(robotics_dataset_state state) robotics_dataset_state {
    robotics_dataset_state {
        source_name: state.source_name,
        sample_count: state.sample_count,
        normalized: true,
    }
}

