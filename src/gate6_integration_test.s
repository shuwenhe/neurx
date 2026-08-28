package neurx.scheduler

use neurx.scheduler
use neurx.scheduler.load_balance

func test_scheduler_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    queue_len := get_queue_length()
    if queue_len != 0 {
        failed = failed + 1
        return passed, failed, "Queue not empty after init"
    }

    passed = passed + 1
    return passed, failed, "test_scheduler_init passed"
}

func test_register_gpu_group() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    gpu_ids := vec[int]()
    gpu_ids.push(0)
    gpu_ids.push(1)

    reg_success, reg_err := register_gpu_group(0, gpu_ids, 2, 1)
    if !reg_success {
        failed = failed + 1
        return passed, failed, "Failed to register: " + reg_err
    }

    group, status_success, status_err := get_group_status(0)
    if !status_success {
        failed = failed + 1
        return passed, failed, "Failed to get status: " + status_err
    }

    if !group.is_available {
        failed = failed + 1
        return passed, failed, "Group not available"
    }

    passed = passed + 1
    return passed, failed, "test_register_gpu_group passed"
}

func test_submit_inference_task() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    input_ids := vec[int]()
    input_ids.push(1)
    input_ids.push(2)
    input_ids.push(3)

    task_id, submit_success, submit_err := submit_inference_task(input_ids, 32, 1)
    if !submit_success {
        failed = failed + 1
        return passed, failed, "Failed to submit: " + submit_err
    }

    if task_id <= 0 {
        failed = failed + 1
        return passed, failed, "Invalid task_id"
    }

    queue_len := get_queue_length()
    if queue_len != 1 {
        failed = failed + 1
        return passed, failed, "Queue length mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_submit_inference_task passed"
}

func test_get_next_task() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    input_ids := vec[int]()
    input_ids.push(1)

    submit_success, submit_err := submit_inference_task(input_ids, 32, 2)
    if !submit_success {
        failed = failed + 1
        return passed, failed, "Failed to submit: " + submit_err
    }

    task, get_success, get_err := get_next_task()
    if !get_success {
        failed = failed + 1
        return passed, failed, "Failed to get task: " + get_err
    }

    if task.batch_size != 32 {
        failed = failed + 1
        return passed, failed, "Batch size mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_get_next_task passed"
}

func test_allocate_gpu_group() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    gpu_ids := vec[int]()
    gpu_ids.push(0)
    gpu_ids.push(1)

    reg_success, reg_err := register_gpu_group(0, gpu_ids, 2, 1)
    if !reg_success {
        failed = failed + 1
        return passed, failed, "Failed to register: " + reg_err
    }

    group_id, alloc_success, alloc_err := allocate_gpu_group(32)
    if !alloc_success {
        failed = failed + 1
        return passed, failed, "Failed to allocate: " + alloc_err
    }

    if group_id != 0 {
        failed = failed + 1
        return passed, failed, "Wrong group allocated"
    }

    passed = passed + 1
    return passed, failed, "test_allocate_gpu_group passed"
}

func test_release_gpu_group() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    gpu_ids := vec[int]()
    gpu_ids.push(0)

    reg_success, reg_err := register_gpu_group(0, gpu_ids, 1, 1)
    if !reg_success {
        failed = failed + 1
        return passed, failed, "Failed to register: " + reg_err
    }

    release_success, release_err := release_gpu_group(0, 32)
    if !release_success {
        failed = failed + 1
        return passed, failed, "Failed to release: " + release_err
    }

    passed = passed + 1
    return passed, failed, "test_release_gpu_group passed"
}

func test_load_balancer_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := load_balance.load_balancer_init(4, 1)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_load_balancer_init passed"
}

func test_update_group_metrics() (int, int, string) {
    passed := 0
    failed := 0

    success, err := load_balance.load_balancer_init(4, 1)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    update_success, update_err := load_balance.update_group_metrics(0, 1000, 500, 10)
    if !update_success {
        failed = failed + 1
        return passed, failed, "Failed to update: " + update_err
    }

    metric, get_success, get_err := load_balance.get_group_metrics(0)
    if !get_success {
        failed = failed + 1
        return passed, failed, "Failed to get: " + get_err
    }

    if metric.queue_depth != 10 {
        failed = failed + 1
        return passed, failed, "Metric mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_update_group_metrics passed"
}

func test_check_load_imbalance() (int, int, string) {
    passed := 0
    failed := 0

    success, err := load_balance.load_balancer_init(4, 1)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    load_balance.update_group_metrics(0, 1000, 100, 20)
    load_balance.update_group_metrics(1, 100, 50, 1)

    imbalanced, check_success, check_err := load_balance.check_load_imbalance()
    if !check_success && imbalanced {
        failed = failed + 1
        return passed, failed, "Check failed: " + check_err
    }

    passed = passed + 1
    return passed, failed, "test_check_load_imbalance passed"
}

func test_get_most_loaded_group() (int, int, string) {
    passed := 0
    failed := 0

    success, err := load_balance.load_balancer_init(4, 1)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    load_balance.update_group_metrics(0, 1000, 100, 5)
    load_balance.update_group_metrics(1, 1000, 100, 15)
    load_balance.update_group_metrics(2, 1000, 100, 8)

    group_id, get_success, get_err := load_balance.get_most_loaded_group()
    if !get_success {
        failed = failed + 1
        return passed, failed, "Failed: " + get_err
    }

    if group_id != 1 {
        failed = failed + 1
        return passed, failed, "Wrong group returned"
    }

    passed = passed + 1
    return passed, failed, "test_get_most_loaded_group passed"
}

func test_get_least_loaded_group() (int, int, string) {
    passed := 0
    failed := 0

    success, err := load_balance.load_balancer_init(4, 1)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    load_balance.update_group_metrics(0, 1000, 100, 15)
    load_balance.update_group_metrics(1, 1000, 100, 2)
    load_balance.update_group_metrics(2, 1000, 100, 8)

    group_id, get_success, get_err := load_balance.get_least_loaded_group()
    if !get_success {
        failed = failed + 1
        return passed, failed, "Failed: " + get_err
    }

    if group_id != 1 {
        failed = failed + 1
        return passed, failed, "Wrong group returned"
    }

    passed = passed + 1
    return passed, failed, "test_get_least_loaded_group passed"
}

func test_task_status_management() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    input_ids := vec[int]()
    input_ids.push(1)

    task_id, submit_success, submit_err := submit_inference_task(input_ids, 32, 1)
    if !submit_success {
        failed = failed + 1
        return passed, failed, "Failed to submit: " + submit_err
    }

    status_success, status_err := set_task_status(task_id, 2)
    if !status_success {
        failed = failed + 1
        return passed, failed, "Failed to set status: " + status_err
    }

    passed = passed + 1
    return passed, failed, "test_task_status_management passed"
}

func test_scheduler_stats() (int, int, string) {
    passed := 0
    failed := 0

    success, err := scheduler_init(4, 1000)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    input_ids := vec[int]()
    input_ids.push(1)

    submit_inference_task(input_ids, 32, 1)
    submit_inference_task(input_ids, 64, 2)

    queue_len, tasks_done, total_time, stats_success, stats_err := get_scheduler_stats()
    if !stats_success {
        failed = failed + 1
        return passed, failed, "Failed: " + stats_err
    }

    if queue_len != 2 {
        failed = failed + 1
        return passed, failed, "Queue length mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_scheduler_stats passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_scheduler_init()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_register_gpu_group()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_submit_inference_task()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_get_next_task()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_allocate_gpu_group()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_release_gpu_group()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_load_balancer_init()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7 + " | "

    p8, f8, r8 := test_update_group_metrics()
    total_passed = total_passed + p8
    total_failed = total_failed + f8
    results = results + r8 + " | "

    p9, f9, r9 := test_check_load_imbalance()
    total_passed = total_passed + p9
    total_failed = total_failed + f9
    results = results + r9 + " | "

    p10, f10, r10 := test_get_most_loaded_group()
    total_passed = total_passed + p10
    total_failed = total_failed + f10
    results = results + r10 + " | "

    p11, f11, r11 := test_get_least_loaded_group()
    total_passed = total_passed + p11
    total_failed = total_failed + f11
    results = results + r11 + " | "

    p12, f12, r12 := test_task_status_management()
    total_passed = total_passed + p12
    total_failed = total_failed + f12
    results = results + r12 + " | "

    p13, f13, r13 := test_scheduler_stats()
    total_passed = total_passed + p13
    total_failed = total_failed + f13
    results = results + r13

    return total_passed, total_failed, results
}
