package main

struct inner {
    int value
}

struct outer {
    string name
    inner data
}

func main() {
    println("=== Test: Can we even SET nested fields? ===")
    outer obj
    obj.name = "test"
    println("Step 1: Set top-level field OK")
    inner temp
    temp.value = 42
    println("Step 2: Created temp Inner with value=42")
    obj.data = temp
    println("Step 3: Assigned temp to obj.data")
    inner retrieved = obj.data
    println("Step 4: Retrieved obj.data")
    int val = retrieved.value
    println("Step 5: Got value = " + int_to_str(val))
    0
}

