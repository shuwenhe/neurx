# NeurX Compatibility Analysis

No NeurX runtime code was modified.

## Weight-loading requirements

A future loader must support:

- Safetensors index-driven shard selection
- 4 official weight shards
- BF16 tensor decoding
- DeepSeek naming and custom `modeling_deepseek.py` weight names
- Dense and MoE expert tensors
- MLA projection tensors
- Shared expert tensors
- Vocabulary size 102400
- 27 transformer layers

The existing index lists each tensor in shard 1 through shard 4. The loader must verify tensor names, dtype, and shard offsets before device allocation.

## MLA requirements

Required operations:

1. `q_proj` or the `q_a_proj -> RMSNorm -> q_b_proj` branch
2. KV compression via `kv_a_proj_with_mqa`
3. KV RMSNorm
4. KV expansion via `kv_b_proj`
5. Split of no-position and RoPE dimensions
6. YaRN RoPE application
7. MHA-style attention over reconstructed heads
8. Compressed or decomposed KV-cache layout

MLA cache dimensions must be derived from:

- KV LoRA rank: 512
- RoPE head dimension: 64
- V head dimension: 128
- Number of heads: 16

## MoE requirements

The MLU backend must support:

- Token-level routing logits
- Greedy/top-k expert selection
- 6 active routed experts
- 64 routed expert GEMMs
- 2 shared expert GEMMs
- Expert dispatch and combine
- Efficient routing metadata
- Expert parallelism or local-expert sharding
- Per-expert activation quantization only if explicitly validated

Dense layers before the MoE stage require standard BF16 linear and RMSNorm kernels.

## BF16/FP16 support

The official config declares BF16 weights. Native NeurX support requires:

- BF16 safetensors conversion or BF16 load
- BF16 GEMM
- BF16 RMSNorm
- BF16 YaRN RoPE
- BF16 routing score handling
- Numerical tolerances by kernel type

FP16 is not declared by `config.json` and must not be substituted automatically.

## KV cache layout

Recommended implementation sequence:

1. Represent compressed KV state rather than assuming full MHA KV.
2. Cache the 512-dimensional KV LoRA state.
3. Cache 64-dimensional per-token RoPE key component.
4. On attention, expand KV with `kv_b_proj`.
5. Paged/block cache support should include both state components.
6. Verify cache updates against PyTorch reference values before MLU optimization.

## MLU590 optimization opportunities

After CNRT and CNNL are available:

- CNNL GEMM for dense and expert projections
- CNNL RMSNorm or NeurX lowering
- custom BF16/FP16-aware MLA projections
- fused KV compression and cache expansion
- fused YaRN RoPE
- expert routing and grouped GEMM
- paged KV-cache kernels
- CNCL tensor and expert parallel collectives
- NUMA-aware host pinning
- eight-card tensor/expert parallel placement

## Remaining blockers

- Complete official weight checkpoint
- Host-visible CNRT
- Host-visible CNNL
- Host-visible CNCL
- Verified CNRT kernel launch
- BF16 numerical kernels
- Custom DeepSeek weight loader
- MLA and MoE operator lowering
- MLU multi-card collectives

No claim of MLU inference readiness is made.
