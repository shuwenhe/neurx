package main

use neurx.pretrain.llm.gpt_large_pretrain.gpt_large_pretrain_launch as gpt_large_pretrain_launch

// Top-level runner package that exposes an unqualified `main` symbol
// so the runtime can locate the entrypoint. Delegates to the real pretrain entry.
func main() int {
    return gpt_large_pretrain_launch()
}
