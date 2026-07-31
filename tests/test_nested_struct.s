package main
struct inner_data {
    int value
    float score
    []float weights
}

struct outer_data {
    string name
    inner_data data
}
func test_direct_access() {
    outer_data obj
    obj.name = "test"
    obj.data.value = 42
    obj.data.score = 3.14
    obj.data.weights = []float{cap: 3}
    obj.data.weights[0] = 1.0
    obj.data.weights[1] = 2.0
    obj.data.weights[2] = 3.0
    println("[Test 1] Direct field access:")
    println("  obj.data.value = " + int_to_str(obj.data.value))
    println("  obj.data.score = " + float_to_str(obj.data.score, 2))
    println("  obj.data.weights[0] = " + float_to_str(obj.data.weights[0], 1))
}

func test_array_element_access() {
    []outer_data arr = []outer_data{cap: 2}
    arr[0].name = "first"
    arr[0].data.value = 10
    arr[0].data.score = 1.5
    arr[0].data.weights = []float{cap: 2}
    arr[0].data.weights[0] = 0.5
    arr[1].name = "second"
    arr[1].data.value = 20
    arr[1].data.score = 2.5
    println("")
    println("[Test 2] Array element field access:")
    println("  arr[0].data.value = " + int_to_str(arr[0].data.value))
    println("  arr[1].data.value = " + int_to_str(arr[1].data.value))
}

func test_local_extraction() {
    []outer_data arr = []outer_data{cap: 1}
    arr[0].name = "extract"
    arr[0].data.value = 99
    arr[0].data.score = 9.9
    println("")
    println("[Test 3] Local variable extraction:")
    outer_data elem = arr[0]
    int val = elem.data.value
    println("  Extracted value = " + int_to_str(val))
    inner_data inner = elem.data
    int val2 = inner.value
    println("  Double extraction = " + int_to_str(val2))
}

func test_function_param(outer_data param) {
    println("")
    println("[Test 4] Function parameter field access:")
    int val = param.data.value
    println("  param.data.value = " + int_to_str(val))
}

func test_loop_iteration() {
    []outer_data arr = []outer_data{cap: 3}
    int i = 0
    while i < 3 {
        arr[i].name = "item" + int_to_str(i)
        arr[i].data.value = i * 10
        i = i + 1
    }
    println("")
    println("[Test 5] Loop iteration with nested access:")
    i = 0
    while i < 3 {
        outer_data item = arr[i]
        int val = item.data.value
        println("  arr[" + int_to_str(i) + "].data.value = " + int_to_str(val))
        i = i + 1
    }
}

func main() {
    println("===================================")
    println("S Compiler Nested Struct Test")
    println("===================================")
    test_direct_access()
    test_array_element_access()
    test_local_extraction()
    outer_data sample
    sample.name = "sample"
    sample.data.value = 777
    test_function_param(sample)
    test_loop_iteration()
    println("")
    println("[Result] All tests completed!")
    0
}
