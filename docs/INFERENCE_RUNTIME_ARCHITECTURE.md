# NeurX English textmodelinferenceframework

English textframeworkEnglish textrequestEnglish text **Prefill** English text **Decode** phase.English textgenerateEnglish textbatch, CUDA English text Ascend requestEnglish text kernel launch; English textbatchEnglish text CUDA/cuBLAS/FlashAttention/NCCL English text CANN/ACL/FlashAttention/HCCL.

```
HTTP/gRPC request
       │
admission + prefix/KV cache
       │
DisaggregatedScheduler
   ┌───┴────────────┐
Prefill lane      Decode lane (priority)
large-token batch  continuous 1-token batch
   │                    │
CUDA / Ascend adapters ─ KV block handoff ─ sampler/stream
```

## English text

- **English textoptimize**: RMSNorm + QKV English text, Flash/Paged Attention, RoPE English text, logits + sampling English text; CUDA English text FP8(supportEnglish text), Ascend use BF16.
- **English textoptimize**: English text NCCL(CUDA)English text HCCL(Ascend)all-reduce English textdefault; Prefill English text Decode English text, English text KV block English text P2P English text RDMA English text, English text prompt.
- **English textoptimize**: Decode English text TTFT English text token English text; Prefill English text token budget English text, English textrequest; batch key English text `(backend, dtype)`, English text graph capture English text kernel English text.
- **English textinference**: English text replica English text; English text KV-cache English text, English text token English text, English text replica.English textrequestEnglish textdataEnglish text KV block, English textmodelweight.

## English text

`inference/runtime/inference_runtime.h` English text, English text CUDA/Ascend English text, English text, English text, Prefill English text Decode English text.run:

```bash
make inference-runtime-test
```

English textbatchEnglish text `complete_prefill()` English text `complete_decode()`; English textstateEnglish text, English textrequestEnglish text.

## English text

CUDA English text `cuda/transformer_kernels.cuh` English text NCCL; Ascend English text ACL/CANN graph, FlashAttention English text HCCL implementationEnglish textbatchEnglish text.truthfulEnglish text, KV pool English text RPC/HTTP transport English text, English textrunEnglish textimplementationEnglish text.

English textdirectory: CUDA kernel English text `cuda/` English text `inference/runtime/backends/`, Ascend English text, kernel, English text, ACL runtime English text HCCL English text `cann/`, NCCL English text `distributed/nccl/`.
