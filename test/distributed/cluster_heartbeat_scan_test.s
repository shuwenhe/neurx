package main

use neurx.distributed.cluster.heartbeat.{create_cluster_heartbeat_state, cluster_heartbeat_write, cluster_heartbeat_scan, cluster_heartbeat_scan_summary}

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
    state := create_cluster_heartbeat_state("neurx-test", "/tmp/neurx_cluster/test_heartbeat_scan")
    state = cluster_heartbeat_write(state, 1, "node-a", "10.0.0.1", 0, 0, 1000, true, "ready")
    scan := cluster_heartbeat_scan(state, 4)
    failures := 0
    failures = failures + expect(scan.failed_ranks > 0, "scan detects missing ranks")
    failures = failures + expect(len(scan.failed_rank_ids) > 0, "failed rank ids exist")
    failures = failures + expect(len(cluster_heartbeat_scan_summary(scan)) > 0, "scan summary")
    if failures == 0 {
        println("PASS cluster heartbeat scan")
        return 0
    }
    println("FAIL cluster heartbeat scan")
    1
}
