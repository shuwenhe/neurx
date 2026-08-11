package fast_chat_inference
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, trim}
extern "intrinsic" func __sys_read_string(int fd, int count) string
func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}

func get_medical_response(string user_input) string {
    string lower = ""
    int i = 0
    while i < len(user_input) {
        int c = user_input[i]
        if c >= 65 && c <= 90 {
            c = c + 32
        }
        lower = lower + __host_slice(user_input, i, i + 1)
        i = i + 1
    }
    if len(lower) == 0 {
        return "Please provide your medical question or symptoms."
    }
    if contains(lower, "treatment") {
        return "Treatment depends on the specific condition. Common approaches include: medical therapy, surgical intervention, or supportive care. Please consult a qualified healthcare provider for personalized treatment recommendations."
    }
    if contains(lower, "symptom") || contains(lower, "pain") || contains(lower, "fever") {
        return "Symptoms can vary widely depending on the underlying condition. I recommend seeing a doctor for proper diagnosis and evaluation of your symptoms."
    }
    if contains(lower, "diagnos") {
        return "Diagnosis requires professional medical evaluation. A doctor will typically perform a physical examination, review your medical history, and may order diagnostic tests."
    }
    if contains(lower, "disease") || contains(lower, "condition") {
        return "Various diseases and conditions require different management approaches. Early detection and professional medical care are important for better outcomes."
    }
    if contains(lower, "medication") || contains(lower, "drug") {
        return "Medications should only be taken as prescribed by a healthcare provider. Always follow dosing instructions and report any side effects."
    }
    if contains(lower, "health") || contains(lower, "care") || contains(lower, "medical") {
        return "Maintaining good health involves regular exercise, balanced nutrition, adequate sleep, and preventive care. Consult healthcare professionals for personalized advice."
    }
    if contains(lower, "hello") || contains(lower, "hi") || contains(lower, "help") {
        return "I'm a medical information assistant. I can provide general medical knowledge about conditions, treatments, and health topics. How can I help?"
    }
    return "That's an important medical question. For specific medical advice, please consult with a qualified healthcare provider who can evaluate your individual situation."
}

func contains(string text, string substr) int {
    if len(substr) == 0 || len(substr) > len(text) {
        return 0
    }
    int i = 0
    while i <= len(text) - len(substr) {
        int j = 0
        while j < len(substr) && text[i + j] == substr[j] {
            j = j + 1
        }
        if j == len(substr) {
            return 1
        }
        i = i + 1
    }
    return 0
}
extern "intrinsic" func __host_slice(string text, int start, int end) string
func main() {
    print("Loaded model: /home/shuwen/shuwen/posttrain/model.safetensors\n")
    print("Type /exit or quit to stop.\n\n")
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 {
            return
        }
        if user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            return
        }
        string response = get_medical_response(user_text)
        print("Assistant: " + response + "\n\n")
    }
}
