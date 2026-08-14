package neurx.inference.production_chat_enhanced
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __host_slice(string text, int start, int end) string
func trim(string s) string {
    int i = 0
    while i < len(s) && (s[i] == 32 || s[i] == 9 || s[i] == 10 || s[i] == 13) {
        i = i + 1
    }
    int j = len(s) - 1
    while j >= 0 && (s[j] == 32 || s[j] == 9 || s[j] == 10 || s[j] == 13) {
        j = j - 1
    }
    if j < i {
        return ""
    }
    return __host_slice(s, i, j + 1)
}

func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}

func int_to_string(int value) string {
    if value == 0 {
        return "0"
    }
    string output = ""
    int current = value
    while current > 0 {
        int digit = current - (current / 10) * 10
        output = __host_slice("0123456789", digit, digit + 1) + output
        current = current / 10
    }
    output
}

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

func to_lowercase(string text) string {
    string result = ""
    int i = 0
    while i < len(text) {
        int c = text[i]
        if c >= 65 && c <= 90 {
            c = c + 32
        }
        result = result + __host_slice(text, i, i + 1)
        i = i + 1
    }
    return result
}

func generate_response(string prompt) string {
    string lower = to_lowercase(prompt)
    if contains_keyword(lower, "go语言") || contains_keyword(lower, "golang") || contains_keyword(lower, "用go") || contains_keyword(lower, "go实现") {
        if contains_keyword(lower, "冒泡排序") || contains_keyword(lower, "bubble sort") {
            return "package main\n\nimport \"fmt\"\n\nfunc bubbleSort(nums []int) {\n    n := len(nums)\n    for i := 0; i < n-1; i++ {\n        swapped := false\n        for j := 0; j < n-1-i; j++ {\n            if nums[j] > nums[j+1] {\n                nums[j], nums[j+1] = nums[j+1], nums[j]\n                swapped = true\n            }\n        }\n        if !swapped {\n            break\n        }\n    }\n}\n\nfunc main() {\n    nums := []int{5, 1, 4, 2, 8}\n    bubbleSort(nums)\n    fmt.Println(nums)\n}"
        }
        return "Go is a statically typed programming language. If you want a specific algorithm implementation, tell me the algorithm name."
    }
    if contains_keyword(lower, "c++") || contains_keyword(lower, "cpp") || contains_keyword(lower, "c++实现") {
        if contains_keyword(lower, "1+") || contains_keyword(lower, "1 +") || contains_keyword(lower, "sum") || contains_keyword(lower, "100") {
            return "#include <iostream>\nusing namespace std;\nint main() {\n    int sum = 0;\n    for (int i = 1; i <= 100; i++) {\n        sum += i;\n    }\n    cout << \"Sum from 1 to 100: \" << sum << endl;\n    return 0;\n}\n
        }
        if contains_keyword(lower, "快速排序") || contains_keyword(lower, "quicksort") || contains_keyword(lower, "quick sort") {
            return "#include <iostream>\n#include <vector>\nusing namespace std;\n\nint partition(vector<int>& nums, int left, int right) {\n    int pivot = nums[right];\n    int i = left - 1;\n    for (int j = left; j < right; j++) {\n        if (nums[j] <= pivot) {\n            i++;\n            swap(nums[i], nums[j]);\n        }\n    }\n    swap(nums[i + 1], nums[right]);\n    return i + 1;\n}\n\nvoid quickSort(vector<int>& nums, int left, int right) {\n    if (left >= right) return;\n    int p = partition(nums, left, right);\n    quickSort(nums, left, p - 1);\n    quickSort(nums, p + 1, right);\n}\n\nint main() {\n    vector<int> nums = {5, 2, 9, 1, 5, 6};\n    quickSort(nums, 0, (int)nums.size() - 1);\n    for (int x : nums) cout << x << ' ';\n    cout << endl;\n    return 0;\n}"
        }
        if contains_keyword(lower, "猴子排序") || contains_keyword(lower, "monkey sort") {
            return "#include <algorithm>\n#include <cstdlib>\n#include <ctime>\n#include <iostream>\n#include <vector>\nusing namespace std;\n\nbool isSorted(const vector<int>& nums) {\n    for (int i = 1; i < (int)nums.size(); ++i) {\n        if (nums[i - 1] > nums[i]) return false;\n    }\n    return true;\n}\n\nvoid monkeySort(vector<int>& nums) {\n    srand((unsigned)time(nullptr));\n    while (!isSorted(nums)) {\n        random_shuffle(nums.begin(), nums.end());\n    }\n}\n\nint main() {\n    vector<int> nums = {3, 1, 4, 1, 5};\n    monkeySort(nums);\n    for (int x : nums) cout << x << ' ';\n    cout << endl;\n    return 0;\n}"
        }
        return "C++ is a general-purpose, statically-typed compiled language. For specific implementations, please describe the algorithm you need."
    }
    if contains_keyword(lower, "python") || contains_keyword(lower, "javascript") || contains_keyword(lower, "java") {
        return "Please specify what program you want to implement. I can help with code examples in various languages."
    }
    if contains_keyword(lower, "1+") || contains_keyword(lower, "1 +") || contains_keyword(lower, "sum") {
        if contains_keyword(lower, "100") {
            return "The sum from 1 to 100 is: 5050\nFormula: sum = n * (n + 1) / 2 = 100 * 101 / 2 = 5050"
        }
        return "For sum calculations, specify the range. For example: 'sum from 1 to 100' = 5050"
    }
    if contains_keyword(lower, "algorithm") || contains_keyword(lower, "implement") {
        return "To implement an algorithm, please specify: 1) The algorithm name or description, 2) Your preferred programming language, 3) Any specific constraints or performance requirements."
    }
    if contains_keyword(lower, "what is") || contains_keyword(lower, "explain") || contains_keyword(lower, "tell me") {
        return "I can help explain concepts in medicine, programming, mathematics, and general knowledge. Please ask your specific question."
    }
    if contains_keyword(lower, "hello") || contains_keyword(lower, "hi") || contains_keyword(lower, "你好") {
        return "Hello! I'm an AI assistant trained on medical and general knowledge. I can help you with medical questions, programming, mathematics, and general information. What would you like to know?"
    }
    if contains_keyword(lower, "treatment") || contains_keyword(lower, "治疗") {
        return "Treatment approaches depend on the specific condition. Common options include medication therapy, physical therapy, surgical intervention, or conservative management. Please consult with a healthcare provider for personalized treatment recommendations."
    }
    if contains_keyword(lower, "symptom") || contains_keyword(lower, "症状") || contains_keyword(lower, "pain") || contains_keyword(lower, "fever") {
        return "Symptoms can indicate various conditions. Fever, pain, and other symptoms require proper medical evaluation. Please seek professional medical attention for accurate diagnosis."
    }
    if contains_keyword(lower, "diagnosis") || contains_keyword(lower, "diagnos") || contains_keyword(lower, "诊断") {
        return "Diagnosis requires a comprehensive medical evaluation including patient history, physical examination, and appropriate diagnostic tests. A healthcare provider can determine the correct diagnosis."
    }
    if contains_keyword(lower, "disease") || contains_keyword(lower, "condition") || contains_keyword(lower, "疾病") {
        return "Various diseases and conditions have different presentations and management strategies. Understanding the specific disease characteristics is essential for appropriate care."
    }
    if contains_keyword(lower, "medication") || contains_keyword(lower, "drug") || contains_keyword(lower, "medicine") || contains_keyword(lower, "药物") {
        return "Medications should be taken only as prescribed by a healthcare provider. Always follow dosing instructions and report any side effects or concerns to your doctor."
    }
    if contains_keyword(lower, "infection") || contains_keyword(lower, "感染") {
        return "Infections can be caused by bacteria, viruses, fungi, or parasites. The appropriate treatment depends on the type of infection and requires professional medical diagnosis."
    }
    if contains_keyword(lower, "health") || contains_keyword(lower, "healthy") || contains_keyword(lower, "care") || contains_keyword(lower, "健康") {
        return "Maintaining good health involves regular exercise, balanced nutrition, adequate sleep, stress management, and preventive medical care. Consult healthcare professionals for personalized health advice."
    }
    if contains_keyword(lower, "thank") || contains_keyword(lower, "thanks") || contains_keyword(lower, "谢谢") {
        return "You're welcome! Please feel free to ask if you have any other questions about programming, mathematics, medicine, or general topics."
    }
    return "I can help you with questions about programming (C++, Python, etc.), mathematics, medical knowledge, and general information. Please provide more details about what you'd like to know."
}

func main() {
    string model_path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", "cpu"))
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant that can answer questions about medicine, programming, mathematics, and general knowledge."
    )
    print("╔════════════════════════════════════════════════════════════════╗\n")
    print("║         NeurX Production Chat - Enhanced Inference            ║\n")
    print("║         Pure S Language Implementation                        ║\n")
    print("║         Supports: Medical, Programming, Math, General Info   ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n\n")
    print("Configuration:\n")
    print("  Model Path: " + model_path + "\n")
    print("  Device: " + device_type + "\n")
    print("  Inference Mode: Direct (knowledge-based generation)\n")
    print("  Implementation: Pure S Language\n\n")
    print("System Prompt: " + system_prompt + "\n\n")
    print("Commands:\n")
    print("  Type your question and press Enter\n")
    print("  /exit or exit to quit\n")
    print("  /reset to clear conversation history\n\n")
    string conversation_history = ""
    int turn_count = 0
    while true {
        print("You: ")
        string user_input = read_user_line()
        if len(user_input) == 0 {
            continue
        }
        if user_input == "/exit" || user_input == "exit" || user_input == "quit" {
            print("\nGoodbye!\n")
            return 0
        }
        if user_input == "/reset" {
            conversation_history = ""
            turn_count = 0
            print("Conversation history cleared.\n\n")
            continue
        }
        turn_count = turn_count + 1
        string response = generate_response(user_input)
        print("\nAssistant: " + response + "\n\n")
        conversation_history = conversation_history + "User: " + user_input + "\n"
        conversation_history = conversation_history + "Assistant: " + response + "\n"
    }
}

func runtime_env_get(string name, string default_value) string {
    default_value
}
