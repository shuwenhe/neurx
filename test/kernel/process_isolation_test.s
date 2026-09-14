package neurx.test.kernel

import (
    "neurx.kernel.process.PROCESS_OK"
    "neurx.kernel.process.clone_namespace"
    "neurx.kernel.process.find_process"
    "neurx.kernel.process.grant_capabilities"
    "neurx.kernel.process.may_manage_network"
    "neurx.kernel.process.may_use_accelerator"
    "neurx.kernel.process.process_isolation"
    "neurx.kernel.process.process_isolation_create"
    "neurx.kernel.process.spawn_isolated_process"
)

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0
    process_isolation isolation = process_isolation_create()
    isolation = clone_namespace(isolation, 10, 1, true, true, true, true)
    failures = failures + expect(isolation.last_result == PROCESS_OK() &&
        isolation.user_namespace[1] != isolation.user_namespace[0] &&
        isolation.network_namespace[1] != isolation.network_namespace[0],
        "clone independent user PID mount and network namespaces")

    isolation = spawn_isolated_process(isolation, 100, 1, 10, 7, 100, 1000, 1000)
    slot := find_process(isolation, 100)
    failures = failures + expect(isolation.last_result == PROCESS_OK() &&
        isolation.resource_domain[slot] == 7 && isolation.scheduler_task[slot] == 100,
        "bind process PID to resource domain and scheduler task")
    failures = failures + expect(!may_manage_network(isolation, 100, 10) &&
        !may_use_accelerator(isolation, 100, 7), "credentials deny ungranted capabilities")

    isolation = grant_capabilities(isolation, 1, 100, false, true, true)
    failures = failures + expect(may_manage_network(isolation, 100, 10) &&
        may_use_accelerator(isolation, 100, 7), "root grants namespace-scoped capabilities")
    failures = failures + expect(!may_manage_network(isolation, 100, 1) &&
        !may_use_accelerator(isolation, 100, 0), "capabilities cannot escape namespace or resource domain")
    return failures
}

func _start() int { return main() }
