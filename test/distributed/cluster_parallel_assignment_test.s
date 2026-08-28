package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_probe_runtime}

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
    probe := bridge_probe_runtime(state)
    failures := 0
    failures = failures + expect(probe.ready, "bridge ready")
    failures = failures + expect(len(probe.assignment_summary) > 0, "assignment summary exists")
    failures = failures + expect(len(probe.parallel_plan.ranks) > 0, "parallel ranks exists")
    if failures == 0 {
        println("PASS cluster parallel assignment")
        return 0
    }
    println("FAIL cluster parallel assignment")
    1
}
