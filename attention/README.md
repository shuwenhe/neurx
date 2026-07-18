# Attention

This directory contains the NeurX S attention implementations.

| File | Responsibility |
| --- | --- |
| `attention.s` | Transformer MHA, GQA, MQA, RoPE and Flash Attention entry points |
| `attention_implementation.s` | Standalone multi-head attention core |
| `attention_gradient.s` | Attention backward and gradient computation |
| `attention_mechanism.s` | Prefix-LM and specialized attention mechanisms |
| `attention_complete.s` | Tensor-based attention forward/backward implementation |
| `flash_attention_compute.s` | Portable tiled Flash Attention compute path |
| `flash_attention_v2.s` | Flash Attention 2 implementation |
| `flash_attention_v3.s` | Inference-oriented Flash Attention 3 implementation |
| `cuda_attention.s` | CUDA SDPA kernel definitions |
| `cuda_flash_attention.s` | CUDA Flash Attention kernel definitions |
| `ring_attention.s` | Distributed long-context Ring Attention |
| `mla.s` | Multi-head latent attention |
| `nda.s` | Channel-gated neural delta attention |
| `inference_paged_attention.s` | Inference paged-attention state |
| `serving_paged_attention.s` | Serving paged-attention state |

S packages use the `neurx.attention` namespace.
