package main

use neurx.distributed.cluster.heartbeat.{create_cluster_heartbeat_state, cluster_heartbeat_write, cluster_heartbeat_is_live, cluster_heartbeat_summary}

func expect(bool condition, string name) int {
    if condition {
        print("PASS ")
        print(name)
        return 0
    }
    print("FAIL ")
    print(name)
    return 1
}

func main() int {
    state := create_cluster_heartbeat_state("neurx-test", "/tmp/neurx_cluster/test_heartbeat")
    state = cluster_heartbeat_write(state, 1, "node-a", "10.0.0.1", 0, 0, 1000, true, "ready")
    failures := 0
    failures = failures + expect(cluster_heartbeat_is_live(state, 0), "heartbeat live")
    failures = failures + expect(len(cluster_heartbeat_summary(state)) > 0, "heartbeat summary")
    if failures == 0 {
        println("PASS cluster heartbeat")
        return 0
    }
    println("FAIL cluster heartbeat")
    1
}
