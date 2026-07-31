package main

struct Data {
    int value
}

func main() {
    println("=== Test 1: Local struct field access ===")
    Data local
    local.value = 42
    int val1 = local.value
    println("Local: " + int_to_str(val1))

    println("")
    println("=== Test 2: Array element field access ===")
    []Data arr = []Data{cap: 1}
    arr[0].value = 99

    Data elem = arr[0]
    int val2 = elem.value
    println("From array: " + int_to_str(val2))

    0
}
