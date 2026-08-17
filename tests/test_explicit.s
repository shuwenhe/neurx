package main

struct data {
    int value
}

func main() {
    println("=== Test: Explicit struct field operations ===")
    data obj = data {
        value: 0
    }
    println("Initial value: 0")
    obj.value = 42
    println("After setting to 42")
    int val = obj.value
    println("Successfully read value!")
    if val == 42 {
        println("✓ TEST PASSED: value == 42")
        0
    } else {
        println("✗ TEST FAILED: value != 42")
        1
    }
}
