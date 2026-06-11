package neurx.test_platform_config

use neurx.platform.config.{runtime_config, runtime_config_parse_result, bool_parse_result, int_parse_result, new_runtime_config, parse_bool_with_default, parse_optional_int, runtime_config_from_values, runtime_config_state_dict, runtime_config_load_state_dict}
use neurx.platform.errors.{platform_error_kind, platform_error_active}

func main() int {
    runtime_config cfg0 = new_runtime_config()
    if cfg0.default_device != "cpu" || cfg0.log_level != "INFO" {
        println("new_runtime_config defaults failed")
        return 1
    }

    bool_parse_result b1 = parse_bool_with_default("FLAG", " true ", false)
    if !b1.ok || !b1.value {
        println("parse_bool true failed")
        return 1
    }

    bool_parse_result b2 = parse_bool_with_default("FLAG", "Off", true)
    if !b2.ok || b2.value {
        println("parse_bool false failed")
        return 1
    }

    bool_parse_result b3 = parse_bool_with_default("FLAG", "", true)
    if !b3.ok || !b3.value {
        println("parse_bool default failed")
        return 1
    }

    bool_parse_result b4 = parse_bool_with_default("FLAG", "maybe", true)
    if b4.ok || !platform_error_active(b4.error) {
        println("parse_bool invalid failed")
        return 1
    }

    int_parse_result i1 = parse_optional_int("SEED", " 123 ")
    if !i1.ok || !i1.has_value || i1.value != 123 {
        println("parse_int value failed")
        return 1
    }

    int_parse_result i2 = parse_optional_int("SEED", "")
    if !i2.ok || i2.has_value {
        println("parse_int empty failed")
        return 1
    }

    int_parse_result i3 = parse_optional_int("SEED", "12x")
    if i3.ok || platform_error_kind(i3.error) != "ConfigurationError" {
        println("parse_int invalid failed")
        return 1
    }

    runtime_config_parse_result ok_cfg = runtime_config_from_values("npu", "1", "0", "debug", "yes", "42")
    if !ok_cfg.ok {
        println("runtime_config_from_values success failed")
        return 1
    }
    if ok_cfg.config.default_device != "npu" || ok_cfg.config.log_level != "DEBUG" || !ok_cfg.config.has_seed || ok_cfg.config.seed != 42 {
        println("runtime_config values incorrect")
        return 1
    }

    runtime_config_parse_result bad_device = runtime_config_from_values("bad", "1", "0", "INFO", "0", "")
    if bad_device.ok || platform_error_kind(bad_device.error) != "ConfigurationError" {
        println("runtime_config bad device failed")
        return 1
    }

    runtime_config_parse_result bad_seed = runtime_config_from_values("cpu", "1", "0", "INFO", "0", "-1")
    if bad_seed.ok || platform_error_kind(bad_seed.error) != "ConfigurationError" {
        println("runtime_config bad seed failed")
        return 1
    }

    runtime_config snapshot = runtime_config_state_dict(ok_cfg.config)
    runtime_config restored = runtime_config_load_state_dict(new_runtime_config(), snapshot)
    if restored.seed != 42 || !restored.has_seed {
        println("runtime_config state_dict failed")
        return 1
    }

    println("platform config test passed")
    0
}