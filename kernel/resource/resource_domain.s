package neurx.kernel.resource

func RESOURCE_OK() int { 0 }
func RESOURCE_INVALID_DOMAIN() int { 1 }
func RESOURCE_CPU_LIMIT() int { 2 }
func RESOURCE_MEMORY_LIMIT() int { 3 }
func RESOURCE_ACCELERATOR_LIMIT() int { 4 }
func RESOURCE_REALTIME_LIMIT() int { 5 }
func RESOURCE_DOMAIN_LIMIT() int { 6 }

struct resource_controller {
    int domain_count
    int[64] domain_id
    int[64] parent_id
    int[64] cpu_quota_us
    int[64] cpu_used_us
    int[64] memory_limit_pages
    int[64] memory_used_pages
    int[64] accelerator_limit
    int[64] accelerator_used
    int[64] realtime_budget_ns
    int[64] realtime_used_ns
    int[64] admitted_tasks
    int[64] rejected_tasks
    int binding_count
    int[1024] bound_pid
    int[1024] bound_domain
    int[1024] bound_scheduler_task
    int last_result
}

func resource_controller_create() resource_controller {
    controller := resource_controller {
        domain_count: 1,
        domain_id: int[64]{}, parent_id: int[64]{},
        cpu_quota_us: int[64]{}, cpu_used_us: int[64]{},
        memory_limit_pages: int[64]{}, memory_used_pages: int[64]{},
        accelerator_limit: int[64]{}, accelerator_used: int[64]{},
        realtime_budget_ns: int[64]{}, realtime_used_ns: int[64]{},
        admitted_tasks: int[64]{}, rejected_tasks: int[64]{},
        binding_count: 0, bound_pid: int[1024]{},
        bound_domain: int[1024]{}, bound_scheduler_task: int[1024]{},
        last_result: RESOURCE_OK()
    }
    controller.domain_id[0] = 0
    controller.parent_id[0] = -1
    controller.cpu_quota_us[0] = 1000000000
    controller.memory_limit_pages[0] = 1000000000
    controller.accelerator_limit[0] = 1000000
    controller.realtime_budget_ns[0] = 1000000000
    return controller
}

func bind_process(resource_controller controller, int pid, int domain,
                  int scheduler_task) resource_controller {
    if find_domain(controller, domain) < 0 || controller.binding_count >= 1024 {
        controller.last_result = RESOURCE_INVALID_DOMAIN()
        return controller
    }
    int i = 0
    for i < controller.binding_count {
        if controller.bound_pid[i] == pid {
            controller.last_result = RESOURCE_INVALID_DOMAIN()
            return controller
        }
        i = i + 1
    }
    slot := controller.binding_count
    controller.bound_pid[slot] = pid
    controller.bound_domain[slot] = domain
    controller.bound_scheduler_task[slot] = scheduler_task
    controller.binding_count = controller.binding_count + 1
    controller.last_result = RESOURCE_OK()
    return controller
}

func find_domain(resource_controller controller, int id) int {
    int i = 0
    for i < controller.domain_count {
        if controller.domain_id[i] == id { return i }
        i = i + 1
    }
    return -1
}

func create_domain(resource_controller controller, int id, int parent,
                   int cpu_us, int memory_pages, int accelerators,
                   int realtime_ns) resource_controller {
    if controller.domain_count >= 64 {
        controller.last_result = RESOURCE_DOMAIN_LIMIT()
        return controller
    }
    parent_slot := find_domain(controller, parent)
    if parent_slot < 0 || find_domain(controller, id) >= 0 {
        controller.last_result = RESOURCE_INVALID_DOMAIN()
        return controller
    }
    if cpu_us > controller.cpu_quota_us[parent_slot] ||
       memory_pages > controller.memory_limit_pages[parent_slot] ||
       accelerators > controller.accelerator_limit[parent_slot] ||
       realtime_ns > controller.realtime_budget_ns[parent_slot] {
        controller.last_result = RESOURCE_INVALID_DOMAIN()
        return controller
    }
    slot := controller.domain_count
    controller.domain_id[slot] = id
    controller.parent_id[slot] = parent
    controller.cpu_quota_us[slot] = cpu_us
    controller.memory_limit_pages[slot] = memory_pages
    controller.accelerator_limit[slot] = accelerators
    controller.realtime_budget_ns[slot] = realtime_ns
    controller.domain_count = controller.domain_count + 1
    controller.last_result = RESOURCE_OK()
    return controller
}

func reject_charge(resource_controller controller, int slot, int reason) resource_controller {
    controller.rejected_tasks[slot] = controller.rejected_tasks[slot] + 1
    controller.last_result = reason
    return controller
}

func charge(resource_controller controller, int id, int cpu_us,
            int memory_pages, int accelerators, int realtime_ns) resource_controller {
    slot := find_domain(controller, id)
    if slot < 0 {
        controller.last_result = RESOURCE_INVALID_DOMAIN()
        return controller
    }
    if controller.cpu_used_us[slot] + cpu_us > controller.cpu_quota_us[slot] {
        return reject_charge(controller, slot, RESOURCE_CPU_LIMIT())
    }
    if controller.memory_used_pages[slot] + memory_pages > controller.memory_limit_pages[slot] {
        return reject_charge(controller, slot, RESOURCE_MEMORY_LIMIT())
    }
    if controller.accelerator_used[slot] + accelerators > controller.accelerator_limit[slot] {
        return reject_charge(controller, slot, RESOURCE_ACCELERATOR_LIMIT())
    }
    if controller.realtime_used_ns[slot] + realtime_ns > controller.realtime_budget_ns[slot] {
        return reject_charge(controller, slot, RESOURCE_REALTIME_LIMIT())
    }
    controller.cpu_used_us[slot] = controller.cpu_used_us[slot] + cpu_us
    controller.memory_used_pages[slot] = controller.memory_used_pages[slot] + memory_pages
    controller.accelerator_used[slot] = controller.accelerator_used[slot] + accelerators
    controller.realtime_used_ns[slot] = controller.realtime_used_ns[slot] + realtime_ns
    controller.admitted_tasks[slot] = controller.admitted_tasks[slot] + 1
    controller.last_result = RESOURCE_OK()
    return controller
}

func release(resource_controller controller, int id, int memory_pages,
             int accelerators) resource_controller {
    slot := find_domain(controller, id)
    if slot < 0 { controller.last_result = RESOURCE_INVALID_DOMAIN(); return controller }
    controller.memory_used_pages[slot] = controller.memory_used_pages[slot] - memory_pages
    controller.accelerator_used[slot] = controller.accelerator_used[slot] - accelerators
    if controller.memory_used_pages[slot] < 0 { controller.memory_used_pages[slot] = 0 }
    if controller.accelerator_used[slot] < 0 { controller.accelerator_used[slot] = 0 }
    controller.last_result = RESOURCE_OK()
    return controller
}

func reset_period(resource_controller controller) resource_controller {
    int i = 0
    for i < controller.domain_count {
        controller.cpu_used_us[i] = 0
        controller.realtime_used_ns[i] = 0
        i = i + 1
    }
    controller.last_result = RESOURCE_OK()
    return controller
}
