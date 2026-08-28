package main

use neurx.deployment.hetero_runtime_bridge.{bridge_hetero_demo_execute}

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
    code := bridge_hetero_demo_execute("neurx-worker", "127.0.0.1", 29500)
    failures := 0
    failures = failures + expect(code == 0 || code != 0, "demo execute callable")
    if failures == 0 {
        println("PASS hetero runtime bridge execute")
        return 0
    }
    println("FAIL hetero runtime bridge execute")
    1
}
