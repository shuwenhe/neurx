package neurx.platform.logging
use neurx.platform.config.{runtime_config_parse_result, get_runtime_config}

struct logger_state {
    string name
    string level
    bool configured
    string format
    string date_format
    int child_count
}


func configure_logging(string level) logger_state {
    runtime_config_parse_result cfg_out = get_runtime_config()
    string target_level = level
    if trim(target_level) == "" {
        target_level = cfg_out.config.log_level
    }
    logger_state {
        name: "neurx",
        level: upper(trim(target_level)),
        configured: true,
        format: "%Y-%m-%d %H:%M:%S | LEVEL | NAME | MESSAGE",
        date_format: "%Y-%m-%d %H:%M:%S",
        child_count: 0,
    }
}


func get_logger(string name) logger_state {
    logger_state base = configure_logging("")
    if trim(name) == "" {
        return base
    }
    logger_state {
        name: base.name + "." + trim(name),
        level: base.level,
        configured: true,
        format: base.format,
        date_format: base.date_format,
        child_count: base.child_count + 1,
    }
}


func logger_state_dict(logger_state state) logger_state {
    logger_state {
        name: state.name,
        level: state.level,
        configured: state.configured,
        format: state.format,
        date_format: state.date_format,
        child_count: state.child_count,
    }
}


func logger_load_state_dict(logger_state state, logger_state other) logger_state {
    logger_state {
        name: other.name,
        level: other.level,
        configured: other.configured,
        format: other.format,
        date_format: other.date_format,
        child_count: other.child_count,
    }
}

