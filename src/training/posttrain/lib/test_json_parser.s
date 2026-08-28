package neurx.posttrain.lib.test_json
use std.io.eprintln
use neurx.posttrain.lib.json_parser
func main() {
    eprintln("\n=== Testing Pure-S JSON Parser ===\n")
    test_null()
    test_bool()
    test_number()
    test_string()
    test_array()
    test_object()
    test_nested()
    eprintln("\n✅ All JSON parser tests passed!\n")
}
func test_null() {
    eprintln("[Test 1] Null value")
    val := json_parser.parse("null")
    if !val.is_null() {
        panic("Expected null")
    }
    eprintln("  ✓ null parsing OK")
}
func test_bool() {
    eprintln("[Test 2] Boolean values")
    val_true := json_parser.parse("true")
    if !val_true.is_bool() || !val_true.as_bool() {
        panic("Expected true")
    }
    eprintln("  ✓ true parsing OK")
    val_false := json_parser.parse("false")
    if !val_false.is_bool() || val_false.as_bool() {
        panic("Expected false")
    }
    eprintln("  ✓ false parsing OK")
}
func test_number() {
    eprintln("[Test 3] Number values")
    val_int := json_parser.parse("42")
    if !val_int.is_number() || val_int.as_int() != 42 {
        panic("Expected 42")
    }
    eprintln("  ✓ integer parsing OK")
    val_negative := json_parser.parse("-10")
    if !val_negative.is_number() || val_negative.as_int() != -10 {
        panic("Expected -10")
    }
    eprintln("  ✓ negative parsing OK")
    val_float := json_parser.parse("3.14")
    if !val_float.is_number() {
        panic("Expected float")
    }
    eprintln("  ✓ float parsing OK")
}
func test_string() {
    eprintln("[Test 4] String values")
    val := json_parser.parse("\"hello\"")
    if !val.is_string() || val.as_string() != "hello" {
        panic("Expected 'hello'")
    }
    eprintln("  ✓ string parsing OK")
    val_escaped := json_parser.parse("\"hello\\nworld\"")
    if !val_escaped.is_string() {
        panic("Expected escaped string")
    }
    eprintln("  ✓ escaped string parsing OK")
}
func test_array() {
    eprintln("[Test 5] Array values")
    val := json_parser.parse("[1, 2, 3]")
    if !val.is_array() {
        panic("Expected array")
    }
    arr := val.as_array()
    if len(arr) != 3 {
        panic("Expected array of length 3")
    }
    if arr[0].as_int() != 1 || arr[1].as_int() != 2 || arr[2].as_int() != 3 {
        panic("Expected [1, 2, 3]")
    }
    eprintln("  ✓ array parsing OK")
    val_empty := json_parser.parse("[]")
    if !val_empty.is_array() || len(val_empty.as_array()) != 0 {
        panic("Expected empty array")
    }
    eprintln("  ✓ empty array parsing OK")
}
func test_object() {
    eprintln("[Test 6] Object values")
    val := json_parser.parse("{\"key\": \"value\"}")
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
    val_empty := json_parser.parse("{}")
    if !val_empty.is_object() || len(val_empty.as_object()) != 0 {
        panic("Expected empty object")
    }
    eprintln("  ✓ empty object parsing OK")
}
func test_nested() {
    eprintln("[Test 7] Nested structures")
    json_str := "{\"name\": \"Alice\", \"age\": 30, \"tags\": [\"developer\", \"ai\"], \"active\": true}"
    val := json_parser.parse(json_str)
    if !val.is_object() {
        panic("Expected object")
    }
    name := val.at("name")
    if !name.is_string() || name.as_string() != "Alice" {
        panic("Expected name 'Alice'")
    }
    age := val.at("age")
    if !age.is_number() || age.as_int() != 30 {
        panic("Expected age 30")
    }
    tags := val.at("tags")
    if !tags.is_array() || len(tags.as_array()) != 2 {
        panic("Expected 2 tags")
    }
    active := val.at("active")
    if !active.is_bool() || !active.as_bool() {
        panic("Expected active true")
    }
    eprintln("  ✓ nested structure parsing OK")
}
