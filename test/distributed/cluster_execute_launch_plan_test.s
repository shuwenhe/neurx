package main

use neurx.deployment.cluster_orchestration.{new_demo_cluster_state}
use neurx.deployment.cluster_runtime_bridge.{bridge_execute_launch_plan}

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
    execute := bridge_execute_launch_plan(state)
    failures := 0
    failures = failures + expect(len(execute) > 0, "execute summary generated")
    failures = failures + expect(execute[0] == 91, "execute prefix")
    if failures == 0 {
        println("PASS cluster execute launch plan")
        return 0
    }
    println("FAIL cluster execute launch plan")
    1
}
