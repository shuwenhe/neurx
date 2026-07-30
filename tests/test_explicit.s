package main

struct Data {
    int value
}

func main() int {
    println("=== Test: Explicit struct field operations ===")
    Data obj
    println("Before: Setting obj.value = 42")
    obj.value = 42
    println("After: Reading obj.value")
    int val = obj.value
    println("Value: " + int_to_str(val))
    val
}
