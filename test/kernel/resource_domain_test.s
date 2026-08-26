package neurx.test.kernel

use neurx.kernel.resource.resource_controller
use neurx.kernel.resource.resource_controller_create
use neurx.kernel.resource.create_domain
use neurx.kernel.resource.charge
use neurx.kernel.resource.release
use neurx.kernel.resource.reset_period
use neurx.kernel.resource.bind_process
use neurx.kernel.resource.find_domain
use neurx.kernel.resource.RESOURCE_OK
use neurx.kernel.resource.RESOURCE_CPU_LIMIT
use neurx.kernel.resource.RESOURCE_MEMORY_LIMIT
use neurx.kernel.resource.RESOURCE_ACCELERATOR_LIMIT
use neurx.kernel.resource.RESOURCE_REALTIME_LIMIT

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0
    resource_controller controller = resource_controller_create()
    controller = create_domain(controller, 10, 0, 10000, 1024, 2, 5000000)
    failures = failures + expect(controller.last_result == RESOURCE_OK(), "create isolated AI resource domain")
    controller = bind_process(controller, 100, 10, 100)
    failures = failures + expect(controller.last_result == RESOURCE_OK() &&
        controller.binding_count == 1 && controller.bound_pid[0] == 100 &&
        controller.bound_domain[0] == 10 && controller.bound_scheduler_task[0] == 100,
        "bind PID to resource domain and scheduler identity")

    controller = charge(controller, 10, 3000, 256, 1, 1000000)
    slot := find_domain(controller, 10)
    failures = failures + expect(controller.last_result == RESOURCE_OK() &&
        controller.admitted_tasks[slot] == 1, "admit task within all budgets")

    controller = charge(controller, 10, 8000, 1, 0, 1)
    failures = failures + expect(controller.last_result == RESOURCE_CPU_LIMIT(), "reject CPU quota excess")
    controller = charge(controller, 10, 1, 800, 0, 1)
    failures = failures + expect(controller.last_result == RESOURCE_MEMORY_LIMIT(), "reject memory quota excess")
    controller = charge(controller, 10, 1, 1, 2, 1)
    failures = failures + expect(controller.last_result == RESOURCE_ACCELERATOR_LIMIT(), "reject accelerator quota excess")
    controller = charge(controller, 10, 1, 1, 0, 5000000)
    failures = failures + expect(controller.last_result == RESOURCE_REALTIME_LIMIT(), "reject realtime budget excess")

    controller = release(controller, 10, 256, 1)
    controller = reset_period(controller)
    failures = failures + expect(controller.memory_used_pages[slot] == 0 &&
        controller.accelerator_used[slot] == 0 && controller.cpu_used_us[slot] == 0,
        "release persistent resources and replenish period budgets")
    return failures
}

func _start() int { return main() }
