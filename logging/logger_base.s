package neurx.logging
enum log_level {
    DEBUG,
    INFO,
    WARNING,
    ERROR,
}
enum metric_type {
    SCALAR,
    HISTOGRAM,
    IMAGE,
    AUDIO,
    TEXT,
    TABLE,
    SCALAR_LIST,
}
struct log_entry {
    float timestamp
    log_level level
    string message
    map[string]any metadata
}

struct metric_entry {
    int step
    string name
    metric_type type
    float scalar_value
    []float histogram_values
    []float scalar_list
    map<string]string tags
    float wall_time
}
