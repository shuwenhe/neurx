package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_fault_injection_worker_relaunch_commands}

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
    relaunch := bridge_fault_injection_worker_relaunch_commands(state)
    failures := 0
    failures = failures + expect(len(relaunch) > 0, "worker relaunch script generated")
    failures = failures + expect(relaunch[0] == 35, "worker relaunch shebang")
    if failures == 0 {
        println("PASS cluster fault injection worker relaunch")
        return 0
    }
    println("FAIL cluster fault injection worker relaunch")
    1
}
