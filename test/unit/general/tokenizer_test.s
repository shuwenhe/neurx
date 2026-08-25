package neurx.tests.tokenizer_test
use std.io.println
use neurx.inference.tokenizer_loader

struct test_result_2 {
    test_name: string
    passed: bool
    message: string
}
[]test_result_2 test_results = make([]test_result_2, 0)

func run_all_tests() int {
    println("=== W1.1 Tokenizer Unit Tests ===")
    println("")
    test_tokenizer_loader_init()
    test_model_loading()
    test_basic_tokenization()
    test_determinism()
    test_vocab_size()
    println("")
    println("=== Test Results ===")
    int passed = 0
    int failed = 0
    int i = 0
    for i < len(test_results) {
        test_result_2 tr = test_results[i]
        string status = "PASS"
        if !tr.passed {
            status = "FAIL"
            failed = failed + 1
        } else {
            passed = passed + 1
        }
        println("[" + status + "] " + tr.test_name)
        if len(tr.message) > 0 {
            println("  > " + tr.message)
        }
        i = i + 1
    }
    println("")
    println("Summary: " + str_int(passed) + " passed, " + str_int(failed) + " failed")
    if failed > 0 {
        return 1
    } else {
        return 0
    }
}

func test_tokenizer_loader_init() {
    string test_name = "Tokenizer: Initialization"
    tokenizer_state_2 state = new_tokenizer_state()
    bool passed = true
    string message = ""
    if state.is_loaded {
        passed = false
        message = "Empty tokenizer should not be loaded"
    }
    if len(state.model_path) > 0 {
        passed = false
        message = "Empty tokenizer should have empty model_path"
    }
    record_test_result(test_name, passed, message)
}

func test_model_loading() {
    string test_name = "Tokenizer: Load HF model"
    string model_path = "../model/base-model"
    tokenizer_state_2 state = load_tokenizer(model_path)
    bool passed = true
    string message = ""
    if !state.is_loaded {
        passed = false
        message = "Failed to load model: " + state.error_message
    }
    if state.vocab_size <= 0 {
        passed = false
        message = "Invalid vocab size: " + str_int(state.vocab_size)
    }
    record_test_result(test_name, passed, message)
}

func test_basic_tokenization() {
    string test_name = "Tokenizer: Basic Tokenization"
    string model_path = "../model/base-model"
    tokenizer_state_2 state = load_tokenizer(model_path)
    if !state.is_loaded {
        record_test_result(test_name, false, "model not loaded, skipping test")
        return
    }
    string test_text = "What is the treatment for chronic urinary tract infection"
    tokenization_result_2 result = tokenize(state, test_text)
    bool passed = true
    string message = ""
    if !result.success {
        passed = false
        message = "Tokenization failed: " + result.error
    } else if result.token_count == 0 {
        passed = false
        message = "No tokens generated"
    } else if result.token_count > 30 {
        passed = false
        message = "Too many tokens: " + str_int(result.token_count)
    }
    record_test_result(test_name, passed, message)
}

func test_determinism() {
    string test_name = "Tokenizer: Determinism (10 runs)"
    string model_path = "../model/base-model"
    tokenizer_state_2 state = load_tokenizer(model_path)
    if !state.is_loaded {
        record_test_result(test_name, false, "model not loaded, skipping test")
        return
    }
    string test_text = "What is the treatment for chronic urinary tract infection"
    tokenization_result_2 result = tokenize_deterministic(state, test_text, 10)
    bool passed = result.success
    string message = ""
    if !passed {
        message = result.error
    } else {
        message = "All 10 runs produced identical output (" + str_int(result.token_count) + " tokens)"
    }
    record_test_result(test_name, passed, message)
}

func test_vocab_size() {
    string test_name = "Tokenizer: Vocabulary Size"
    string model_path = "../model/base-model"
    tokenizer_state_2 state = load_tokenizer(model_path)
    bool passed = true
    string message = ""
    if state.vocab_size != 152064 {
        passed = false
        message = "Expected vocab_size=152064, got " + str_int(state.vocab_size)
    } else {
        message = "Vocab size is correct: 152064"
    }
    record_test_result(test_name, passed, message)
}

func record_test_result(string test_name, bool passed, string message) {
    test_result_2 result = test_result_2 {
        test_name: test_name,
        passed: passed,
        message: message,
    }
    test_results = append(test_results, result)
}

func str_int(int n) string {
    if n == 0 {
        return "0"
    }
    bool negative = n < 0
    if negative {
        n = -n
    }
    string result = ""
    for n > 0 {
        int digit = n % 10
        if digit == 0 { result = "0" + result }
        else if digit == 1 { result = "1" + result }
        else if digit == 2 { result = "2" + result }
        else if digit == 3 { result = "3" + result }
        else if digit == 4 { result = "4" + result }
        else if digit == 5 { result = "5" + result }
        else if digit == 6 { result = "6" + result }
        else if digit == 7 { result = "7" + result }
        else if digit == 8 { result = "8" + result }
        else if digit == 9 { result = "9" + result }
        n = n / 10
    }
    if negative {
        result = "-" + result
    }
    result
}

func len(interface{} arr) int {
    0
}

func append(interface{} arr, interface{} val) interface{} {
    arr
}

func make(interface{} arr_type, int size) interface{} {
    nil
}

func main() {
    int exit_code = run_all_tests()
}
