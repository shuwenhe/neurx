# Native inference architecture

Status: **NOT DONE** until the official Stage4 installation and complete real-checkpoint acceptance run are recorded. Diagnostic compiler tests prove individual paths, not final acceptance.

`tool/build_native.py` resolves the source closure of `cmd/serve/main.s`, compiles a canonical S unit, emits machine code, and records its compiler identity. The Hugging Face execution path uses `native_executor.s`, `hf_transformer.s`, `safetensors_embedding.s`, `hf_bpe_tokenizer.s`, and `transformer_decode.s`. The reference-model and embedding-only paths exist for historical tests; their output cannot count as Qwen inference.

Model loading parses configuration and safetensors metadata, decodes BF16/F16/F32 into native f64 arrays, validates layer dimensions, and assembles twelve grouped layer fields using opaque construction handles. The embedding descriptor remains a file-backed lookup; the complete tied embedding matrix is loaded as the LM head. The final acceptance run must verify all matrix elements accessed and all 24 layers executed.

A forward step performs embedding lookup, learned RMSNorm, Q/K/V matrix-vector multiplication and biases, split-half RoPE, grouped-query causal attention with KV cache, softmax, output projection, residual, post-attention norm, SiLU gated MLP, and residual. Final normalization and the complete vocabulary projection determine greedy argmax. Cache arrays are returned explicitly because ordinary S arrays have value semantics.

Construction buffers are mutable only before publication. All published array updates and slices remain pure copies. See [tensor memory](TENSOR_MEMORY.md) and [the implementation plan](superpowers/plans/2026-11-10-native-construction.md).

Acceptance prompt: `Explain how a compiler performs semantic analysis.` Traces must distinguish loading, every forward/layer, logits and generated token IDs. Numerical verification is independent and cannot supply native output. The official compiler source, bootstrap stages and installed distribution live under `artifact/local-inference/`; the external S checkout is not modified by this mission.
