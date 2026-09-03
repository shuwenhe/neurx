package neurx.serving.simple_chat

use std.syscall
use std.io

struct model_info {
    string id
    string name
    string path
}

struct app_state {
    string current_model
    model_info[] models
}

func create_app() app_state {
    models := make(model_info[], 2)
    models[0] = model_info{
        id: "qwen-0.5b",
        name: "Qwen2.5-0.5B-Instruct",
        path: "/model/Qwen2.5-0.5B-Instruct",
    }
    models[1] = model_info{
        id: "qwen-vl-7b",
        name: "Qwen2.5-VL-7B",
        path: "/model/Qwen2.5-VL-7B",
    }
    
    return app_state{
        current_model: "qwen-0.5b",
        models: models,
    }
}

func (app: &app_state) get_models_json() string {
    json := "{"
    json = json + "\"models\":["
    
    for i := 0; i < len(app.models); i = i + 1 {
        if i > 0 {
            json = json + ","
        }
        model := app.models[i]
        json = json + "{\"id\":\"" + model.id + "\",\"name\":\"" + model.name + "\"}"
    }
    
    json = json + "],"
    json = json + "\"current_model\":\"" + app.current_model + "\""
    json = json + "}"
    return json
}

func (app: &app_state) handle_chat(model_id: string, user_message: string) string {
    if len(model_id) > 0 {
        app.current_model = model_id
    }
    
    model_name := ""
    for i := 0; i < len(app.models); i = i + 1 {
        if app.models[i].id == app.current_model {
            model_name = app.models[i].name
            break
        }
    }
    
    response_content := "这是来自 " + model_name + " 的回复。"
    response_content = response_content + "\n\n用户输入: " + user_message
    response_content = response_content + "\n\n(模拟响应，使用真实模型时会返回 AI 生成的内容)"
    
    response := "{"
    response = response + "\"id\":\"chatcmpl-1234567890\","
    response = response + "\"object\":\"chat.completion\","
    response = response + "\"model\":\"" + app.current_model + "\","
    response = response + "\"choices\":[{"
    response = response + "\"index\":0,"
    response = response + "\"message\":{"
    response = response + "\"role\":\"assistant\","
    response = response + "\"content\":\"" + response_content + "\""
    response = response + "},"
    response = response + "\"finish_reason\":\"stop\""
    response = response + "}],"
    response = response + "\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":20,\"total_tokens\":30}"
    response = response + "}"
    
    return response
}

func (app: &app_state) set_model(model_id: string) bool {
    for i := 0; i < len(app.models); i = i + 1 {
        if app.models[i].id == model_id {
            app.current_model = model_id
            return true
        }
    }
    return false
}

func main() {
    app := create_app()
    
    println("✅ NeurX Web Chat Server initialized")
    println("📦 Available models:")
    for i := 0; i < len(app.models); i = i + 1 {
        println("   - " + app.models[i].id + ": " + app.models[i].name + " at " + app.models[i].path)
    }
    println("")
    println("🚀 Current model: " + app.current_model)
    println("")
    println("📖 Usage:")
    println("   This S program defines the chat server backend.")
    println("   Frontend: http:
    println("   Models can be selected from the UI.")
}
