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
    failures = failures + expect(probe.execution_script.valid, "execution script valid")
    failures = failures + expect(len(probe.execution_script.script) > 0, "execution script generated")
    failures = failures + expect(len(probe.execution_script_summary) > 0, "execution script summary")
    if failures == 0 {
        println("PASS cluster parallel execution script")
        return 0
    }
    println("FAIL cluster parallel execution script")
    1
}
