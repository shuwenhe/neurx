package neurx.logging








struct tensorboard_writer {
    bool initialized
    string log_dir
    string current_file
    int events_written


    file_handle output_file
}


func create_tensorboard_writer(string log_dir) tensorboard_writer {

    ensure_directory_exists(log_dir)


    string filename = "events.out.tfevents." + get_timestamp_string() + "." + get_hostname()
    string filepath = join_path(log_dir, filename)


    file_handle f = open_file_for_writing(filepath)

    tensorboard_writer {
        initialized: true,
        log_dir: log_dir,
        current_file: filepath,
        events_written: 0,
        output_file: f,
    }
}






func tb_write_scalar(
    tensorboard_writer *writer,
    string tag,
    float value,
    int step
) {
    if !writer.initialized { return }


    []byte summary_data = encode_scalar_summary(tag, value, step)


    write_event(writer.output_file, step, summary_data)

    writer.events_written = writer.events_written + 1
}
