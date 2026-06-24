package neurx.logging

// ============================================================================
// Training Logger & Monitoring System
// Supports: Console, File, TensorBoard, Weights & Biases (WandB)
// Tracks: Loss, Learning Rate, Throughput, GPU Memory, Custom Metrics
// ============================================================================

// ---- Log Level ----
enum log_level {
    DEBUG,
    INFO,
    WARNING,
    ERROR,
}

// ---- Metric Types ----
enum metric_type {
    SCALAR,       // Single value (loss, accuracy)
    HISTOGRAM,    // Distribution (gradient norms, activation stats)
    IMAGE,        // Image (attention maps, generated samples)
    AUDIO,        // Audio waveform (for speech models)
    TEXT,         // Text string (generated text samples)
    TABLE,        // Table data (hyperparameters, results)
    SCALAR_LIST,  // List of scalars (loss per step)
}

// ---- Log Entry ----
struct log_entry {
    float timestamp           // Unix timestamp
    log_level level
    string message
    map[string]any metadata   // Additional structured data
}

// ---- Metric Entry ----
struct metric_entry {
    int step                  // Global training step
    string name               // Metric name ("train_loss", "lr", etc.)
    metric_type type
    
    // Value depends on type
    float scalar_value
    []float histogram_values  // For histograms
    []float scalar_list      // For line plots
    map<string]string tags     // For grouping/filtering (e.g., "split": "train")
    
    // Metadata
    float wall_time           // Real time when logged
}
