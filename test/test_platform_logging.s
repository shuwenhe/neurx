package neurx.test_platform_logging

use neurx.platform.logging.{logger_state, configure_logging, get_logger, logger_state_dict, logger_load_state_dict}

func main() int {
    logger_state base = configure_logging("debug")
    if !base.configured || base.level != "DEBUG" {
        println("configure_logging failed")
        return 1
    }

    logger_state child = get_logger("train")
    if child.name != "neurx.train" {
        println("get_logger child name failed")
        return 1
    }

    logger_state snapshot = logger_state_dict(child)
    logger_state restored = logger_load_state_dict(base, snapshot)
    if restored.name != "neurx.train" || restored.level == "" {
        println("logger state_dict failed")
        return 1
    }

    println("platform logging test passed")
    0
}