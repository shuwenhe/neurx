package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_probe_runtime, bridge_launch_plan}

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
    launch := bridge_launch_plan(state)
    failures := 0
    failures = failures + expect(probe.ready, "bridge ready")
    failures = failures + expect(len(probe.launch_plan.commands) > 0, "launch commands present")
    failures = failures + expect(len(launch) > 0, "launch summary generated")
    if failures == 0 {
        println("PASS cluster parallel launch")
        return 0
    }
    println("FAIL cluster parallel launch")
    1
}
