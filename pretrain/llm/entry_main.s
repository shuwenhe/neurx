package neurx.pretrain.llm.entry

use neurx.pretrain.llm.gpt_large_pretrain.main as gpt_large_pretrain_main

// Thin entry wrapper that exposes a top-level `main` for the runtime.
func main() int {
    // Delegate to the real large pretrain entrypoint.
    return gpt_large_pretrain_main()
}
