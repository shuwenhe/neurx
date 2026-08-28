package neurx.observability.logging
struct logger_config {
    string experiment_name
    string run_name
    string log_dir
    bool log_to_console
    bool log_to_file
    bool log_to_tensorboard
    bool log_to_wandb
    log_level console_level
    bool colorize_output
    bool show_progress_bar
    string tensorboard_dir
    int flush_every_n_steps
    string wandb_project
    string wandb_entity
    map[string]string wandb_config
    int global_step_offset
    float log_frequency
}
func default_logger_config() logger_config {
    logger_config {
        experiment_name: "neurx_experiment",
        run_name: "",
        log_dir: "./logs",
        log_to_console: true,
        log_to_file: false,
        log_to_tensorboard: true,
        log_to_wandb: false,
        console_level: log_level.INFO,
        colorize_output: true,
        show_progress_bar: true,
        tensorboard_dir: "./logs/tensorboard",
        flush_every_n_steps: 100,
        wandb_project: "neurx-training",
        wandb_entity: "",
        wandb_config: {},
        global_step_offset: 0,
        log_frequency: 1.0,
    }
}
struct logger {
    logger_config config
    int current_step
    []metric_entry metric_buffer
    []log_entry message_buffer
    tensorboard_writer tb_writer
    wandb_run wb_run
}
