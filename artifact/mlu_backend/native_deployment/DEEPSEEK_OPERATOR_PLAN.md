# DeepSeek operator plan

Operator development is gated on an actual Vector Add pass. The target is the official DeepSeek-V2-Lite checkpoint. Only the published model metadata was reviewed. Model weights were not downloaded. [Official model](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite) · [Configuration](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/main/config.json)

1. Build and validate CNNL GEMM first. Add custom GEMM only for measured coverage gaps. Verify independent FP16 and BF16 paths with real MLU kernels and a CPU FP32 accumulation reference.
2. Validate RMSNorm, RoPE, softmax and attention on small deterministic fixtures. Cover causal masking, stride/layout and variable sequence lengths. Record tolerances by operator and dtype.
3. Validate MLA projections and attention against the base reference. Verify KV cache prefill writes, decode reads and position handling by comparing cached decode with recomputation.
4. Validate MoE routing and top-k behavior, expert GEMM and token dispatch/combine with deterministic fixtures. Cover empty experts, repeat tokens and stable tie handling.
5. After the required operators pass, pin the model revision and tokenizer. Implement sharded weight loading, dtype/layout checks, prefill and incremental decode in NeurX S. Compare intermediate activations, logits and generated token IDs against a pinned trusted reference.
6. After successful single-card inference, test CNCL all-reduce, all-gather, reduce-scatter and broadcast against CPU reductions. Then investigate TP4, TP8 and eight-card EP with an allocated topology. Record NUMA locality, PCIe and MLU-Link placement and per-rank correctness before optimizing.

Repository candidates include `src/inference/extension/attention/mla.s`, `src/model/extensions/moe/`, and `src/runtime/distributed/moe_all_to_all.s`. Their presence does not establish an MLU implementation. Device buffers, vendor operations, collective support and dtype acceptance require independent hardware evidence.
