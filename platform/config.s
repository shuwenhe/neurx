package neurx.platform.config
use neurx.platform.errors.{platform_error_state, new_configuration_error, clear_error, platform_error_active}
struct runtime_config {
    string default_device
    bool fallback_to_cpu
    bool strict_checks
    string log_level
    bool deterministic
    int seed
    bool has_seed
}

struct bool_parse_result {
    bool value
    bool ok
    platform_error_state error
}

struct int_parse_result {
    int value
    bool has_value
    bool ok
    platform_error_state error
}

func make_bool_parse_result(bool value, bool ok, error platform_error_state) bool_parse_result {
    bool_parse_result {
        value: value,
        ok: ok,
        error: error,
    }
}

func make_int_parse_result(int value, bool has_value, bool ok, error platform_error_state) int_parse_result {
    int_parse_result {
        value: value,
        has_value: has_value,
        ok: ok,
        error: error,
    }
}

func make_runtime_config_parse_result(runtime_config cfg, bool ok, error platform_error_state) runtime_config_parse_result {
    runtime_config_parse_result {
        config: cfg,
        ok: ok,
        error: error,
    }
}

func new_runtime_config() runtime_config {
    runtime_config {
        default_device: "cpu",
        fallback_to_cpu: true,
        strict_checks: false,
        log_level: "INFO",
        deterministic: false,
        seed: 0,
        has_seed: false,
    }
}

func normalize_for_parse(string value) string {
    lower(trim(value))
}

func normalize_device(string value) string {
    string out = normalize_for_parse(value)
    if out == "" {
        return "cpu"
    }
    out
}

func normalize_log_level(string value) string {
    string out = upper(trim(value))
    if out == "" {
        return "INFO"
    }
    out
}

func is_valid_device(string value) bool {
    string out = normalize_device(value)
    out == "cpu" || out == "cuda" || out == "mps" || out == "npu"
}

func is_valid_log_level(string value) bool {
    string out = normalize_log_level(value)
    out == "CRITICAL" || out == "ERROR" || out == "WARNING" || out == "INFO" || out == "DEBUG"
}

func parse_bool_with_default(string name, string value, bool default_value) bool_parse_result {
    string v = normalize_for_parse(value)
    if v == "" {
        return make_bool_parse_result(default_value, true, clear_error())
    }
    if v == "1" || v == "true" || v == "on" || v == "yes" {
        return make_bool_parse_result(true, true, clear_error())
    }
    if v == "0" || v == "false" || v == "off" || v == "no" {
        return make_bool_parse_result(false, true, clear_error())
    }
    make_bool_parse_result(default_value, false, new_configuration_error(name + " expects bool-like value, got: " + value))
}

func is_digit_char(string ch) bool {
    ch >= "0" && ch <= "9"
}

func config_substring(string s, int from, int to) string {
    string result = ""
    int i = from
    while i < to && i < len(s) {
        result = result + string(s[i])
        i = i + 1
    }
    result
}

func is_valid_int_literal(string value) bool {
    string v = trim(value)
    if len(v) == 0 {
        return false
    }
    int start = 0
    string first_char = config_substring(v, 0, 1)
    if first_char == "+" || first_char == "-" {
        if len(v) == 1 {
            return false
        }
        start = 1
    }
    int i = start
    while i < len(v) {
        string digit_char = config_substring(v, i, i + 1)
        if !is_digit_char(digit_char) {
            return false
        }
        i = i + 1
    }
    true
}

func parse_optional_int(string name, string value) int_parse_result {
    string v = trim(value)
    if v == "" {
        return make_int_parse_result(0, false, true, clear_error())
    }
    if !is_valid_int_literal(v) {
        return make_int_parse_result(0, false, false, new_configuration_error(name + " expects int value, got: " + value))
    }
    make_int_parse_result(int(v), true, true, clear_error())
}

func config_error(string message) runtime_config_parse_result {
    make_runtime_config_parse_result(new_runtime_config(), false, new_configuration_error(message))
}

struct runtime_config_parse_result {
    runtime_config config
    bool ok
    platform_error_state error
}

func validate_runtime_config(runtime_config cfg) platform_error_state {
    if !is_valid_device(cfg.default_device) {
        return new_configuration_error("TENSOR_DEVICE must be one of {cpu,cuda,mps,npu}")
    }
    if !is_valid_log_level(cfg.log_level) {
        return new_configuration_error("TENSOR_LOG_LEVEL must be one of {CRITICAL,ERROR,WARNING,INFO,DEBUG}")
    }
    if cfg.has_seed && cfg.seed < 0 {
        return new_configuration_error("TENSOR_SEED must be >= 0")
    }
    clear_error()
}

func runtime_config_from_values(
    string device,
    string fallback_to_cpu,
    string strict_checks,
    string log_level,
    string deterministic,
    string seed,
) runtime_config_parse_result {
    runtime_config cfg = new_runtime_config()
    cfg.default_device = normalize_device(device)
    cfg.log_level = normalize_log_level(log_level)
    bool_parse_result fallback_out = parse_bool_with_default("TENSOR_FALLBACK_TO_CPU", fallback_to_cpu, true)
    if !fallback_out.ok {
        return make_runtime_config_parse_result(cfg, false, fallback_out.error)
    }
    cfg.fallback_to_cpu = fallback_out.value
    bool_parse_result strict_out = parse_bool_with_default("TENSOR_STRICT_CHECKS", strict_checks, false)
    if !strict_out.ok {
        return make_runtime_config_parse_result(cfg, false, strict_out.error)
    }
    cfg.strict_checks = strict_out.value
    bool_parse_result deterministic_out = parse_bool_with_default("TENSOR_DETERMINISTIC", deterministic, false)
    if !deterministic_out.ok {
        return make_runtime_config_parse_result(cfg, false, deterministic_out.error)
    }
    cfg.deterministic = deterministic_out.value
    int_parse_result seed_out = parse_optional_int("TENSOR_SEED", seed)
    if !seed_out.ok {
        return make_runtime_config_parse_result(cfg, false, seed_out.error)
    }
    cfg.has_seed = seed_out.has_value
    cfg.seed = seed_out.value
    platform_error_state validation = validate_runtime_config(cfg)
    if platform_error_active(validation) {
        return make_runtime_config_parse_result(cfg, false, validation)
    }
    make_runtime_config_parse_result(cfg, true, clear_error())
}

func get_runtime_config() runtime_config_parse_result {
    runtime_config_from_values(
        env_get("TENSOR_DEVICE", "cpu"),
        env_get("TENSOR_FALLBACK_TO_CPU", "true"),
        env_get("TENSOR_STRICT_CHECKS", "false"),
        env_get("TENSOR_LOG_LEVEL", "INFO"),
        env_get("TENSOR_DETERMINISTIC", "false"),
        env_get("TENSOR_SEED", "")
    )
}

func runtime_config_state_dict(runtime_config cfg) runtime_config {
    runtime_config {
        default_device: cfg.default_device,
        fallback_to_cpu: cfg.fallback_to_cpu,
        strict_checks: cfg.strict_checks,
        log_level: cfg.log_level,
        deterministic: cfg.deterministic,
        seed: cfg.seed,
        has_seed: cfg.has_seed,
    }
}

func runtime_config_load_state_dict(runtime_config cfg, runtime_config other) runtime_config {
    runtime_config {
        default_device: other.default_device,
        fallback_to_cpu: other.fallback_to_cpu,
        strict_checks: other.strict_checks,
        log_level: other.log_level,
        deterministic: other.deterministic,
        seed: other.seed,
        has_seed: other.has_seed,
    }
}
