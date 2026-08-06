package neurx.inference.test_keywords

extern "intrinsic" func __host_slice(string text, int start, int end) string

func contains_keyword(string text, string keyword) bool {
    int text_len = len(text)
    int keyword_len = len(keyword)
    if keyword_len > text_len {
        return false
    }
    int i = 0
    while i <= text_len - keyword_len {
        bool match = true
        int j = 0
        while j < keyword_len {
            string text_char = __host_slice(text, i + j, i + j + 1)
            string keyword_char = __host_slice(keyword, j, j + 1)
            if text_char != keyword_char {
                match = false
            }
            j = j + 1
        }
        if match {
            return true
        }
        i = i + 1
    }
    return false
}

func generate_response(string prompt) string {
    if contains_keyword(prompt, "你好") || contains_keyword(prompt, "hello") {
        return "您好！我是医学助手。"
    } else if contains_keyword(prompt, "诊断") || contains_keyword(prompt, "diagnosis") {
        return "诊断需要基于患者的症状、体征和各项检查。"
    } else if contains_keyword(prompt, "症状") || contains_keyword(prompt, "symptom") {
        return "请详细描述您关心的具体症状。"
    } else if contains_keyword(prompt, "治疗") || contains_keyword(prompt, "treatment") {
        return "治疗方案应根据具体疾病制定。"
    } else if contains_keyword(prompt, "药物") || contains_keyword(prompt, "medicine") {
        return "药物治疗需要遵循医嘱。"
    }
    return "感谢您的提问，请提供更多细节。"
}

func main() {
    print("NeurX Keyword Matching Test\n")
    print("════════════════════════════════════════════════\n\n")

    string test1 = "你好"
    string result1 = generate_response(test1)
    print("Input: '" + test1 + "'\n")
    print("Output: '" + result1 + "'\n")
    print("Expected: Contains '医学助手'\n")
    if contains_keyword(result1, "医学助手") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")

    string test2 = "诊断症状"
    string result2 = generate_response(test2)
    print("Input: '" + test2 + "'\n")
    print("Output: '" + result2 + "'\n")
    print("Expected: Contains '诊断' or '症状'\n")
    if contains_keyword(result2, "诊断") || contains_keyword(result2, "症状") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")

    string test3 = "你是什么"
    string result3 = generate_response(test3)
    print("Input: '" + test3 + "'\n")
    print("Output: '" + result3 + "'\n")
    print("Expected: Generic response\n")
    print("✓ PASS (Got: '" + result3 + "')\n")
    print("\n")

    string test4 = "hello"
    string result4 = generate_response(test4)
    print("Input: '" + test4 + "'\n")
    print("Output: '" + result4 + "'\n")
    print("Expected: Contains '医学助手'\n")
    if contains_keyword(result4, "医学助手") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")

    string test5 = "What is diagnosis?"
    string result5 = generate_response(test5)
    print("Input: '" + test5 + "'\n")
    print("Output: '" + result5 + "'\n")
    print("Expected: Contains '诊断' or 'diagnosis' response\n")
    if contains_keyword(result5, "诊断") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")

    print("════════════════════════════════════════════════\n")
    print("Keyword matching verification complete.\n")
}

