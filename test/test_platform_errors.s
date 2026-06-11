package neurx.test_platform_errors

use neurx.platform.errors.{platform_error_state, new_tensor_error, new_configuration_error, new_backend_not_available_error, new_runtime_validation_error, clear_error, platform_error_kind, platform_error_message, platform_error_active, platform_error_state_dict, platform_error_load_state_dict}

func main() int {
    platform_error_state e1 = new_tensor_error("base")
    if !platform_error_active(e1) || platform_error_kind(e1) != "TensorError" {
        println("tensor error failed")
        return 1
    }

    platform_error_state e2 = new_configuration_error("bad config")
    if platform_error_kind(e2) != "ConfigurationError" {
        println("configuration error failed")
        return 1
    }

    platform_error_state e3 = new_backend_not_available_error("cuda missing")
    if platform_error_kind(e3) != "BackendNotAvailableError" {
        println("backend error failed")
        return 1
    }

    platform_error_state e4 = new_runtime_validation_error("runtime bad")
    if platform_error_kind(e4) != "RuntimeValidationError" {
        println("runtime validation error failed")
        return 1
    }

    platform_error_state copied = platform_error_state_dict(e2)
    platform_error_state loaded = platform_error_load_state_dict(clear_error(), copied)
    if !platform_error_active(loaded) || platform_error_message(loaded) != "bad config" {
        println("error state_dict failed")
        return 1
    }

    platform_error_state empty = clear_error()
    if platform_error_active(empty) {
        println("clear_error failed")
        return 1
    }

    println("platform errors test passed")
    0
}