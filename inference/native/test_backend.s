use std.conv.int_to_string

package neurx.inference.test_backend
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

func generate_response(string prompt, int max_tokens) string {
    string response = ""
    if contains_keyword(prompt, "你好") || contains_keyword(prompt, "hello") || contains_keyword(prompt, "hi") {
        response = "您好！我是医学助手，已准备就绪。请告诉我您想了解的医学问题。"
    } else if contains_keyword(prompt, "你是") || contains_keyword(prompt, "who are") {
        response = "我是一个基于医学知识库的AI助手，经过医学多选题数据集(MedMCQA)的微调。可以帮助您回答医学相关问题。"
    } else if contains_keyword(prompt, "症状") || contains_keyword(prompt, "symptom") {
        response = "医学症状通常分为主要症状和伴随症状。请详细描述您关心的具体症状，我会提供医学解释和建议。"
    } else if contains_keyword(prompt, "诊断") || contains_keyword(prompt, "diagnosis") {
        response = "诊断需要基于患者的症状、体征、实验室检查和影像学检查等多方面信息。建议咨询专业医生进行准确诊断。"
    } else if contains_keyword(prompt, "治疗") || contains_keyword(prompt, "treatment") {
        response = "治疗方案应根据具体疾病、患者条件和医学证据制定。常见治疗方法包括药物治疗、物理治疗和手术治疗等。"
    } else if contains_keyword(prompt, "药物") || contains_keyword(prompt, "medicine") || contains_keyword(prompt, "drug") {
        response = "药物治疗需要遵循医嘱，了解药物的适应症、用法用量、不良反应和禁忌。任何用药前应咨询医生或药师。"
    } else if contains_keyword(prompt, "感染") || contains_keyword(prompt, "infection") {
        response = "感染是病原体入侵机体后引起的炎症反应。根据病原体类型和感染部位，治疗方法不同。需要及时就医。"
    } else if contains_keyword(prompt, "疾病") || contains_keyword(prompt, "disease") {
        response = "疾病是机体在一定条件下因各种病因引起的生理功能和代谢异常。了解具体疾病的病理、症状和治疗是重要的。"
    } else if contains_keyword(prompt, "健康") || contains_keyword(prompt, "health") {
        response = "保持健康需要合理的饮食、适当的运动、充足的睡眠和心理健康。预防疾病比治疗疾病更重要。"
    } else if contains_keyword(prompt, "谢谢") || contains_keyword(prompt, "thanks") {
        response = "不客气！如果您还有其他医学问题，欢迎继续提问。祝您健康！"
    } else {
        response = "感谢您的提问。这是一个有趣的医学问题。基于医学知识库，我理解您可能在询问相关的医学概念。请提供更多细节以便我给出更准确的回答。"
    }
    return response
}

extern "intrinsic" func __sys_read_string(int fd, int count) string

func main() {
    print("NeurX Medical AI Backend - Interactive Mode\n")
    print("Type medical queries (or /exit to quit)\n")
    print("\n")
    while true {
        print("You: ")
        string input = __sys_read_string(0, 512)
        if input == "/exit" || input == "exit" {
            print("Goodbye!\n")
            return
        }
        if len(input) == 0 {
            continue
        }
        string response = generate_response(input, 128)
        print("Assistant: " + response + "\n\n")
    }
}
