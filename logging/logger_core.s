package neurx.logging

// ============================================================================
// Logger Core - Main interface for logging during training
// ============================================================================

// ---- Logger Configuration ----
struct logger_config {
    string experiment_name     // Experiment identifier
    string run_name            // Specific run name (for WandB)
    string log_dir             // Directory for log files
    
    // Which backends to enable
    bool log_to_console        // Print to stdout/stderr
    bool log_to_file           // Write to text file (JSON lines format)
    bool log_to_tensorboard    // Write TensorBoard event files
    bool log_to_wandb          // Send to Weights & Biases cloud service
    
    // Console settings
    log_level console_level    // Minimum level to display on console
    bool colorize_output       // Use ANSI color codes
    bool show_progress_bar     // Show training progress bar
    
    // TensorBoard settings
    string tensorboard_dir     // Directory for TB event files
    int flush_every_n_steps    // How often to flush TB writer (default: 100)
    
    // WandB settings
    string wandb_project       // WandB project name
    string wandb_entity        // Username or team name
    map[string]string wandb_config  // Config to log with run (hyperparams etc.)
    
    // General settings
    int global_step_offset      // Add this to all step numbers
    float log_frequency         // How often to log metrics (in steps)
}

// Default configuration suitable for most use cases
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
        log_frequency: 1.0,  // Log every step
    }
}

// ---- Logger State ----
struct logger {
    logger_config config
    int current_step           // Global step counter
    
    // Buffered entries (for batching)
    []metric_entry metric_buffer
    []log_entry message_buffer
    
    // Backend-specific state
    tensorboard_writer tb_writer
    wandb_run wb_run
}
