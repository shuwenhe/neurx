package neurx.cluster

use neurx.cluster.cluster_comm
use neurx.cluster.topology
use neurx.cluster.coordinator

func test_cluster_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    config, config_success, config_err := cluster_comm.get_cluster_config()
    if !config_success {
        failed = failed + 1
        return passed, failed, "Failed to get config: " + config_err
    }

    if config.num_nodes != 8 {
        failed = failed + 1
        return passed, failed, "Config mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_cluster_init passed"
}

func test_register_node() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    reg_success, reg_err := cluster_comm.register_node(0, "node-0", 8)
    if !reg_success {
        failed = failed + 1
        return passed, failed, "Failed to register: " + reg_err
    }

    node, node_success, node_err := cluster_comm.get_node_info(0)
    if !node_success {
        failed = failed + 1
        return passed, failed, "Failed to get node: " + node_err
    }

    if !node.is_active {
        failed = failed + 1
        return passed, failed, "Node not active"
    }

    passed = passed + 1
    return passed, failed, "test_register_node passed"
}

func test_connect_peer() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    peer_success, peer_err := cluster_comm.connect_peer(1, 1, "192.168.1.1", 6379)
    if !peer_success {
        failed = failed + 1
        return passed, failed, "Failed to connect: " + peer_err
    }

    passed = passed + 1
    return passed, failed, "test_connect_peer passed"
}

func test_cluster_stream() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    stream_id, stream_success, stream_err := cluster_comm.create_cluster_stream(0, 1)
    if !stream_success {
        failed = failed + 1
        return passed, failed, "Failed to create stream: " + stream_err
    }

    if stream_id < 0 {
        failed = failed + 1
        return passed, failed, "Invalid stream_id"
    }

    passed = passed + 1
    return passed, failed, "test_cluster_stream passed"
}

func test_send_across_nodes() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    send_success, send_err := cluster_comm.send_across_nodes(0, 1, int64(1024000))
    if !send_success {
        failed = failed + 1
        return passed, failed, "Failed to send: " + send_err
    }

    passed = passed + 1
    return passed, failed, "test_send_across_nodes passed"
}

func test_all_reduce_cluster() (int, int, string) {
    passed := 0
    failed := 0

    success, err := cluster_comm.cluster_init(8, 8, 0, "node-0")
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    reduce_success, reduce_err := cluster_comm.all_reduce_across_cluster(int64(4096), 0)
    if !reduce_success {
        failed = failed + 1
        return passed, failed, "Failed: " + reduce_err
    }

    passed = passed + 1
    return passed, failed, "test_all_reduce_cluster passed"
}

func test_topology_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := topology.topology_init(8, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    config, config_success, config_err := topology.get_topology_config()
    if !config_success {
        failed = failed + 1
        return passed, failed, "Failed to get config: " + config_err
    }

    if config.num_nodes != 8 {
        failed = failed + 1
        return passed, failed, "Config mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_topology_init passed"
}

func test_set_node_distance() (int, int, string) {
    passed := 0
    failed := 0

    success, err := topology.topology_init(8, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    dist_success, dist_err := topology.set_node_distance(0, 1, 1, 100.0)
    if !dist_success {
        failed = failed + 1
        return passed, failed, "Failed to set distance: " + dist_err
    }

    passed = passed + 1
    return passed, failed, "test_set_node_distance passed"
}

func test_shortest_path() (int, int, string) {
    passed := 0
    failed := 0

    success, err := topology.topology_init(8, 0)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    path, path_success, path_err := topology.find_shortest_path(0, 3)
    if !path_success {
        failed = failed + 1
        return passed, failed, "Failed to find path: " + path_err
    }

    if path.len() <= 0 {
        failed = failed + 1
        return passed, failed, "Empty path"
    }

    passed = passed + 1
    return passed, failed, "test_shortest_path passed"
}

func test_coordinator_init() (int, int, string) {
    passed := 0
    failed := 0

    success, err := coordinator.coordinator_init(8, 2)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed: " + err
    }

    passed = passed + 1
    return passed, failed, "test_coordinator_init passed"
}

func test_submit_global_task() (int, int, string) {
    passed := 0
    failed := 0

    success, err := coordinator.coordinator_init(8, 2)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    submit_success, submit_err := coordinator.submit_global_task(int64(1), 0)
    if !submit_success {
        failed = failed + 1
        return passed, failed, "Failed to submit: " + submit_err
    }

    task, task_success, task_err := coordinator.get_global_task(int64(1))
    if !task_success {
        failed = failed + 1
        return passed, failed, "Failed to get task: " + task_err
    }

    if task.task_id != 1 {
        failed = failed + 1
        return passed, failed, "Task mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_submit_global_task passed"
}

func test_assign_task() (int, int, string) {
    passed := 0
    failed := 0

    success, err := coordinator.coordinator_init(8, 2)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    coordinator.submit_global_task(int64(1), 0)

    nodes, assign_success, assign_err := coordinator.assign_task_to_nodes(int64(1), 2)
    if !assign_success {
        failed = failed + 1
        return passed, failed, "Failed to assign: " + assign_err
    }

    if nodes.len() < 2 {
        failed = failed + 1
        return passed, failed, "Not enough nodes assigned"
    }

    passed = passed + 1
    return passed, failed, "test_assign_task passed"
}

func test_heartbeat() (int, int, string) {
    passed := 0
    failed := 0

    success, err := coordinator.coordinator_init(8, 2)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    healthy, heart_success, heart_err := coordinator.heartbeat_all_nodes()
    if !heart_success {
        failed = failed + 1
        return passed, failed, "Failed: " + heart_err
    }

    if healthy <= 0 {
        failed = failed + 1
        return passed, failed, "No healthy nodes"
    }

    passed = passed + 1
    return passed, failed, "test_heartbeat passed"
}

func test_coordinator_stats() (int, int, string) {
    passed := 0
    failed := 0

    success, err := coordinator.coordinator_init(8, 2)
    if !success {
        failed = failed + 1
        return passed, failed, "Failed to init: " + err
    }

    coordinator.submit_global_task(int64(1), 0)
    coordinator.report_task_completion(int64(1))

    total, completed, failed_tasks, stats_success, stats_err := coordinator.get_coordinator_stats()
    if !stats_success {
        failed = failed + 1
        return passed, failed, "Failed: " + stats_err
    }

    if completed != 1 {
        failed = failed + 1
        return passed, failed, "Completion count mismatch"
    }

    passed = passed + 1
    return passed, failed, "test_coordinator_stats passed"
}

func run_all_tests() (int, int, string) {
    total_passed := 0
    total_failed := 0
    results := ""

    p1, f1, r1 := test_cluster_init()
    total_passed = total_passed + p1
    total_failed = total_failed + f1
    results = results + r1 + " | "

    p2, f2, r2 := test_register_node()
    total_passed = total_passed + p2
    total_failed = total_failed + f2
    results = results + r2 + " | "

    p3, f3, r3 := test_connect_peer()
    total_passed = total_passed + p3
    total_failed = total_failed + f3
    results = results + r3 + " | "

    p4, f4, r4 := test_cluster_stream()
    total_passed = total_passed + p4
    total_failed = total_failed + f4
    results = results + r4 + " | "

    p5, f5, r5 := test_send_across_nodes()
    total_passed = total_passed + p5
    total_failed = total_failed + f5
    results = results + r5 + " | "

    p6, f6, r6 := test_all_reduce_cluster()
    total_passed = total_passed + p6
    total_failed = total_failed + f6
    results = results + r6 + " | "

    p7, f7, r7 := test_topology_init()
    total_passed = total_passed + p7
    total_failed = total_failed + f7
    results = results + r7 + " | "

    p8, f8, r8 := test_set_node_distance()
    total_passed = total_passed + p8
    total_failed = total_failed + f8
    results = results + r8 + " | "

    p9, f9, r9 := test_shortest_path()
    total_passed = total_passed + p9
    total_failed = total_failed + f9
    results = results + r9 + " | "

    p10, f10, r10 := test_coordinator_init()
    total_passed = total_passed + p10
    total_failed = total_failed + f10
    results = results + r10 + " | "

    p11, f11, r11 := test_submit_global_task()
    total_passed = total_passed + p11
    total_failed = total_failed + f11
    results = results + r11 + " | "

    p12, f12, r12 := test_assign_task()
    total_passed = total_passed + p12
    total_failed = total_failed + f12
    results = results + r12 + " | "

    p13, f13, r13 := test_heartbeat()
    total_passed = total_passed + p13
    total_failed = total_failed + f13
    results = results + r13 + " | "

    p14, f14, r14 := test_coordinator_stats()
    total_passed = total_passed + p14
    total_failed = total_failed + f14
    results = results + r14

    return total_passed, total_failed, results
}
