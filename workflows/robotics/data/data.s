package neurx.workflows.robotics.data

use neurx.model.robotics.data.{robotics_dataset_state}

func new_robotics_dataset_state(string source_name, int sample_count) robotics_dataset_state {
    neurx.model.robotics.data.new_robotics_dataset_state(source_name, sample_count)
}

func robotics_dataset_state_dict(robotics_dataset_state state) robotics_dataset_state {
    neurx.model.robotics.data.robotics_dataset_state_dict(state)
}

func robotics_dataset_load_state_dict(robotics_dataset_state state, robotics_dataset_state other) robotics_dataset_state {
    neurx.model.robotics.data.robotics_dataset_load_state_dict(state, other)
}

func robotics_dataset_mark_normalized(robotics_dataset_state state) robotics_dataset_state {
    neurx.model.robotics.data.robotics_dataset_mark_normalized(state)
}
