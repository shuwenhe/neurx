package main
use neurx.moe.core.{moe_core_self_test}

func main() {
    int status = moe_core_self_test()
    if status != 0 {
        println("[moe-core-s] FAIL: status=" + test_int_to_string(status))
        return status
    }
    println("[moe-core-s] routing: PASS")
    println("[moe-core-s] shared experts: PASS")
    println("[moe-core-s] routed experts: PASS")
    println("[moe-core-s] load accounting: PASS")
    0
}

func test_int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    int current = value
    string out = ""
    for current > 0 {
        int digit = current - (current / 10) * 10
        out = test_string_char(digit + 48) + out
        current = current / 10
    }
    out
}

func test_string_char(int code) string {
    string(code)
}
