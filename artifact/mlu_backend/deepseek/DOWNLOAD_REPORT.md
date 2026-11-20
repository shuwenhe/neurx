# Download Report

Audit date: 2026-11-20

## Final status

| Acceptance item | Status |
|---|---|
| PRECHECK_PASSED | CONFIRMED |
| DOWNLOAD_COMPLETED | NOT COMPLETED |
| INTEGRITY_VERIFIED | NOT COMPLETED |
| CONFIG_VERIFIED | CONFIRMED |
| NEURX_COMPATIBILITY_ANALYZED | CONFIRMED |

The complete official checkpoint was not downloaded. The run stopped because Hugging Face LFS/Xet CDN reads repeatedly timed out or disconnected. No weight shard moved to the top-level directory as a complete file.

## Precheck

```text
target=/app/shuwen/model/DeepSeek-V2-Lite
/app/shuwen/model exists, owned by gaozhi:gaozhi, mode 2775
target did not exist before download
/app/shuwen/model writable: exit=0
/app/shuwen writable: exit=0
disk /app/shuwen: 439G total, 261G used, 155G available
active Hugging Face download processes before start: none
hf: NOT_FOUND
huggingface-cli: NOT_FOUND
```

## Isolated download tooling

No system package was modified. `huggingface_hub` was installed under:

```text
/app/shuwen/.hf-tool
```

Commands and exits:

```bash
python3 -m pip install --disable-pip-version-check --target /app/shuwen/.hf-tool 'huggingface_hub==0.25.2'
exit=0

PYTHONPATH=/app/shuwen/.hf-tool python3 - <<'PY'
import huggingface_hub
print(huggingface_hub.__version__)
PY
exit=0
output=huggingface_hub=0.25.2
```

The standard virtual environment could not be bootstrapped because Python 3.8 lacked `ensurepip`; no system Python packages were changed.

## Proxy verification

The download used only process environment variables:

```text
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
ALL_PROXY=socks5h://127.0.0.1:7891
```

Pre-download API verification returned HTTP 200 and pinned revision SHA:

```text
604d5664dddd88a0433dbae533b7fe9472482de0
```

## Download command

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5h://127.0.0.1:7891
export PYTHONPATH=/app/shuwen/.hf-tool

python3 -m huggingface_hub.commands.huggingface_cli download \
  deepseek-ai/DeepSeek-V2-Lite \
  --revision 604d5664dddd88a0433dbae533b7fe9472482de0 \
  --local-dir /app/shuwen/model/DeepSeek-V2-Lite \
  --resume-download \
  --max-workers 1
```

The download was attempted twice with four concurrent workers and once with a single worker.

The first attempt exit was 1 due to `ChunkedEncodingError: IncompleteRead` on shard 2.

The single-worker API retry exit was 1 due to a remote proxy disconnect before snapshot metadata download.

The final single-worker retry was stopped after 14 minutes because shard 1 remained at the same size and no progress was observed.

## Repository asset metadata

Pinned repository size:

| File | Official metadata size |
|---|---:|
| `model-00001-of-000004.safetensors` | 8,594,887,408 bytes |
| `model-00002-of-000004.safetensors` | 8,591,757,448 bytes |
| `model-00003-of-000004.safetensors` | 8,590,718,520 bytes |
| `model-00004-of-000004.safetensors` | 5,636,263,200 bytes |
| **Expected weight total** | **31,413,626,576 bytes** |

Official repository SHA-256 values reported through Hugging Face metadata:

| Shard | Repository SHA-256 |
|---|---|
| shard 1 | `0d7e9f39bde40111a4c0f390b87497dce4565cf578d916395e6b2c7851f1e8da` |
| shard 2 | `e0656832b0d594b4a64cad40ff8465231de6ed44c854f74f6b217797660aa4bb` |
| shard 3 | `843ec689624f3a520526e040f0326c4dc9865e8172942ca98a084fe136fdb21a` |
| shard 4 | `cfb51658f67cedfbbc4d62ad14187830ceec8ee82c788c5f718feea98905ef31` |

## Current files

Top-level configuration and source assets are present:

```text
config.json                 1522 bytes
configuration_deepseek.py   10338 bytes
generation_config.json       181 bytes
.gitattributes               1519 bytes
LICENSE                     13759 bytes
modeling_deepseek.py        78672 bytes
model.safetensors.index.json 479924 bytes
README.md                   15498 bytes
tokenization_deepseek_fast.py 1368 bytes
tokenizer_config.json        1279 bytes
tokenizer.json             4607451 bytes
```

Incomplete safetensors cache files remain:

```text
model-00001-of-000004.safetensors...incomplete 377487360 bytes
model-00002-of-000004.safetensors...incomplete 3061841920 bytes
model-00003-of-000004.safetensors...incomplete 3124756480 bytes
model-00004-of-000004.safetensors...incomplete 272629760 bytes
```

No top-level `.safetensors` weight shard exists, so file-hash and integrity verification cannot pass.

## Integrity status

NOT VERIFIED:

- Four top-level weight shards are missing.
- Partial `.incomplete` files do not match official metadata sizes.
- No downloaded weight file passed SHA-256 verification.
- The safetensors index exists and names all four official shards.
- No incomplete file was deleted or moved out of the Hugging Face cache.
