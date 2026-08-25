package interactive_chat
use neurx.runtime.io.{runtime_run_command_output}

func main() {
    print("\n╔═══════════════════════════════════════════════╗\n")
    print("║  NeurX Interactive model Chat (Pure S)       ║\n")
    print("║  Type questions, get medical responses       ║\n")
    print("╚═══════════════════════════════════════════════╝\n\n")
    for true {
        print("You: ")
        string cmd = "read -t 5 line && echo \"$line\" || echo \"\""
        string input = runtime_run_command_output(cmd)
        if input == "exit" || input == "quit" {
            print("Goodbye!\n")
            return
        }
        if len(input) == 0 {
            continue
        }
        print("Assistant: Medical response to: " + input + "\n\n")
    }
}
