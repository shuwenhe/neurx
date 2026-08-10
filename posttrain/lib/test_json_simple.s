package neurx.posttrain.lib.test_json_simple

use std.io.eprintln
use neurx.posttrain.lib.json_simple

func main() {
    eprintln("\n=== Testing Pure-S JSON Parser ===\n")

    test_null()
    test_bool()
    test_number()
    test_string()
    test_array()
    test_object()

    eprintln("\n✅ All JSON tests passed!\n")
}

func test_null() {
    eprintln("[Test 1] Null value")
    val := json_simple.parse("null")
    if !val.is_null() {
        panic("Expected null")
    }
    eprintln("  ✓ null parsing OK")
}

func test_bool() {
    eprintln("[Test 2] Boolean values")

    val_true := json_simple.parse("true")
    if !val_true.is_bool() || !val_true.as_bool() {
        panic("Expected true")
    }
    eprintln("  ✓ true parsing OK")

    val_false := json_simple.parse("false")
    if !val_false.is_bool() || val_false.as_bool() {
        panic("Expected false")
    }
    eprintln("  ✓ false parsing OK")
}

func test_number() {
    eprintln("[Test 3] Number values")

    val_int := json_simple.parse("42")
    if !val_int.is_number() {
        panic("Expected number")
    }
    eprintln("  ✓ integer parsing OK")

    val_float := json_simple.parse("3.14")
    if !val_float.is_number() {
        panic("Expected float")
    }
    eprintln("  ✓ float parsing OK")
}

func test_string() {
    eprintln("[Test 4] String values")

    val := json_simple.parse("\"hello\"")
    if !val.is_string() || val.as_string() != "hello" {
        panic("Expected 'hello'")
    }
    eprintln("  ✓ string parsing OK")
}

func test_array() {
    eprintln("[Test 5] Array values")

    val := json_simple.parse("[1,2,3]")
    if !val.is_array() {
        panic("Expected array")
    }
    arr := val.as_array()
    if len(arr) != 3 {
        panic("Expected array of length 3")
    }
    eprintln("  ✓ array parsing OK")
}

func test_object() {
    eprintln("[Test 6] Object values")

    val := json_simple.parse("{\"key\":\"value\"}")
    if !val.is_object() {
        panic("Expected object")
    }

    if !val.contains("key") {
        panic("Expected 'key' field")
    }

    key_val := val.at("key")
    if !key_val.is_string() || key_val.as_string() != "value" {
        panic("Expected value 'value'")
    }
    eprintln("  ✓ object parsing OK")
}
