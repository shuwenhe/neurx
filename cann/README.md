# NeurX CANN / Ascend

English textdirectoryEnglish textsave NeurX English text CANN/NPU English text, configurationEnglish text.

## Layout

- `env.s`: output Ascend CANN runEnglish text.
- `configs/ascend_910b_train.json`: 910B trainingEnglish textexample, defaultEnglish text `S` trainingEnglish text.
- `configs/ascend_310p3_train.json`: 310P3 inferenceEnglish textexample, defaultEnglish text `S` English text.
- `kernels/`: Ascend C / TBE English textinferenceEnglish text.
- `operators/`: ACLNN / Graph Engine English text.
- `runtime/`: ACL English text, stream, English textrunEnglish textload.
- `model/`: NXTRFMV2 checkpoint English text, FP16 English textweightload.
- `cache/`: English text KV Cache English textrequest block table.
- `hccl/`: English textrunEnglish textload.
- `inference/`: CANN inferenceEnglish text.
- `deploy/`: English text.
- `scripts/`: English textrunEnglish text.

## Notes

`Ascend 310/310P/310P3` English textinferenceEnglish text, English textcompletetrainingEnglish text.English text:

- `910/910B`: English texttraining.
- `310P3`: English textinferenceEnglish text.

## Quick Start

```bash
cd /app/neurx
ASCEND_HOME_PATH=/usr/local/Ascend/ascend-toolkit/latest \
ASCEND_RT_VISIBLE_DEVICES=0 \
make pretrain-npu
```

trainingEnglish textrunEnglish text, English text
`ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`.English text Linux, CANN
Runtime, `npu-smi`, English text HCCL, English text `cann`/`hccl` English textconfiguration
startEnglish text S English texttrainingEnglish text.

English text CANN trainingEnglish text, S English texttrainingEnglish textuseEnglish text kernel; English text
CPU fallback English text NPU English text.

## 310P3 inference

310P3 English text 8 English text, English text token English textpathuse HCCL.English text worker
English text ACL context, modelweightEnglish text KV Cache.

```bash
cmake -S cann -B artifacts/build/cann
cmake --build artifacts/build/cann
```

310P3 ATB English textpluginimplementationEnglish text `operators/atb_310p_plugin.cpp`, compileEnglish textgenerate
`libneurx_cann_operators.so`:

```bash
source "${ASCEND_HOME_PATH}/set_env.sh"
source "${ATB_HOME_PATH}/set_env.sh"
cmake -S cann -B artifacts/build/cann-310p \
  -DNEURX_ENABLE_ATB_310P=ON
cmake --build artifacts/build/cann-310p
```

pluginimplementation `operators/operator_abi.h` English text ABI v2 prefill/decode English text, English text
Gather, RMSNorm, Linear, RoPE, ReshapeAndCache, PagedAttention, English text,
SwiGLU English text LM Head.KV Cache use 310P
`FRACTAL_NZ` English text.

English text `scripts/launch_8card_310p3_inference.sh`.English text
`NEURX_ASCEND_WORKER_BIN`, `NEURX_CHECKPOINT` English text
`NEURX_CANN_OPERATOR_LIBRARY`.

`inference/ascend_worker.{h,cpp}` English text worker English text CANN dataEnglish text: English text
pinned host/device token English text logits English text, English text Prefill/Decode, English text FP16
logits English text host FP32, English textsupport temperature, top-k, top-p English text repetition
penalty English text.HTTP/OpenAI English text, tokenizer English textrequestEnglish text serving English text
English text.

ATB pluginsupport NPU device-side sampling: English text temperature English text `0`(greedy)
English text `1` English text repetition penalty English textrequestEnglish text FP16 Softmax English text
TopkToppSampling, English text host English textrequestEnglish text INT32 token ID.English text
English textuse CPU reference sampler, English text.ATB English text batch
English text 512.

`cache/prefix_cache.{h,cpp}` cachecomplete, English text prompt KV blocks.English textrequest
English text Prefill English text block-aligned token prefix, English text
English text KV blocks; English textcache token English textgenerateEnglish textrequestEnglish text logits.
cacheuse LRU English text, defaultEnglish text 256 English text 128 English text retained blocks.Worker
English text batch English text KV English textcache, English text retained blocks English textrequest.English text
KV block English text, English text Decode English textrequestEnglish textuseEnglish textcache.
English text `NEURX_ASCEND_PREFIX_CACHE_ENTRIES` English text
`NEURX_ASCEND_PREFIX_CACHE_BLOCKS` English text, English text `0` English text.English text,
query, English text retained block countEnglish text `/metrics` English text.

ATB pluginEnglish text shape-keyed LRU GraphOperation cache:
`Add+RMSNorm` English text `Swish+Multiply(SwiGLU)` English text, English text
English text rows/columns shape English text workspace.FP16 attention English text
English text `RMSNorm+Q/K/V Linear+RoPE` English text GraphOperation; INT8 weight
English textuse ACLNN W8A16 path, English text 310P3 English text.cacheEnglish text 32 English text,
English textstepEnglish text stream.310P3 English text capture.

modelloadEnglish textsupport `NEURX_ASCEND_PRECISION=int8` English text W8A16 weight-only
inference.Embedding English text RMSNorm weightEnglish text FP16; Q/K/V/O, FFN English text LM Head
English textoutputEnglish text INT8, English textsave FP16 antiquant scale.310P3 plugin
use `aclnnWeightQuantBatchMatmulV2` output FP16 activation; English text `fp16`
English text ATB Linear path.

CMake English textgenerate `neurx_ascend_worker`.English text `/health/live`,
`/health/ready`, `/metrics`, `/admin/drain` English text
`POST /v1/token-completions`.inferenceEnglish text `input_ids`,
`max_new_tokens`, English textparameterEnglish text `stop_token_ids`, English textgenerateEnglish text token IDs.
`POST /v1/batch-token-completions` English text `input_ids`, English text prompt
English text Prefill, English textrequestEnglish text Decode batch;
English text token English textrequestEnglish text KV Cache.defaultEnglish text 64 English text, English text
`NEURX_ASCEND_HTTP_MAX_BATCH` English text, English text 2000.
English text:

```bash
export NEURX_ASCEND_WORKER_BIN=/app/neurx/bin/neurx_ascend_worker
```

English textimplementationEnglish text FP16 activation(weightEnglish text FP16 English text per-channel INT8),
head size English text16English text256, KV block size English text16English text
English text128.Prefill supportEnglish text: English text query token useEnglish text block-table
English text context length, English text KV Cache English text.English text
English text 310P3+CANN/ATB English text CPU/CUDA golden alignment.

## 310P3 FP16 / INT8 alignment

truthfulEnglish textstart FP16 English text INT8 worker, English text 16 English text.
English text logits English textdefaultEnglish text, testEnglish text
`NEURX_ASCEND_ENABLE_BENCHMARK_API=1`.English text worker English text:

```bash
python3 cann/scripts/benchmark_8card_310p3.py collect \
  --precision fp16 --output /tmp/neurx-fp16.json

# English text NEURX_ASCEND_PRECISION=int8 English text worker English text
python3 cann/scripts/benchmark_8card_310p3.py collect \
  --precision int8 --output /tmp/neurx-int8.json

python3 cann/scripts/benchmark_8card_310p3.py compare \
  --fp16 /tmp/neurx-fp16.json --int8 /tmp/neurx-int8.json
```

English text worker English text readiness, English text prompt English text top-k logits, English text greedy
generateEnglish text p50/p95 requestEnglish text, defaultEnglish textrequestEnglish text 8 English text, English text
`--batch-size` English text.English textphaseEnglish text top-1 English text, top-k English text,
English text token English text logit English text INT8/FP16 English text; English text.
English text `--prompts` English text tokenizer generateEnglish text token ID English text.
