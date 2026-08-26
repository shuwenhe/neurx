package neurx.test.kernel

use neurx.kernel.process.process_isolation
use neurx.kernel.process.process_isolation_create
use neurx.kernel.resource.resource_controller
use neurx.kernel.resource.resource_controller_create
use neurx.kernel.resource.create_domain
use neurx.kernel.core.execution_core
use neurx.kernel.core.execution_core_create
use neurx.kernel.process.transaction.process_spawn_transaction
use neurx.kernel.process.transaction.spawn_transaction_result
use neurx.kernel.process.transaction.SPAWN_OK
use neurx.kernel.process.transaction.SPAWN_RESOURCE_FAILED
use neurx.kernel.process.transaction.SPAWN_CREDENTIAL_FAILED

func expect(bool condition, string name) int {
    if condition { print("PASS " + name); return 0 }
    print("FAIL " + name)
    return 1
}

func main() int {
    int failures = 0
    process_isolation isolation = process_isolation_create()
    resource_controller resources = resource_controller_create()
    resources = create_domain(resources, 7, 0, 10000, 1024, 2, 5000000)
    execution_core scheduler = execution_core_create(4)

    spawn_transaction_result result = process_spawn_transaction(
        isolation, resources, scheduler,
        100, 1, 10, 1, true, 7, 20, -1,
        4000000, 500000, 1000, 1000,
        3000, 256, 1, 1000000)
    isolation = result.isolation
    resources = result.resources
    scheduler = result.scheduler
    int status = result.status
    failures = failures + expect(status == SPAWN_OK() &&
        isolation.process_count == 2 && isolation.namespace_count == 2 &&
        resources.binding_count == 1 && scheduler.task_count == 1 &&
        scheduler.task_id[0] == 100,
        "commit namespace credentials resources and scheduler atomically")

    process_before := isolation.process_count
    namespace_before := isolation.namespace_count
    binding_before := resources.binding_count
    task_before := scheduler.task_count
    memory_before := resources.memory_used_pages[1]
    result = process_spawn_transaction(
        isolation, resources, scheduler,
        101, 1, 11, 1, true, 7, 10, -1,
        5000000, 500000, 1000, 1000,
        1, 900, 0, 1)
    isolation = result.isolation
    resources = result.resources
    scheduler = result.scheduler
    status = result.status
    failures = failures + expect(status == SPAWN_RESOURCE_FAILED() &&
        isolation.process_count == process_before &&
        isolation.namespace_count == namespace_before &&
        resources.binding_count == binding_before &&
        resources.memory_used_pages[1] == memory_before &&
        scheduler.task_count == task_before,
        "resource failure rolls back namespace and all subsystem state")

    result = process_spawn_transaction(
        isolation, resources, scheduler,
        102, 999, 12, 1, true, 7, 10, -1,
        5000000, 500000, 1000, 1000,
        1, 1, 0, 1)
    isolation = result.isolation
    resources = result.resources
    scheduler = result.scheduler
    status = result.status
    failures = failures + expect(status == SPAWN_CREDENTIAL_FAILED() &&
        isolation.namespace_count == namespace_before &&
        resources.binding_count == binding_before &&
        scheduler.task_count == task_before,
        "credential creation failure rolls back charge binding and namespace")
    return failures
}

func _start() int { return main() }
