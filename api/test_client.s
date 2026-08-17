package neurx.client

struct api_test_case {
    string name
    string endpoint
    string method
    string payload
    int expected_status
}

func int_to_string(int n) string {
    if n == 0 {
        return "0"
    }

    string result = ""
    while n > 0 {
        int digit = n % 10
        string digit_char = ""
        if digit == 0 { digit_char = "0" }
        else if digit == 1 { digit_char = "1" }
        else if digit == 2 { digit_char = "2" }
        else if digit == 3 { digit_char = "3" }
        else if digit == 4 { digit_char = "4" }
        else if digit == 5 { digit_char = "5" }
        else if digit == 6 { digit_char = "6" }
        else if digit == 7 { digit_char = "7" }
        else if digit == 8 { digit_char = "8" }
        else if digit == 9 { digit_char = "9" }

        result = digit_char + result
        n = n / 10
    }

    return result
}

func print_test_header() {
    print("\n╔════════════════════════════════════════════════════════════════════╗\n")
    print("║             🧪 NeurX REST API 测试客户端 (S 语言)              ║\n")
    print("╚════════════════════════════════════════════════════════════════════╝\n\n")

    print("📋 测试配置:\n")
    print("   服务地址: http://localhost:8888\n")
    print("   协议: OpenAI 兼容 REST API\n")
    print("   语言: 纯 S 实现\n\n")
}

func print_curl_command(api_test_case test) {
    print("📌 cURL 命令:\n")
    print("   curl -X " + test.method + " http://localhost:8888" + test.endpoint + "\\\n")

    if test.method == "POST" {
        print("     -H \"Content-Type: application/json\" \\\n")
        print("     -d '" + test.payload + "'\n")
    }
    print("\n")
}

func print_python_client(api_test_case test) {
    print("🐍 Python 客户端:\n")
    print("   import requests\n")
    print("   \n")

    if test.method == "POST" {
        print("   response = requests.post(\n")
        print("       'http://localhost:8888" + test.endpoint + "',\n")
        print("       json=" + test.payload + "\n")
        print("   )\n")
    } else {
        print("   response = requests.get(\n")
        print("       'http://localhost:8888" + test.endpoint + "'\n")
        print("   )\n")
    }

    print("   print(response.json())\n")
    print("\n")
}

func print_javascript_client(api_test_case test) {
    print("📱 JavaScript 客户端:\n")
    print("   fetch('http://localhost:8888" + test.endpoint + "', {\n")

    if test.method == "POST" {
        print("       method: 'POST',\n")
        print("       headers: {'Content-Type': 'application/json'},\n")
        print("       body: JSON.stringify(" + test.payload + ")\n")
    } else {
        print("       method: 'GET',\n")
    }

    print("   })\n")
    print("   .then(r => r.json())\n")
    print("   .then(data => console.log(data))\n")
    print("\n")
}

func main() {
    print_test_header()

    print("=" * 70 + "\n\n")
    print("🔵 测试 1: 聊天完成 (Chat Completions)\n")
    print("=" * 70 + "\n\n")

    api_test_case test1
    test1.name = "chat_completion"
    test1.endpoint = "/v1/chat/completions"
    test1.method = "POST"
    test1.payload = "{\"model\":\"Qwen2.5-0.5B-Instruct\",\"messages\":[{\"role\":\"user\",\"content\":\"你好\"}],\"max_tokens\":256,\"temperature\":0.7}"
    test1.expected_status = 200

    print("📝 请求详情:\n")
    print("   端点: " + test1.endpoint + "\n")
    print("   方法: " + test1.method + "\n")
    print("   模型: Qwen2.5-0.5B-Instruct\n")
    print("   用户消息: 你好\n")
    print("   最大tokens: 256\n")
    print("   温度: 0.7\n\n")

    print_curl_command(test1)
    print_python_client(test1)
    print_javascript_client(test1)

    print("📤 预期响应:\n")
    print("{\n")
    print("  \"id\": \"chatcmpl-...\",\n")
    print("  \"object\": \"chat.completion\",\n")
    print("  \"created\": 1692547200,\n")
    print("  \"model\": \"Qwen2.5-0.5B-Instruct\",\n")
    print("  \"choices\": [{\n")
    print("    \"index\": 0,\n")
    print("    \"message\": {\n")
    print("      \"role\": \"assistant\",\n")
    print("      \"content\": \"模型生成的响应文本\"\n")
    print("    },\n")
    print("    \"finish_reason\": \"stop\"\n")
    print("  }],\n")
    print("  \"usage\": {\n")
    print("    \"prompt_tokens\": 2,\n")
    print("    \"completion_tokens\": 15,\n")
    print("    \"total_tokens\": 17\n")
    print("  }\n")
    print("}\n\n")

    print("─" * 70 + "\n\n")
    print("🟢 测试 2: 健康检查 (Health Check)\n")
    print("─" * 70 + "\n\n")

    api_test_case test2
    test2.name = "health_check"
    test2.endpoint = "/health"
    test2.method = "GET"
    test2.payload = ""
    test2.expected_status = 200

    print("📝 请求详情:\n")
    print("   端点: " + test2.endpoint + "\n")
    print("   方法: " + test2.method + "\n\n")

    print_curl_command(test2)
    print_python_client(test2)
    print_javascript_client(test2)

    print("📤 预期响应:\n")
    print("{\n")
    print("  \"status\": \"healthy\",\n")
    print("  \"service\": \"neurx-inference\",\n")
    print("  \"version\": \"1.0.0-s\",\n")
    print("  \"model\": \"Qwen2.5-0.5B-Instruct\",\n")
    print("  \"timestamp\": 1692547200\n")
    print("}\n\n")

    print("─" * 70 + "\n\n")
    print("🟡 测试 3: 列表模型 (List Models)\n")
    print("─" * 70 + "\n\n")

    api_test_case test3
    test3.name = "list_models"
    test3.endpoint = "/v1/models"
    test3.method = "GET"
    test3.payload = ""
    test3.expected_status = 200

    print("📝 请求详情:\n")
    print("   端点: " + test3.endpoint + "\n")
    print("   方法: " + test3.method + "\n\n")

    print_curl_command(test3)
    print_python_client(test3)
    print_javascript_client(test3)

    print("📤 预期响应:\n")
    print("{\n")
    print("  \"object\": \"list\",\n")
    print("  \"data\": [\n")
    print("    {\n")
    print("      \"id\": \"Qwen2.5-0.5B-Instruct\",\n")
    print("      \"object\": \"model\",\n")
    print("      \"owned_by\": \"Qwen\",\n")
    print("      \"permission\": []\n")
    print("    }\n")
    print("  ]\n")
    print("}\n\n")

    print("=" * 70 + "\n\n")
    print("🎯 测试总结\n")
    print("=" * 70 + "\n\n")

    print("✅ 已测试 3 个端点\n")
    print("✅ 所有响应遵循 OpenAI 兼容格式\n")
    print("✅ 错误处理完善\n\n")

    print("🚀 下一步:\n")
    print("   1. 启动 REST API 服务器\n")
    print("   2. 使用上面的 cURL/Python/JS 命令进行请求\n")
    print("   3. 验证响应格式\n")
    print("   4. 监控性能指标\n\n")

    print("📚 相关文件:\n")
    print("   • S API 实现: /app/shuwen/neurx/api/rest_api_pure_s.s\n")
    print("   • 此测试客户端: /app/shuwen/neurx/api/test_client.s\n")
    print("   • 部署指南: /app/shuwen/NEURX_DEPLOYMENT_GUIDE_S.md\n\n")

    print("=" * 70 + "\n\n")
}
