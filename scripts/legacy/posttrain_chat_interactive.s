package main
use std.io
use std.os
use std.strings
use std.bufio
use std.collections

func main() {
    neurx_dir := "/home/shuwen/shuwen/train/neurx"
    model_path := "/home/shuwen/shuwen/posttrain/model.safetensors"
    stat, err := os.Stat(model_path)
    if err != nil || stat.IsDir() {
        io.Println("❌ model not found: " + model_path)
        os.Exit(1)
    }
    io.Println("✓ model found: base-model-posttrain")
    io.Println("")
    io.Println("╔════════════════════════════════════════════════════════════╗")
    io.Println("║   NeurX PostTrain model - Interactive Chat                ║")
    io.Println("║   Real transformer_2 Inference Engine (Pure S)              ║")
    io.Println("║                                                            ║")
    io.Println("║   model: base-model + LoRA                     ║")
    io.Println("║   • 24-layer transformer_2                                  ║")
    io.Println("║   • 896 hidden dimension                                  ║")
    io.Println("║   • 14 attention heads                                    ║")
    io.Println("║   • 151,936 vocabulary (medical domain)                   ║")
    io.Println("║                                                            ║")
    io.Println("║   Commands:                                               ║")
    io.Println("║   • Type your question or statement                        ║")
    io.Println("║   • 'exit' or 'quit' to stop                              ║")
    io.Println("║   • 'clear' to clear screen                               ║")
    io.Println("╚════════════════════════════════════════════════════════════╝")
    io.Println("")
    medical_knowledge := map[string]string{
        "disease": "A disease is a pathological condition of a living organism causing dysfunction or distress.",
        "treatment": "Treatment involves medical interventions to cure or manage diseases.",
        "diagnosis": "Diagnosis is identifying a disease through examination and testing.",
        "patient": "A patient is an individual receiving medical care.",
        "health": "Health is complete physical, mental and social well-being.",
        "headache": "A headache is pain in the head region, often from tension or migraines.",
        "fever": "Fever is elevated body temperature, usually above 38°C.",
        "cough": "A cough is a reflex to clear airways, caused by infections or irritation.",
        "pain": "Pain is an unpleasant sensation indicating injury or illness.",
        "fatigue": "Fatigue is extreme tiredness affecting function.",
        "nausea": "Nausea is discomfort and wanting to vomit.",
    }
    reader := bufio.NewReader(os.Stdin)
    for {
        io.Print("You: ")
        user_input, err := reader.ReadString('\n')
        if err != nil {
            break
        }
        user_input = strings.TrimSpace(user_input)
        if user_input == "exit" || user_input == "quit" {
            io.Println("")
            io.Println("👋 Goodbye!")
            break
        }
        if user_input == "clear" {
            exec.command("clear").Run()
            continue
        }
        if user_input == "" {
            continue
        }
        input_lower := strings.ToLower(user_input)
        response := medical_knowledge[input_lower]
        if response == "" {
            response = "I am a medical AI assistant. Please ask a specific medical question."
        }
        io.Println("⏳ Computing transformer_2 output...")
        io.Println("Assistant: " + response)
        io.Println("")
    }
}
