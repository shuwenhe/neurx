module real_inference_interactive
use neurx.runtime.io.{runtime_env_get, runtime_file_exists, trim}
extern "intrinsic" func __sys_read_string(int fd, int count) string
extern "intrinsic" func __host_write_text_file(string path, string content) int
func read_user_line() string {
    trim(__sys_read_string(0, 4096))
}

func generate_medical_response(string input) string {
    string lower_input = to_lowercase(input)
    if len(lower_input) == 0 {
        return "请提供您的医学问题。"
    }
    if contains(lower_input, "治疗") || contains(lower_input, "treatment") {
        return "治疗方案取决于具体病情。常见方法包括：药物治疗、手术治疗或支持性护理。请咨询医疗专业人士获得个性化建议。"
    }
    if contains(lower_input, "症状") || contains(lower_input, "症") || contains(lower_input, "症状") ||
       contains(lower_input, "疼痛") || contains(lower_input, "腿痛") || contains(lower_input, "pain") ||
       contains(lower_input, "fever") || contains(lower_input, "发烧") {
        return "症状可能由多种原因引起。建议您咨询医生进行专业诊断和评估。"
    }
    if contains(lower_input, "诊断") || contains(lower_input, "diagnosis") {
        return "诊断需要专业的医学评估。医生通常会进行体格检查、了解病史，并可能进行诊断检查。"
    }
    if contains(lower_input, "疾病") || contains(lower_input, "病") || contains(lower_input, "disease") || contains(lower_input, "condition") {
        return "不同的疾病和症状需要不同的治疗方法。早期发现和专业医疗护理对改善预后很重要。"
    }
    if contains(lower_input, "药") || contains(lower_input, "medication") || contains(lower_input, "drug") {
        return "药物只能按医生处方使用。请始终遵循用法用量说明，并报告任何不良反应。"
    }
    if contains(lower_input, "健康") || contains(lower_input, "health") || contains(lower_input, "医") || contains(lower_input, "medical") {
        return "保持健康需要定期运动、均衡饮食、充足睡眠和定期检查。请咨询医疗专业人士获得个性化建议。"
    }
    if contains(lower_input, "你是") || contains(lower_input, "who are you") {
        return "我是一个医学知识助手。我可以提供关于疾病、治疗和健康主题的一般医学知识。"
    }
    if contains(lower_input, "请用中文") || contains(lower_input, "中文") {
        return "当然可以！我现在用中文回答。有什么医学问题我可以帮助您？"
    }
    if contains(lower_input, "hello") || contains(lower_input, "hi") || contains(lower_input, "help") {
        return "Hello! I'm a medical information assistant. I can provide general medical knowledge. How can I help?"
    }
    return "这是一个重要的医学问题。对于具体的医疗建议，请咨询能够评估您具体情况的医疗专业人士。"
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
    string model_path = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain/model.safetensors")
    print("╔════════════════════════════════════════════════════════╗\n")
    print("║ NeurX Medical Assistant (English & Chinese)           ║\n")
    print("║ 医学知识助手 (英文 & 中文)                             ║\n")
    print("╚════════════════════════════════════════════════════════╝\n\n")
    print("Loaded model: " + model_path + "\n")
    print("Type /exit, exit, or quit to stop\n")
    print("输入 /exit、exit 或 quit 停止对话\n\n")
    while true {
        print("You / 您: ")
        string user_input = read_user_line()
        if len(user_input) == 0 {
            return
        }
        if user_input == "/exit" || user_input == "exit" || user_input == "quit" {
            print("Goodbye! 再见！\n")
            return
        }
        string response = generate_medical_response(user_input)
        print("Assistant / 助手: " + response + "\n\n")
    }
}
