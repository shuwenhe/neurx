package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_fault_injection_recovery}
use neurx.distributed.cluster.heartbeat.{create_cluster_heartbeat_state, cluster_heartbeat_write}

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
    state := new_demo_cluster_state()
    heartbeat := create_cluster_heartbeat_state(state.cluster_name, "/tmp/neurx_cluster/heartbeat")
    heartbeat = cluster_heartbeat_write(heartbeat, 1, "node-a", "10.0.0.1", 0, 0, 1000, true, "ready")
    heartbeat = cluster_heartbeat_write(heartbeat, 2, "node-b", "10.0.0.2", 1, 0, 1000, true, "ready")
    result := bridge_fault_injection_recovery(state)
    failures := 0
    failures = failures + expect(result.heartbeat_scan.failed_ranks > 0, "failed ranks detected")
    failures = failures + expect(len(result.heartbeat_scan.failed_rank_ids) > 0, "failed rank ids present")
    failures = failures + expect(len(result.scan_summary) > 0, "scan summary generated")
    failures = failures + expect(result.filter_meta.valid, "filter result valid")
    failures = failures + expect(len(result.recovery_summary) > 0, "recovery summary generated")
    if failures == 0 {
        println("PASS cluster fault injection recovery")
        return 0
    }
    println("FAIL cluster fault injection recovery")
    1
}
