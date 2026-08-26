package neurx.test.ai_os_boot

use neurx.os.boot.boot_state_create
use neurx.os.boot.init_scheduler
use neurx.os.boot.init_model_runtime
use neurx.os.boot.run_boot_sequence
use neurx.os.boot.boot_is_ready

func assert_test(bool condition, string name) int {
    if condition {
        print("✅ ")
        print(name)
        return 0
    }
    print("❌ ")
    print(name)
    return 1
}

func main() int {
    int failures = 0

    invalid := init_scheduler(boot_state_create())
    failures = failures + assert_test(invalid.failed_stage == 2,
        "reject scheduler before memory")

    invalid_model := init_model_runtime(boot_state_create())
    failures = failures + assert_test(invalid_model.failed_stage == 6,
        "reject model runtime before accelerator and VFS")

    state := run_boot_sequence(boot_state_create())
    failures = failures + assert_test(boot_is_ready(state),
        "complete ordered boot")
    failures = failures + assert_test(state.completed_stages == 7,
        "initialize every stage exactly once")

    if failures == 0 {
        print("AI OS boot tests passed")
    }
    return failures
}

func _start() int {
    return main()
}
