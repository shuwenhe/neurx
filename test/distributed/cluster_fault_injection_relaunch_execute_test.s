package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_fault_injection_relaunch_execute}

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
    exit_code := bridge_fault_injection_relaunch_execute(state)
    failures := 0
    failures = failures + expect(exit_code >= 0, "relaunch execute exit code")
    if failures == 0 {
        println("PASS cluster fault injection relaunch execute")
        return 0
    }
    println("FAIL cluster fault injection relaunch execute")
    1
}
