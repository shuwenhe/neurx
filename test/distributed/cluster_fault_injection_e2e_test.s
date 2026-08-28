package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state, cluster_elastic_recover}
use neurx.deployment.cluster_runtime_bridge.{bridge_fault_injection_recovery}

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
    recovered_state := cluster_elastic_recover(state)
    result := bridge_fault_injection_recovery(recovered_state)
    failures := 0
    failures = failures + expect(result.heartbeat_scan.total_ranks > 0, "scan total ranks")
    failures = failures + expect(result.heartbeat_scan.failed_ranks >= 0, "scan failed ranks")
    failures = failures + expect(result.filter_meta.valid, "filter meta valid")
    failures = failures + expect(result.relaunch_plan.valid, "relaunch plan valid")
    failures = failures + expect(result.relaunch_execution_batch.valid, "relaunch execution batch valid")
    failures = failures + expect(result.relaunch_execution_script.valid, "relaunch execution script valid")
    failures = failures + expect(len(result.recovery_summary) > 0, "recovery summary present")
    if failures == 0 {
        println("PASS cluster fault injection e2e")
        return 0
    }
    println("FAIL cluster fault injection e2e")
    1
}
