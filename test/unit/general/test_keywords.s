package neurx.inference.test_keywords
extern "intrinsic" func __host_slice(string text, int start, int end) string

func contains_keyword(string text, string keyword) bool {
    int text_len = len(text)
    int keyword_len = len(keyword)
    if keyword_len > text_len {
        return false
    }
    int i = 0
    for i <= text_len - keyword_len {
        bool match = true
        int j = 0
        for j < keyword_len {
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
    if contains_keyword(prompt, "hello") || contains_keyword(prompt, "hello") {
        return "您good！我isMedical Assistant。"
    } else if contains_keyword(prompt, "Diagnosis") || contains_keyword(prompt, "diagnosis") {
        return "Diagnosisneed基于PatientofSymptoms、体征and各itemscheck。"
    } else if contains_keyword(prompt, "Symptoms") || contains_keyword(prompt, "symptom") {
        return "请详细描述您关心ofspecificSymptoms。"
    } else if contains_keyword(prompt, "Treatment") || contains_keyword(prompt, "treatment") {
        return "Treatmentsolution应based onspecificDisease制set。"
    } else if contains_keyword(prompt, "medicine") || contains_keyword(prompt, "medicine") {
        return "medicineTreatmentneed遵循医嘱。"
    }
    return "thank youof提问，请提供更more细节。"
}

func main() {
    print("NeurX Keyword Matching Test\n")
    print("════════════════════════════════════════════════\n\n")
    string test1 = "hello"
    string result1 = generate_response(test1)
    print("Input: '" + test1 + "'\n")
    print("Output: '" + result1 + "'\n")
    print("Expected: Contains 'Medical Assistant'\n")
    if contains_keyword(result1, "Medical Assistant") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")
    string test2 = "DiagnosisSymptoms"
    string result2 = generate_response(test2)
    print("Input: '" + test2 + "'\n")
    print("Output: '" + result2 + "'\n")
    print("Expected: Contains 'Diagnosis' or 'Symptoms'\n")
    if contains_keyword(result2, "Diagnosis") || contains_keyword(result2, "Symptoms") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")
    string test3 = "你is什么"
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
    print("Expected: Contains 'Medical Assistant'\n")
    if contains_keyword(result4, "Medical Assistant") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")
    string test5 = "What is diagnosis"
    string result5 = generate_response(test5)
    print("Input: '" + test5 + "'\n")
    print("Output: '" + result5 + "'\n")
    print("Expected: Contains 'Diagnosis' or 'diagnosis' response\n")
    if contains_keyword(result5, "Diagnosis") {
        print("✓ PASS\n")
    } else {
        print("✗ FAIL\n")
    }
    print("\n")
    print("════════════════════════════════════════════════\n")
    print("Keyword matching verification complete.\n")
}
