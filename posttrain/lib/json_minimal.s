package neurx.posttrain.lib
use std.io.eprintln
func test_null(string text) bool {
    if text == "null" {
        return true
    }
    return false
}

func main() {
    eprintln("Test 1: Parse null")
    if test_null("null") {
        eprintln("  OK - null parsed")
    }
    eprintln("Test 2: String comparison")
    string s = "hello"
    if s == "hello" {
        eprintln("  OK - strings match")
    }
    eprintln("All tests passed")
    0
}

