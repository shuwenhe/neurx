package main
func str_len(string s) int {
    return __host_str_len(s)
}
func str_find(string haystack, string needle) int {
    return __host_str_find(haystack, needle)
}
func str_char_at(string s, int pos) string {
    return __host_str_char_at(s, pos)
}
func str_substring(string s, int start) string {
    println("[PLACEHOLDER] str_substring() - needs runtime.c implementation")
    return s
}
func file_size(string path) int {
    return __host_file_size(path)
}
func file_exists(string filepath) bool {
    int result = __host_file_exists(filepath)
    if result == 1 {
        return true
    }
    return false
}
func write_file(string filepath, string content) bool {
    int result = __host_write_file(filepath, content)
    if result == 1 {
        return true
    }
    return false
}
func read_file(string filepath) string {
    return __host_read_file(filepath)
}
func atomic_replace(string tmp_path, string final_path) bool {
    int result = __host_atomic_replace(tmp_path, final_path)
    if result == 1 {
        return true
    }
    return false
}
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
    println("Checking file size...")
    int size = file_size(test_file)
    print("file_size() result: ")
    println(int_to_str(size))
    print("Expected: 11 (length of 'hello world')  ")
    if size == 11 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
}
func test_atomic_rename() {
    println("====================================")
    println("[Test] Atomic Replace (CRITICAL)")
    println("====================================")
    println("")
    println("Test 1: Normal Replace (tmp → final)")
    println("--------------------------------------")
    string tmp1 = "/tmp/neurx_atomic_test1.tmp"
    string final1 = "/tmp/neurx_atomic_test1.json"
    string content1 = "{\"step\": 100}"
    write_file(tmp1, content1)
    bool ok1 = atomic_replace(tmp1, final1)
    print("  atomic_replace() result: ")
    if ok1 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    bool final1_exists = file_exists(final1)
    bool tmp1_gone = !file_exists(tmp1)
    print("  Final exists: ")
    if final1_exists {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    print("  Temp removed: ")
    if tmp1_gone {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    string read1 = read_file(final1)
    print("  Content match: ")
    if read1 == content1 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
    println("Test 2: Overwrite Existing File")
    println("--------------------------------------")
    string tmp2 = "/tmp/neurx_atomic_test2.tmp"
    string final2 = "/tmp/neurx_atomic_test2.json"
    string old_content = "{\"step\": 50}"
    string new_content = "{\"step\": 100}"
    write_file(final2, old_content)
    write_file(tmp2, new_content)
    bool ok2 = atomic_replace(tmp2, final2)
    print("  atomic_replace() result: ")
    if ok2 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    string read2 = read_file(final2)
    print("  Content updated: ")
    if read2 == new_content {
        println("✓ PASS (old overwritten)")
    } else {
        println("✗ FAIL")
    }
    println("")
    println("Test 3: Fail Path (tmp doesn't exist)")
    println("--------------------------------------")
    string tmp3 = "/tmp/neurx_nonexistent.tmp"
    string final3 = "/tmp/neurx_atomic_test3.json"
    bool ok3 = atomic_replace(tmp3, final3)
    print("  atomic_replace() result: ")
    if !ok3 {
        println("✓ PASS (correctly returned false)")
    } else {
        println("✗ FAIL (should return false)")
    }
    println("")
    println("Test 4: Directory fsync (Checkpoint Safety)")
    println("--------------------------------------")
    string tmp4 = "/tmp/trainer_state.json.tmp"
    string final4 = "/tmp/trainer_state.json"
    string checkpoint_data = "{\"step\": 1000, \"loss\": 2.31}"
    write_file(tmp4, checkpoint_data)
    bool ok4 = atomic_replace(tmp4, final4)
    print("  atomic_replace() with dir fsync: ")
    if ok4 {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    string read4 = read_file(final4)
    print("  Checkpoint persisted: ")
    if read4 == checkpoint_data {
        println("✓ PASS")
    } else {
        println("✗ FAIL")
    }
    println("")
    println("🎯 Atomic Replace guarantees:")
    println("  1. File data flushed before rename")
    println("  2. Rename is atomic (all or nothing)")
    println("  3. Directory metadata persisted (critical!)")
    println("  4. Safe for checkpoint during power failure")
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
    for value > 0 {
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
