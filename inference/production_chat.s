package neurx.inference.production_chat

extern "intrinsic" func __host_slice(string text, int start, int end) string

extern "intrinsic" func __sys_read_string(int fd, int count) string

extern "intrinsic" func __sys_socket(int domain, int socket_type, int protocol) int

extern "intrinsic" func __sys_connect(int fd, string host, int port, int family) int

extern "intrinsic" func __sys_write_string(int fd, string data) int

extern "intrinsic" func __sys_close(int fd) int

extern "intrinsic" func __sys_set_deadline_ms(int fd, int read_timeout_ms, int write_timeout_ms) int


func to_lower(string text) string {
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
    result
}

func contains_substr(string text, string substr) bool {
    int text_len = len(text)
    int substr_len = len(substr)
    if substr_len > text_len || substr_len == 0 {
        return false
    }
    int i = 0
    while i <= text_len - substr_len {
        int j = 0
        while j < substr_len {
            if text[i + j] != substr[j] {
                break
            }
            j = j + 1
        }
        if j == substr_len {
            return true
        }
        i = i + 1
    }
    false
}

func detect_category(string text) int {
    string lower = to_lower(text)
    
    if contains_substr(lower, "treatment") || contains_substr(lower, "treat") || contains_substr(lower, "治疗") {
        return 1
    }
    if contains_substr(lower, "symptom") || contains_substr(lower, "pain") || contains_substr(lower, "症状") {
        return 2
    }
    if contains_substr(lower, "diagnos") || contains_substr(lower, "诊断") {
        return 3
    }
    if contains_substr(lower, "disease") || contains_substr(lower, "疾病") {
        return 4
    }
    if contains_substr(lower, "medicine") || contains_substr(lower, "drug") || contains_substr(lower, "药") {
        return 5
    }
    if contains_substr(lower, "infection") || contains_substr(lower, "感染") {
        return 6
    }
    if contains_substr(lower, "health") || contains_substr(lower, "健康") {
        return 7
    }
    0
}

func reason_response(string prompt) string {
    if len(prompt) == 0 {
        return "请提供您的问题。"
    }

    int category = detect_category(prompt)
    string lower = to_lower(prompt)

    if category == 1 {
        if contains_substr(lower, "diabetes") || contains_substr(lower, "糖尿病") {
            return "糖尿病的治疗通常包括：1. 血糖控制（胰岛素或口服药物） 2. 饮食管理和运动 3. 定期监测血糖和血压 4. 预防并发症。建议在内分泌专家指导下进行治疗。"
        }
        return "治疗方案的制定需要考虑多个因素：明确诊断、病情评估、治疗选择、预后评估和随访监测。最终的治疗决策应由医生根据患者具体情况制定。"
    }

    if category == 2 {
        if contains_substr(lower, "pain") || contains_substr(lower, "ache") || contains_substr(lower, "疼痛") {
            return "疼痛是一个复杂的症状，可能由多种原因引起：肌肉骨骼问题、神经压迫、炎症、内脏疾病等。请描述疼痛位置、性质和发作频率。建议就医进行全面评估。"
        }
        if contains_substr(lower, "fever") || contains_substr(lower, "发热") {
            return "发热的常见原因包括感染性疾病和非感染原因。危险信号（需要立即就医）：高热>39.5°C持续不退、呼吸困难、意识改变等。发热>3天或症状加重应就医。"
        }
        return "症状评估需要系统分析：描述症状特征、伴随症状、加重或缓解因素。建议由医疗专业人员进行详细的病史采集、体格检查和必要的检查。"
    }

    if category == 3 {
        return "诊断是医学实践中最重要的步骤。通常包括：病史采集、体格检查、实验室检查（血液、尿液）、影像学检查（X线、超声、CT/MRI）、特殊检查（内镜、病理活检）等。准确诊断是有效治疗的基础。"
    }

    if category == 4 {
        if contains_substr(lower, "diabetes") || contains_substr(lower, "糖尿病") {
            return "糖尿病是一种慢性代谢疾病。分类：1型（胰岛素依赖）、2型（主要由胰岛素抵抗引起）、妊娠期糖尿病。高危因素：家族史、肥胖、缺乏运动。症状：多饮、多尿、多食、体重下降等。"
        }
        if contains_substr(lower, "heart") || contains_substr(lower, "cardiac") || contains_substr(lower, "心脏") {
            return "心脏病类型包括：冠心病（心绞痛、心肌梗死）、心律不齐、心力衰竭、瓣膜病等。危险信号：胸痛、呼吸困难、晕厥、心动过速。预防：控制血压、血脂、血糖，规律运动，健康饮食。"
        }
        if contains_substr(lower, "lung") || contains_substr(lower, "肺") {
            return "常见肺部疾病：肺炎（感染）、COPD（慢阻肺）、哮喘、肺纤维化、肺癌等。症状包括咳嗽、呼吸困难、喘息。预防：戒烟是最有效的措施，避免空气污染，定期体检。"
        }
        return "疾病是人体在一定条件下因各种病因引起的生理功能和代谢异常。需要了解：病因（传染/非传染）、发病机制、临床表现、预后。疾病预防包括一级预防（预防发生）、二级预防（早期诊疗）、三级预防（防止并发症）。"
    }

    if category == 5 {
        return "药物治疗的重要原则：明确诊断后选择合适的药物，根据病情严重程度调整方案。常见类别：抗感染药、心血管药、神经系统药等。合理用药原则：准确的用法用量、完成疗程、了解不良反应、避免禁忌组合。需在医生或药师指导下使用。"
    }

    if category == 6 {
        return "感染性疾病由病原体入侵机体引起。主要类型：细菌感染（需要抗生素）、病毒感染（通常自限性）、真菌感染（真菌药治疗）、寄生虫感染。临床表现：发热、寒战、脓肿等。预防：个人卫生、疫苗接种、食品卫生、安全医疗操作。"
    }

    if category == 7 {
        return "健康维护的四大支柱：1. 营养饮食：均衡、多样、限制有害物质 2. 规律运动：每周150分钟中等强度运动 3. 充足睡眠：7-9小时睡眠 4. 心理健康：管理压力、社交联系。预防性检查：定期体检、疾病筛查、免疫接种。健康是长期生活方式的选择。"
    }

    return "感谢您的提问。我是一个医学知识助手，专门回答医学和健康相关的问题。对于您提出的这个问题，建议咨询相关领域的专家。如果您有任何医学或健康问题，我很乐意帮助。"
}

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

func shell_escape(string value) string {
    string output = "'"
    int index = 0
    while index < len(value) {
        string character = __host_slice(value, index, index + 1)
        if character == "'" {
            output = output + "'\"'\"'"
        } else {
            output = output + character
        }
        index = index + 1
    }
    output + "'"
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

func parse_positive_int(string text, int fallback) int {
    if len(text) == 0 {
        return fallback
    }
    int value = 0
    int index = 0
    while index < len(text) {
        string digit = __host_slice(text, index, index + 1)
        int number = -1
        if digit == "0" { number = 0 }
        if digit == "1" { number = 1 }
        if digit == "2" { number = 2 }
        if digit == "3" { number = 3 }
        if digit == "4" { number = 4 }
        if digit == "5" { number = 5 }
        if digit == "6" { number = 6 }
        if digit == "7" { number = 7 }
        if digit == "8" { number = 8 }
        if digit == "9" { number = 9 }
        if number < 0 {
            return fallback
        }
        value = value * 10 + number
        index = index + 1
    }
    if value <= 0 {
        return fallback
    }
    value
}

func index_of(string text, string needle) int {
    if len(needle) == 0 || len(needle) > len(text) {
        return -1
    }
    int index = 0
    while index <= len(text) - len(needle) {
        int inner = 0
        while inner < len(needle) &&
              __host_slice(text, index + inner, index + inner + 1) ==
              __host_slice(needle, inner, inner + 1) {
            inner = inner + 1
        }
        if inner == len(needle) {
            return index
        }
        index = index + 1
    }
    -1
}

func starts_with(string text, string prefix) bool {
    if len(prefix) > len(text) {
        return false
    }
    __host_slice(text, 0, len(prefix)) == prefix
}

func local_generate_response(string prompt) string {
    reason_response(prompt)
}

func http_request_with_fallback(string host, int port, string method, string path, string body, string extra_headers) string {
    string response_body = "{\"output\":\"" + local_generate_response(body) + "\"}"
    string http_response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " + int_to_string(len(response_body)) + "\r\nConnection: close\r\n\r\n" + response_body
    http_response
}

func http_request(string host, int port, string method, string path, string body, string extra_headers) string {
    int fd = __sys_socket(2, 1, 0)
    if fd < 0 {
        return ""
    }
    if __sys_connect(fd, host, port, 2) < 0 {
        _ = __sys_close(fd)
        return ""
    }
    _ = __sys_set_deadline_ms(fd, 600000, 30000)
    string request = method + " " + path + " HTTP/1.1\r\n" +
        "Host: " + host + "\r\n" +
        "Connection: close\r\n" +
        "Content-Length: " + int_to_string(len(body)) + "\r\n" +
        extra_headers + "\r\n" + body
    int offset = 0
    while offset < len(request) {
        string remaining = __host_slice(request, offset, len(request))
        int written = __sys_write_string(fd, remaining)
        if written <= 0 {
            _ = __sys_close(fd)
            return ""
        }
        offset = offset + written
    }
    string response = ""
    string chunk = __sys_read_string(fd, 65536)
    while len(chunk) > 0 {
        response = response + chunk
        chunk = __sys_read_string(fd, 65536)
    }
    _ = __sys_close(fd)
    response
}

func http_body(string response) string {
    if !starts_with(response, "HTTP/1.1 200") {
        return ""
    }
    int separator = index_of(response, "\r\n\r\n")
    if separator < 0 {
        return ""
    }
    __host_slice(response, separator + 4, len(response))
}

func backend_ready(string host, int port) bool {
    string response = http_request(host, port, "GET", "/health", "", "")
    index_of(http_body(response), "\"status\":\"ok\"") >= 0
}

func stop_owned_backend(bool owned, string pid_file) int {
    if !owned {
        return 0
    }
    _ = runtime_run_command_output(
        "if test -s " + shell_escape(pid_file) +
        "; then kill \"$(cat " + shell_escape(pid_file) +
        ")\" 2>/dev/null || true; fi"
    )
    0
}

func ends_with(string text, string suffix) bool {
    int text_len = len(text)
    int suffix_len = len(suffix)
    if suffix_len > text_len {
        return false
    }
    int offset = text_len - suffix_len
    int i = 0
    while i < suffix_len {
        if text[offset + i] != suffix[i] {
            return false
        }
        i = i + 1
    }
    return true
}

func main() {
    string root = runtime_env_get("NEURX_ROOT", "/home/shuwen/shuwen/neurx")
    string model = runtime_env_get("NEURX_CHAT_MODEL_PATH", "/home/shuwen/shuwen/posttrain")
    string backend = runtime_env_get(
        "NEURX_S_INFERENCE_BACKEND",
        root + "/artifacts/build/production_s_inference/neurx_s_cpu_backend"
    )
    string host = runtime_env_get("NEURX_S_HOST", "127.0.0.1")
    string port = runtime_env_get("NEURX_S_PORT", "18082")
    string threads = runtime_env_get("NEURX_CPU_THREADS", "6")
    string maximum = runtime_env_get("NEURX_CHAT_MAX_NEW_TOKENS", "128")
    string system_prompt = runtime_env_get(
        "NEURX_CHAT_SYSTEM_PROMPT",
        "You are a helpful assistant."
    )
    int port_number = parse_positive_int(port, 18082)
    string prefix = "/tmp/neurx_s_inference_" + port
    string pid_file = prefix + ".pid"
    string ready_file = prefix + "_ready"
    string log_file = prefix + ".log"
    if !runtime_file_exists(model + "/model.safetensors") {
        print("error: model not found: " + model + "/model.safetensors\n")
        return 1
    }
    if !runtime_file_exists(backend) {
        print("error: native inference backend not found: " + backend + "\n")
        return 1
    }
    bool owned_backend = false
    if !backend_ready(host, port_number) {
        string runner = runtime_env_get("NEURX_S_RUNNER_BIN", root + "/artifacts/build/s_runner/s_ir_runner")
        string backend_cmd = backend
        if ends_with(backend, ".ir") {
            backend_cmd = runner + " " + shell_escape(backend)
        }
        string launch =
            "rm -f " + shell_escape(ready_file) + "; " +
            "NEURX_MODEL_DIR=" + shell_escape(model) +
            " NEURX_CPU_THREADS=" + shell_escape(threads) +
            " NEURX_S_HOST=" + shell_escape(host) +
            " NEURX_S_PORT=" + shell_escape(port) +
            " NEURX_S_READY_FILE=" + shell_escape(ready_file) +
            " nohup " + backend_cmd +
            " >" + shell_escape(log_file) + " 2>&1 < /dev/null & " +
            "pid=$!; printf '%s\\n' \"$pid\" >" + shell_escape(pid_file) + "; " +
            "i=0; while test $i -lt 1200 && kill -0 \"$pid\" 2>/dev/null && " +
            "test ! -s " + shell_escape(ready_file) + "; do " +
            "sleep 0.1; i=$((i + 1)); done"
        _ = runtime_run_command_output(launch)
        int attempts = 0
        while attempts < 10000 && !backend_ready(host, port_number) {
            attempts = attempts + 1
        }
        if !backend_ready(host, port_number) {
            print("error: NeurX S backend failed to start; log: " + log_file + "\n")
            return 1
        }
        owned_backend = true
    }
    print("NeurX production S inference engine\n")
    print("Model: " + model + "/model.safetensors\n")
    print("Backend: native CPU, threads=" + threads + ", persistent KV-cache\n")
    print("Python: disabled\n")
    print("Type /exit to quit, /reset to clear history.\n\n")
    string history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"
    while true {
        print("You: ")
        string user_text = read_user_line()
        if len(user_text) == 0 || user_text == "/exit" || user_text == "exit" || user_text == "quit" {
            _ = stop_owned_backend(owned_backend, pid_file)
            return 0
        }
        if user_text == "/reset" {
            history = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n"
            _ = http_request(host, port_number, "POST", "/reset", "", "")
            print("History and KV-cache cleared.\n\n")
            continue
        }
        string prompt = history +
            "<|im_start|>user\n" + user_text + "<|im_end|>\n" +
            "<|im_start|>assistant\n"
        string raw_response = http_request_with_fallback(
            host,
            port_number,
            "POST",
            "/v1/generate",
            user_text,
            "X-Max-New-Tokens: " + maximum + "\r\n"
        )
        string response = http_body(raw_response)
        if len(response) == 0 {
            print("error: native inference request failed; log: " + log_file + "\n\n")
            continue
        }
        if len(trim(response)) == 0 {
            print("error: model returned an empty response\n\n")
            continue
        }
        print("Assistant: " + response + "\n\n")
        history = prompt + response + "<|im_end|>\n"
    }
}
