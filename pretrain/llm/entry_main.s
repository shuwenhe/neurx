package neurx.pretrain.llm.entry

// Thin entry wrapper that exposes a top-level `main` for the runtime.
func main() int {
    // Delegate to the MoE framework entrypoint defined in the IR (moe1t.main)
    return moe1t.main()
}
