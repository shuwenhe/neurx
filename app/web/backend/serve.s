package neurx.app.backend

use std.env.get as env_get
use std.io.println

func json_escape(string text) string {
    int n = len(text)
    string out = ""
    int i = 0
    while i < n {
        string ch = text[i]
        if ch == "\\" {
            out = out + "\\\\"
        } else if ch == "\"" {
            out = out + "\\\""
        } else if ch == "\n" {
            out = out + "\\n"
        } else if ch == "\r" {
            out = out + "\\r"
        } else if ch == "\t" {
            out = out + "\\t"
        } else {
            out = out + ch
        }
        i = i + 1
    }
    out
}

func read_prompt() string {
    string prompt = env_get("NEURX_BACKEND_PROMPT").unwrap_or("")
    if prompt == "" {
        return "Please provide your request."
    }
    prompt
}

func extract_summary(string prompt) string {
    string text = prompt
    int n = len(text)
    if n == 0 {
        return ""
    }

    int i = 0
    while i < n {
        string ch = text[i]
        if ch == "\n" || ch == "\r" {
            break
        }
        i = i + 1
    }

    string summary = text[0:i]
    summary
}

func build_completion(string prompt, string model) string {
    string summary = extract_summary(prompt)
    string completion = ""
    if summary == "" {
        completion = "已收到你的请求，当前由本地 S 语言后端直接回答。"
    } else {
        completion = "已收到你的请求：“" + summary + "”。我会直接给出简洁回答。"
    }

    string verbose = env_get("NEURX_BACKEND_VERBOSE_COMPLETION").unwrap_or("")
    if verbose == "1" || verbose == "true" || verbose == "on" {
        completion = completion + " model=" + model
        completion = completion + " prompt_len=" + string(len(prompt))
    }

    completion
}

func response_json(string model, string prompt, string completion) string {
    string out = "{"
    out = out + "\"backend_name\":\"neurx.app.backend.llm.s\""
    out = out + ",\"model_name\":\"" + json_escape(model) + "\""
    out = out + ",\"summary\":\"s-minimal-backend\""
    out = out + ",\"prompt\":\"" + json_escape(prompt) + "\""
    out = out + ",\"completion\":\"" + json_escape(completion) + "\""
    out = out + ",\"generated_tokens\":16"
    out = out + ",\"last_token\":0"
    out = out + ",\"train_loss\":0"
    out = out + ",\"validation_loss\":0"
    out = out + ",\"ready\":true"
    out = out + "}"
    out
}

func main() () {
    string model = env_get("NEURX_BACKEND_MODEL").unwrap_or("gpt_large")
    string prompt = read_prompt()
    string completion = build_completion(prompt, model)
    println(response_json(model, prompt, completion))
}
