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
    failures = failures + expect(probe.grouped_launch_plan.valid, "grouped launch valid")
    failures = failures + expect(len(probe.grouped_launch_plan.bundles) > 0, "grouped bundles")
    failures = failures + expect(len(probe.grouped_launch_summary) > 0, "grouped summary")
    if failures == 0 {
        println("PASS cluster grouped launch")
        return 0
    }
    println("FAIL cluster grouped launch")
    1
}
