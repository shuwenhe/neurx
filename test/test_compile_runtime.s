package neurx.test_compile_runtime

use neurx.compile.runtime.{runtime_status_state, runtime_available, ops_runtime_enabled, supports_runtime_function, runtime_status, runtime_status_state_dict, runtime_status_load_state_dict}

func main() int {
    if !runtime_available() {
        println("runtime_available failed")
        return 1
    }
    if !ops_runtime_enabled() {
        println("ops_runtime_enabled failed")
        return 1
    }
    if !supports_runtime_function("runtime/compile", "new_compile_state") {
        println("supports_runtime_function failed")
        return 1
    }

    runtime_status_state state = runtime_status()
    runtime_status_state snapshot = runtime_status_state_dict(state)
    runtime_status_state restored = runtime_status_load_state_dict(state, snapshot)
    if !restored.runtime_available {
        println("runtime_status state_dict failed")
        return 1
    }

    println("compile runtime test passed")
    0
}