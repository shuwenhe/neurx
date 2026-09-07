package neurx.kernel.process.transaction

use neurx.kernel.process.process_isolation
use neurx.kernel.process.clone_namespace
use neurx.kernel.process.spawn_isolated_process
use neurx.kernel.process.PROCESS_OK
use neurx.kernel.resource.resource_controller
use neurx.kernel.resource.charge
use neurx.kernel.resource.bind_process
use neurx.kernel.resource.RESOURCE_OK
use neurx.kernel.core.execution_core
use neurx.kernel.core.enqueue_task

func SPAWN_OK() int { 0 }

func SPAWN_NAMESPACE_FAILED() int { 1 }

func SPAWN_RESOURCE_FAILED() int { 2 }

func SPAWN_BIND_FAILED() int { 3 }

func SPAWN_CREDENTIAL_FAILED() int { 4 }

func SPAWN_SCHEDULER_FAILED() int { 5 }

struct spawn_transaction_result {
    process_isolation isolation
    resource_controller resources
    execution_core scheduler
    int status
}

func spawn_result(process_isolation isolation, resource_controller resources,
                  execution_core scheduler, int status) spawn_transaction_result {
    spawn_transaction_result {
        isolation: isolation, resources: resources, scheduler: scheduler, status: status
    }
}

func process_spawn_transaction(
    process_isolation isolation,
    resource_controller resources,
    execution_core scheduler,
    int pid, int parent_pid, int namespace_id, int parent_namespace,
    bool create_namespace, int resource_domain, int priority, int affinity,
    int deadline_ns, int slice_ns, int uid, int gid,
    int cpu_charge_us, int memory_pages, int accelerators, int realtime_ns
) spawn_transaction_result {
    process_isolation original_isolation = isolation
    resource_controller original_resources = resources
    execution_core original_scheduler = scheduler
    process_isolation working_isolation = isolation
    resource_controller working_resources = resources
    execution_core working_scheduler = scheduler

    if create_namespace {
        working_isolation = clone_namespace(working_isolation, namespace_id, parent_namespace,
            true, true, true, true)
        if working_isolation.last_result != PROCESS_OK() {
            return spawn_result(original_isolation, original_resources, original_scheduler, SPAWN_NAMESPACE_FAILED())
        }
    }

    working_resources = charge(working_resources, resource_domain, cpu_charge_us,
        memory_pages, accelerators, realtime_ns)
    if working_resources.last_result != RESOURCE_OK() {
        return spawn_result(original_isolation, original_resources, original_scheduler, SPAWN_RESOURCE_FAILED())
    }

    working_resources = bind_process(working_resources, pid, resource_domain, pid)
    if working_resources.last_result != RESOURCE_OK() {
        return spawn_result(original_isolation, original_resources, original_scheduler, SPAWN_BIND_FAILED())
    }

    working_isolation = spawn_isolated_process(working_isolation, pid, parent_pid,
        namespace_id, resource_domain, pid, uid, gid)
    if working_isolation.last_result != PROCESS_OK() {
        return spawn_result(original_isolation, original_resources, original_scheduler, SPAWN_CREDENTIAL_FAILED())
    }

    int old_task_count = working_scheduler.task_count
    working_scheduler = enqueue_task(working_scheduler, pid, priority, affinity, deadline_ns, slice_ns)
    if working_scheduler.task_count != old_task_count + 1 {
        return spawn_result(original_isolation, original_resources, original_scheduler, SPAWN_SCHEDULER_FAILED())
    }

    return spawn_result(working_isolation, working_resources, working_scheduler, SPAWN_OK())
}
