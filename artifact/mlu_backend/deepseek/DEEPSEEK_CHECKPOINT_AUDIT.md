# DeepSeek-V2-Lite checkpoint audit

Read-only snapshot of `/app/shuwen/model/DeepSeek-V2-Lite`. Hugging Face sidecar metadata for configuration, generation configuration, index and tokenizer files names revision `604d5664dddd88a0433dbae533b7fe9472482de0`. `git hash-object` reproduced the sidecar ETags for all five files. The indexed model payload is **31,412,968,448 bytes**.

None of the four finalized safetensors files existed at inspection. The `.incomplete` files were growing across observations. Partial apparent lengths below are a snapshot and can include unwritten regions. They do not establish downloaded payload coverage.

| Shard | Tensors | Partial bytes | Full bytes declared by safetensors header | Official SHA-256 |
| --- | ---: | ---: | ---: | --- |
| 01 | 1,329 | 73,400,320 | 8,594,887,408 | [`0d7e9f39bde40111a4c0f390b87497dce4565cf578d916395e6b2c7851f1e8da`](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/604d5664dddd88a0433dbae533b7fe9472482de0/model-00001-of-000004.safetensors) |
| 02 | 1,491 | 964,689,920 | 8,591,757,448 | [`e0656832b0d594b4a64cad40ff8465231de6ed44c854f74f6b217797660aa4bb`](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/604d5664dddd88a0433dbae533b7fe9472482de0/model-00002-of-000004.safetensors) |
| 03 | 1,491 | 1,226,833,920 | 8,590,718,520 | [`843ec689624f3a520526e040f0326c4dc9865e8172942ca98a084fe136fdb21a`](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/604d5664dddd88a0433dbae533b7fe9472482de0/model-00003-of-000004.safetensors) |
| 04 | 980 | 83,886,080 | 5,636,263,200 | [`cfb51658f67cedfbbc4d62ad14187830ceec8ee82c788c5f718feea98905ef31`](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/604d5664dddd88a0433dbae533b7fe9472482de0/model-00004-of-000004.safetensors) |

Each header was parsed without accessing tensor payloads. Its tensor names exactly matched the weight index. Every offset range was contiguous and matched two bytes per BF16 value across the recorded shape. The aggregate declared payload equaled the index. Full-shard SHA-256 remains pending. The sizes in the table come from the partial headers, while the published file pages display rounded sizes.

| Local file | Bytes | Local SHA-256 |
| --- | ---: | --- |
| `config.json` | 1,522 | `f346286b0f1c8b044252fd54cb4fa78b9fab6472a6e8bebb9edfe03d414ea03d` |
| `generation_config.json` | 181 | `63ec07f6cb36bd8359b44f671123518dd6fbf55007e0c74aa96c296a75def8b5` |
| `model.safetensors.index.json` | 479,924 | `d2cdb2f325f6682cf3ad1ad2526a9f979d857390b579380c0331d975136e0acf` |
| `tokenizer.json` | 4,607,451 | `41f3bf64213da8c012d8bd0871a58a1fdf70463e8f08f110ddbb1082f529f669` |
| `tokenizer_config.json` | 1,279 | `31181eaf79394ea26728d95ecb54fe7c8413e6f56085dbabc8b0818134380ec8` |

The local configuration specifies `DeepseekV2ForCausalLM`, BF16, 27 layers, hidden size 2,048, 16 attention heads, query/key content and rotary dimensions 128/64, value dimension 128, KV LoRA rank 512, 64 routed experts, two shared experts and six routed experts per token. These are model metadata, independent of runtime dtype support. [Pinned configuration](https://huggingface.co/deepseek-ai/DeepSeek-V2-Lite/blob/604d5664dddd88a0433dbae533b7fe9472482de0/config.json)

The audit did not start, stop or alter a downloader. No model files or proxy configuration were modified.
