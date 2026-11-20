# Model Asset Inventory

## Target

```text
/app/shuwen/model/DeepSeek-V2-Lite
```

## Repository

- Official repository: `deepseek-ai/DeepSeek-V2-Lite`
- Pinned revision: `604d5664dddd88a0433dbae533b7fe9472482de0`
- Repository SHA matched API metadata.

## Checkpoint status

**PARTIAL CHECKPOINT**

Complete top-level weight shards: 0 of 4
Complete weight data: unavailable
Official expected weight size: 31,413,626,576 bytes

## Asset availability

| Asset | Status |
|---|---|
| Four safetensors shards | NOT COMPLETE |
| `model.safetensors.index.json` | AVAILABLE |
| `config.json` | AVAILABLE |
| `generation_config.json` | AVAILABLE |
| `tokenizer.json` | AVAILABLE |
| `tokenizer_config.json` | AVAILABLE |
| `modeling_deepseek.py` | AVAILABLE |
| `configuration_deepseek.py` | AVAILABLE |
| `tokenization_deepseek_fast.py` | AVAILABLE |

The safetensors index identifies `model-00001-of-000004.safetensors` through `model-00004-of-000004.safetensors`.

## Weight shard metadata

| Shard | Expected size | Official SHA-256 | Top-level status |
|---|---:|---|---|
| shard 1 | 8,594,887,408 | `0d7e9f39bde40111a4c0f390b87497dce4565cf578d916395e6b2c7851f1e8da` | INCOMPLETE CACHE ONLY |
| shard 2 | 8,591,757,448 | `e0656832b0d594b4a64cad40ff8465231de6ed44c854f74f6b217797660aa4bb` | INCOMPLETE CACHE ONLY |
| shard 3 | 8,590,718,520 | `843ec689624f3a520526e040f0326c4dc9865e8172942ca98a084fe136fdb21a` | INCOMPLETE CACHE ONLY |
| shard 4 | 5,636,263,200 | `cfb51658f67cedfbbc4d62ad14187830ceec8ee82c788c5f718feea98905ef31` | INCOMPLETE CACHE ONLY |

## Configuration-derived availability

- Architecture: `DeepseekV2ForCausalLM`
- Model type: `deepseek_v2`
- Total hidden size: 2048
- Transformer layers: 27
- Attention heads: 16
- KV heads: 16
- Routed experts: 64
- Active routed experts per token: 6
- Shared experts: 2
- Default weight dtype: bfloat16
- Vocabulary size: 102400

## Remaining blocker

No complete checkpoint can be loaded until all four top-level safetensors shards are downloaded and SHA-256 verified.
