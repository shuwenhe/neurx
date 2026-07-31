
package main

func test_str_len() {
    println("====================================")
    println("[Test] str_len()")
    println("====================================")

    string s1 = "checkpoint_step_000100"
    int len1 = str_len(s1)
    println("Input: 'checkpoint_step_000100'")
    print("Length: ")
    println(int_to_str(len1))
    print("Expected: 22  ")
    if len1 == 22 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    string s2 = ""
    int len2 = str_len(s2)
    print("Empty string length: ")
    println(int_to_str(len2))
    print("Expected: 0  ")
    if len2 == 0 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}

func test_str_find() {
    println("====================================")
    println("[Test] str_find()")
    println("====================================")

    string haystack = "checkpoint_step_000100"
    string needle = "step"
    int pos = str_find(haystack, needle)
    println("Haystack: 'checkpoint_step_000100'")
    println("Needle: 'step'")
    print("Position: ")
    println(int_to_str(pos))
    print("Expected: 11  ")
    if pos == 11 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    string needle2 = "xyz"
    int pos2 = str_find(haystack, needle2)
    println("Needle: 'xyz'")
    print("Position: ")
    println(int_to_str(pos2))
    print("Expected: -1  ")
    if pos2 < 0 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}

func test_str_char_at() {
    println("====================================")
    println("[Test] str_char_at()")
    println("====================================")

    string s = "checkpoint"

    string c0 = str_char_at(s, 0)
    println("String: 'checkpoint'")
    print("char_at(0): '")
    print(c0)
    println("'")
    print("Expected: 'c'  ")
    if c0 == "c" {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    string c5 = str_char_at(s, 5)
    print("char_at(5): '")
    print(c5)
    println("'")
    print("Expected: 'p'  ")
    if c5 == "p" {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}

func test_str_substring() {
    println("====================================")
    println("[Test] str_substring()")
    println("====================================")

    string s = "checkpoint_step_000100"

    string sub = str_substring(s, 11)
    println("String: 'checkpoint_step_000100'")
    print("substring(11): '")
    print(sub)
    println("'")
    print("Expected: 'step_000100'  ")
    if sub == "step_000100" {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}

func test_file_io() {
    println("====================================")
    println("[Test] File I/O")
    println("====================================")

    string test_file = "/tmp/neurx_test_runtime.txt"
    string test_content = "hello world"

    println("Writing to: " + test_file)
    println("Content: '" + test_content + "'")
    bool write_ok = write_file(test_file, test_content)
    print("write_file() result: ")
    if write_ok {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    println("Reading from: " + test_file)
    string read_content = read_file(test_file)
    print("read_file() result: '")
    print(read_content)
    println("'")
    print("Expected: '" + test_content + "'  ")
    if read_content == test_content {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    println("Checking file existence...")
    bool exists = file_exists(test_file)
    print("file_exists() result: ")
    if exists {
        println("✓ PASS (file exists)")
    } else {
        println("✗ FAIL (file should exist)")
    }
    println("")
}

func test_atomic_rename() {
    println("====================================")
    println("[Test] Atomic Rename (CRITICAL)")
    println("====================================")

    string tmp_file = "/tmp/neurx_test.json.tmp"
    string final_file = "/tmp/neurx_test.json"
    string content = "{\"step\": 100}"

    println("Step 1: Write to temp file")
    write_file(tmp_file, content)
    println("  ✓ " + tmp_file)
    println("")

    println("Step 2: Atomic rename (防止 checkpoint 损坏)")
    bool rename_ok = rename_file(tmp_file, final_file)
    print("  rename_file() result: ")
    if rename_ok {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    println("Step 3: Verify final file exists")
    bool final_exists = file_exists(final_file)
    bool tmp_gone = !file_exists(tmp_file)
    print("  Final file exists: ")
    if final_exists {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    print("  Temp file removed: ")
    if tmp_gone {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")

    println("Step 4: Verify content preserved")
    string final_content = read_file(final_file)
    print("  Content: '")
    print(final_content)
    println("'")
    print("  Expected: '" + content + "'  ")
    if final_content == content {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}

func main() {
    println("")
    println("========================================")
    println("NeurX Runtime Unit Tests")
    println("========================================")
    println("")

    test_str_len()
    test_str_find()
    test_str_char_at()
    test_str_substring()

    test_file_io()
    test_atomic_rename()

    println("========================================")
    println("Runtime Unit Tests Complete")
    println("========================================")
    println("")
    println("✅ If all tests PASS:")
    println("   → Proceed to test_roundtrip.s")
    println("")
    println("❌ If any tests FAIL:")
    println("   → Fix S runtime implementation")
    println("   → Re-run test_runtime.s")
    println("")
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    string out = ""

    if value < 0 {
        negative = true
        value = 0 - value
    }

    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}

func str_len(string s) int {
    println("[PLACEHOLDER] str_len() - needs runtime.c implementation")
    return 0
}

func str_find(string haystack, string needle) int {
    println("[PLACEHOLDER] str_find() - needs runtime.c implementation")
    return 0 - 1
}

func str_char_at(string s, int pos) string {
    println("[PLACEHOLDER] str_char_at() - needs runtime.c implementation")
    return ""
}

func str_substring(string s, int start) string {
    println("[PLACEHOLDER] str_substring() - needs runtime.c implementation")
    return s
}

func write_file(string filepath, string content) bool {
    println("[PLACEHOLDER] write_file() - needs runtime.c implementation")
    return false
}

func read_file(string filepath) string {
    println("[PLACEHOLDER] read_file() - needs runtime.c implementation")
    return ""
}

func file_exists(string filepath) bool {
    println("[PLACEHOLDER] file_exists() - needs runtime.c implementation")
    return false
}

func rename_file(string old_path, string new_path) bool {
    println("[PLACEHOLDER] rename_file() - needs runtime.c implementation")
    return false
}
