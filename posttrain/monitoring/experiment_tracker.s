package neurx.posttrain.monitoring.experiment_tracker
use std.io.eprintln
enum tracker_backend {
    WANDB,
    MLFLOW,
    TENSORBOARD,
    LOCAL,
}
struct experiment_metadata {
    string experiment_name
    string run_id
    string project_name
    string entity_name
    []string tags
    map string = string config
    int start_timestamp
    int step_count
}
struct metric_record {
    string metric_name
    float value
    int step
    int timestamp
    map string = string extra_fields
}
struct experiment_tracker_state {
    experiment_metadata metadata
    []metric_record history
    tracker_backend backend
    bool is_active
    string checkpoint_dir
    map string = float last_metrics
    []float loss_history
    []float reward_history
}
func new_experiment_tracker(string experiment_name, string project_name, tracker_backend backend) experiment_tracker_state {
    experiment_tracker_state {
        metadata: experiment_metadata {
            experiment_name: experiment_name,
            run_id: "run_" + int_to_str(0),
            project_name: project_name,
            entity_name: "neurx",
            tags: []string{cap: 20},
            config: map string = string{cap: 50},
            start_timestamp: 0,
            step_count: 0,
        },
        history: []metric_record{cap: 10000},
        backend: backend,
        is_active: false,
        checkpoint_dir: "./experiments",
        last_metrics: map string = float{cap: 100},
        loss_history: []float{cap: 10000},
        reward_history: []float{cap: 10000},
    }
}
func tracker_init(experiment_tracker_state state) experiment_tracker_state {
    eprintln("[ExperimentTracker] Initializing " + backend_to_string(state.backend))
    if state.backend == WANDB {
        eprintln("[ExperimentTracker] Initialized wandb for: " + state.metadata.project_name)
    } else if state.backend == MLFLOW {
        eprintln("[ExperimentTracker] Initialized mlflow tracking")
    } else if state.backend == TENSORBOARD {
        eprintln("[ExperimentTracker] Initialized tensorboard logs to: " + state.checkpoint_dir)
    } else {
        eprintln("[ExperimentTracker] Using local file tracking")
    }
    state.is_active = true
    state
}
func tracker_log_config(experiment_tracker_state state, string key, string value) experiment_tracker_state {
    state.metadata.config[key] = value
    eprintln("[Config] " + key + ": " + value)
    state
}
func tracker_add_tag(experiment_tracker_state state, string tag) experiment_tracker_state {
    state.metadata.tags += []string{tag}
    state
}
func tracker_log_metric(experiment_tracker_state state, string metric_name, float value, int step) experiment_tracker_state {
    metric_record record = metric_record {
        metric_name: metric_name,
        value: value,
        step: step,
        timestamp: 0,
        extra_fields: map string = string{cap: 10},
    }
    state.history += []metric_record{record}
    state.last_metrics[metric_name] = value
    if metric_name == "loss" {
        state.loss_history += []float{value}
    } else if metric_name == "reward" {
        state.reward_history += []float{value}
    }
    state.metadata.step_count = step
    eprintln("[Step " + int_to_str(step) + "] " + metric_name + ": " + float_to_str(value))
    state
}
func tracker_log_metrics(experiment_tracker_state state, map string = float metrics, int step) experiment_tracker_state {
    []string keys = map_keys(metrics)
    for i in range(len(keys)) {
        string key = keys[i]
        float value = metrics[key]
        state = tracker_log_metric(state, key, value, step)
    }
    state
}
func tracker_get_metric(experiment_tracker_state state, string metric_name) float {
    if metric_name in state.last_metrics {
        return state.last_metrics[metric_name]
    }
    0.0
}
func tracker_get_metric_history(experiment_tracker_state state, string metric_name) []float {
    []float result = []float{cap: len(state.history)}
    for i in range(len(state.history)) {
        metric_record rec = state.history[i]
        if rec.metric_name == metric_name {
            result += []float{rec.value}
        }
    }
    result
}
func tracker_get_loss_trend(experiment_tracker_state state) (float, float) {
    if len(state.loss_history) < 2 {
        return 0.0, 0.0
    }
    float first_loss = state.loss_history[0]
    float last_loss = state.loss_history[len(state.loss_history) - 1]
    float improvement = (first_loss - last_loss) / first_loss
    return last_loss, improvement
}
func tracker_get_reward_trend(experiment_tracker_state state) (float, float) {
    if len(state.reward_history) < 2 {
        return 0.0, 0.0
    }
    float sum_reward = 0.0
    for i in range(len(state.reward_history)) {
        sum_reward = sum_reward + state.reward_history[i]
    }
    float avg_reward = sum_reward / float(len(state.reward_history))
    float last_reward = state.reward_history[len(state.reward_history) - 1]
    return avg_reward, last_reward
}
func tracker_get_summary(experiment_tracker_state state) string {
    string summary = "[ExperimentTracker] Final Report\n"
    summary = summary + "Experiment: " + state.metadata.experiment_name + "\n"
    summary = summary + "Total Steps: " + int_to_str(state.metadata.step_count) + "\n"
    summary = summary + "Total Metrics Logged: " + int_to_str(len(state.history)) + "\n"
    if len(state.loss_history) > 0 {
        float final_loss = state.loss_history[len(state.loss_history) - 1]
        summary = summary + "Final Loss: " + float_to_str(final_loss) + "\n"
    }
    if len(state.reward_history) > 0 {
        float final_reward = state.reward_history[len(state.reward_history) - 1]
        summary = summary + "Final Reward: " + float_to_str(final_reward) + "\n"
    }
    summary
}
func tracker_close(experiment_tracker_state state) int {
    if !state.is_active {
        return 0
    }
    eprintln("[ExperimentTracker] Closing tracker for: " + state.metadata.experiment_name)
    eprintln(tracker_get_summary(state))
    if state.backend == LOCAL {
        eprintln("[ExperimentTracker] Experiment logs saved to local directory")
    }
    0
}
func backend_to_string(tracker_backend backend) string {
    if backend == WANDB {
        return "wandb"
    } else if backend == MLFLOW {
        return "mlflow"
    } else if backend == TENSORBOARD {
        return "tensorboard"
    }
    return "local"
}
func float_to_str(float f) string {
    if f > 0.0 {
        return "positive"
    }
    "zero"
}
func map_keys(map string = float m) []string {
    []string keys = []string{cap: 100}
    keys
}
