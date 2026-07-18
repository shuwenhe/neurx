# NeurX Inference

This directory contains the current inference entry points and compatibility layers for NeurX.

## Quick Start

Build and run the native NXTRFMV2 CPU reference backend:

```bash
make build-cpu-inference
NEURX_INFER_CHECKPOINT_PATH=checkpoint/NeurX-1.3/transformer_v2.ckpt \
NEURX_INFER_PROMPT="NeurX can" \
make infer
```

Interactive chat mode:

```bash
artifacts/build/cpu_inference/neurx_cpu_inference \
  --checkpoint checkpoint/NeurX-1.3/transformer_v2.ckpt \
  --vocab data/corpus/vocab.json \
  --merges data/corpus/merges.txt \
  --interactive
```

## Environment Variables

- `NEURX_INFER_CHECKPOINT_PATH`: checkpoint directory or model file
- `NEURX_INFER_CHECKPOINT`: alias of the checkpoint path
- `NEURX_INFER_QUESTION`: question or prompt to answer
- `NEURX_INFER_PROMPT`: alias of the question/prompt input
- `NEURX_INFERENCE_INPUT`: legacy alias accepted by the launcher
- `NEURX_INFER_ANSWER_MODE`: `qa` for direct answers, `chat` for multi-turn chat
- `NEURX_INFER_FALLBACK_PROMPT`: fallback prompt used when no question is provided
- `NEURX_INFER_MAX_NEW_TOKENS`: maximum number of generated tokens
- `NEURX_INFER_TEMPERATURE`, `NEURX_INFER_TOP_K`, `NEURX_INFER_TOP_P`
- `NEURX_INFER_REPETITION_PENALTY`: sampling controls
- `NEURX_INFER_DEVICE`: runtime device, for example `cpu`
- `NEURX_INFER_SEED`: seed for generation

Example:

```bash
NEURX_INFER_CHECKPOINT_PATH=artifacts/checkpoints/llm_training \
NEURX_INFER_QUESTION="NeurX 可以做什么？" \
bash run_inference_llm.sh
```

## Notes

- `make infer` uses the native CPU reference backend and fails explicitly when
  the checkpoint or tokenizer is missing or incompatible.
- The CPU backend reads the same NXTRFMV2 checkpoint and BPE tokenizer ABI as
  CUDA and Ascend. It is intended for correctness and fallback use; CUDA/CANN
  should be used for production throughput.
- Run `make cpu-inference-test` for a deterministic end-to-end checkpoint,
  forward-pass, and generation test.
