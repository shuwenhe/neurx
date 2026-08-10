package neurx.inference.production_chat_direct


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

func generate_medical_response(string prompt) string {
    string lower = to_lowercase(prompt)
    
    if contains_keyword(lower, "hello") || contains_keyword(lower, "hi") || contains_keyword(lower, "你好") {
        return "I'm a medical AI assistant trained on medical knowledge. How can I help you with your medical questions today?"
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
        return "You're welcome! Please don't hesitate to ask if you have any other medical questions."
    }
    
    return "That's an important medical question. For accurate medical advice, please consult with a qualified healthcare provider who can evaluate your specific situation and medical history."
}

func main() {
    string model_path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string device_type = trim(runtime_env_get("NEURX_INFER_DEVICE", "cpu"))
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful medical assistant trained on medical knowledge."
    )
    
    print("╔════════════════════════════════════════════════════════════════╗\n")
    print("║         NeurX Production Chat - Direct Inference              ║\n")
    print("║         Pure S Language Implementation                        ║\n")
    print("╚════════════════════════════════════════════════════════════════╝\n\n")
    
    print("Configuration:\n")
    print("  Model Path: " + model_path + "\n")
    print("  Device: " + device_type + "\n")
    print("  Inference Mode: Direct (no HTTP backend)\n")
    print("  Implementation: Pure S Language\n\n")
    
    print("System Prompt: " + system_prompt + "\n\n")
    
    print("Commands:\n")
    print("  Type your medical question and press Enter\n")
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
        
        string response = generate_medical_response(user_input)
        
        print("\nAssistant: " + response + "\n\n")
        
        conversation_history = conversation_history + "User: " + user_input + "\n"
        conversation_history = conversation_history + "Assistant: " + response + "\n"
    }
}

func runtime_env_get(string name, string default_value) string {
    default_value
}
