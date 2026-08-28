package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_recover_failed_nodes}

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
    recovery := bridge_recover_failed_nodes(state)
    failures := 0
    failures = failures + expect(len(recovery) > 0, "recovery summary generated")
    failures = failures + expect(recovery[0] == 91, "recovery prefix")
    if failures == 0 {
        println("PASS cluster recovery")
        return 0
    }
    println("FAIL cluster recovery")
    1
}
