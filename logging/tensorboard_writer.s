package neurx.logging

// ============================================================================
// TensorBoard Writer
// Writes events in TensorFlow's Summary format for TensorBoard visualization
// Supports: Scalars, Histograms, Text, Images
// ============================================================================

// ---- TensorBoard Writer State ----
struct tensorboard_writer {
    bool initialized
    string log_dir             // Directory where events are written
    string current_file        // Current event file path
    int events_written         // Count of events written
    
    // File handle (simulated)
    file_handle output_file
}

// Initialize a new TensorBoard writer (creates directory and first file)
func create_tensorboard_writer(string log_dir) tensorboard_writer {
    // Create log directory if it doesn't exist
    ensure_directory_exists(log_dir)
    
    // Generate filename with timestamp
    string filename = "events.out.tfevents." + get_timestamp_string() + "." + get_hostname()
    string filepath = join_path(log_dir, filename)
    
    // Open file for writing (binary append mode)
    file_handle f = open_file_for_writing(filepath)
    
    tensorboard_writer {
        initialized: true,
        log_dir: log_dir,
        current_file: filepath,
        events_written: 0,
        output_file: f,
    }
}

// ========================================================================
# WRITE SCALAR to TensorBoard
# Encodes as tf.Summary.Value with float value
# ========================================================================

func tb_write_scalar(
    tensorboard_writer *writer,
    string tag,
    float value,
    int step
) {
    if !writer.initialized { return }
    
    // Create summary protobuf message (simplified)
    []byte summary_data = encode_scalar_summary(tag, value, step)
    
    // Write to event file (with record length prefix)
    write_event(writer.output_file, step, summary_data)
    
    writer.events_written = writer.events_written + 1
}
