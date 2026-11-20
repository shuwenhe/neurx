# Model Config Analysis

Source: `/app/shuwen/model/DeepSeek-V2-Lite/config.json`

## Architecture

- Architecture: `DeepseekV2ForCausalLM`
- Model type: `deepseek_v2`
- Custom model implementation: `modeling_deepseek.py`
- Custom config implementation: `configuration_deepseek.py`
- Transformers requires version: `4.33.1`
- Custom model mapping is declared through `auto_map`

## Core dimensions

| Property | Value |
|---|---:|
| Hidden size | 2048 |
| Transformer layers | 27 |
| Attention heads | 16 |
| KV heads | 16 |
| Intermediate size | 10944 |
| MoE intermediate size | 1408 |
| Vocabulary size | 102400 |
| Maximum positions | 163840 |
| RMSNorm epsilon | 0.000001 |

## Attention and MLA

DeepSeek-V2 MLA fields:

| Field | Value |
|---|---:|
| Query LoRA rank | `null`, so direct query projection is used |
| KV LoRA rank | 512 |
| Q/K nope head dimension | 128 |
| Q/K rope head dimension | 64 |
| V head dimension | 128 |
| Attention bias | false |
| Attention dropout | 0.0 |
| Query head dimension | 192 |

The downloaded `modeling_deepseek.py` confirms MLA-style projections:

- `kv_a_proj_with_mqa`
- `kv_a_layernorm`
- `kv_b_proj`
- separate no-position and RoPE key/value components

The KV cache implementation requires both compressed KV state and per-head reconstructed KV dimensions. It must not be implemented as a generic full-size MHA cache without first measuring memory/layout tradeoffs.

## MoE

| Field | Value |
|---|---:|
| Routed experts | 64 |
| Active experts per token | 6 |
| Shared experts | 2 |
| First dense replacement layer | 1 |
| MoE layer frequency | 1 |
| Expert groups | 1 |
| Top-k group | 1 |
| Routing method | greedy |
| Scoring function | softmax |
| Routed scaling factor | 1.0 |

Dense MLPs are used before MoE starts. Starting at layer index 1, configured MoE layers contain 64 routed experts plus 2 shared experts.

## Positional encoding

RoPE configuration:

- Base: 10000
- Scaling type: Yarn
- Scaling factor: 40
- Original maximum positions: 4096
- YaRN beta fast: 32
- YaRN beta slow: 1
- YaRN mscale: 0.707
- YaRN mscale-all-dim: 0.707

## Dtype and cache

- Config dtype: `bfloat16`
- `use_cache`: true
- Tied word embeddings: false
- Hidden activation: SiLU

## Configuration verification

`config.json` and `model.safetensors.index.json` are complete JSON files and were inspected locally. This confirms configuration availability, not checkpoint integrity.
