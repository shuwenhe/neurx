package neurx.pretrain.llm.entry

use neurx.pretrain.llm.gpt_large_pretrain.gpt_large_pretrain_launch as gpt_large_pretrain_launch

// Thin entry wrapper that exposes a top-level `main` for the runtime.
func main() int {
    // Delegate to the real large pretrain entrypoint.
    return gpt_large_pretrain_launch()
}
