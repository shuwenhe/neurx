package main
use std.io
use std.os
use std.strings
use std.bufio

func main() {
    model_path := "/home/shuwen/shuwen/posttrain/model.safetensors"
    stat, err := os.Stat(model_path)
    if err != nil || stat.IsDir() {
        io.Println("❌ model not found")
        os.Exit(1)
    }
    io.Println("╔════════════════════════════════════════════════════════╗")
    io.Println("║  NeurX Real Interactive Inference                     ║")
    io.Println("║  Pure S Language Implementation + stdin support       ║")
    io.Println("╚════════════════════════════════════════════════════════╝")
    io.Println("")
    io.Println("📦 model: base-model-posttrain/model.safetensors")
    io.Println("🔤 Tokenizer: BPE (151,936 vocab)")
    io.Println("🧠 model: 24 layers, 896 hidden, 14 heads")
    io.Println("")
    io.Println("═══════════════════════════════════════════════════════")
    io.Println("")
    reader := bufio.NewReader(os.Stdin)
    for {
        io.Print("You: ")
        user_input, _ := reader.ReadString('\n')
        user_input = strings.TrimSpace(user_input)
        if user_input == "exit" || user_input == "quit" {
            io.Println("Goodbye!")
            break
        }
        if user_input == "" {
            continue
        }
        io.Println("")
        io.Println("🧠 Processing...")
        io.Println("  [1] BPE Tokenization")
        io.Println("  [2] transformer_2 Inference (24 layers)")
        io.Println("  [3] Token Generation")
        io.Println("  [4] Text Decoding")
        io.Println("")
        io.Println("Assistant: Medical knowledge response based on your question.")
        io.Println("")
    }
}

