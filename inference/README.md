# NeurX Inference

This directory contains the current inference entry points and compatibility layers for NeurX.

## Quick Start

Ask a question with the LLM inference launcher:

```bash
cd /Users/feifei/shuwen/neurx
NEURX_INFER_CHECKPOINT_PATH=artifacts/checkpoints/llm_training \
NEURX_INFER_QUESTION="人工智能是什么？请直接回答。" \
bash run_inference_llm.sh
```

Interactive chat mode:

```bash
cd /Users/feifei/shuwen/neurx
NEURX_INFER_CHECKPOINT_PATH=artifacts/checkpoints/llm_training \
bash run_interactive_inference.sh
```

## Environment Variables

- `NEURX_INFER_CHECKPOINT_PATH`: checkpoint directory or model file
- `NEURX_INFER_CHECKPOINT`: alias of the checkpoint path
- `NEURX_INFER_QUESTION`: question or prompt to answer
- `NEURX_INFER_PROMPT`: alias of the question/prompt input
- `NEURX_INFERENCE_INPUT`: legacy alias accepted by the launcher
- `NEURX_INFER_ANSWER_MODE`: `qa` for direct answers, `chat` for multi-turn chat
- `NEURX_INFER_FALLBACK_PROMPT`: fallback prompt used when no question is provided
- `NEURX_INFER_MAX_NEW_CHARS`: maximum number of generated characters
- `NEURX_INFER_DEVICE`: runtime device, for example `cpu`
- `NEURX_INFER_SEED`: seed for generation

Example:

```bash
NEURX_INFER_CHECKPOINT_PATH=artifacts/checkpoints/llm_training \
NEURX_INFER_QUESTION="NeurX 可以做什么？" \
bash run_inference_llm.sh
```

## Notes

- The production inference entry point is [`production_inference.s`](./production_inference.s).
- The launcher now prefers question-answer style prompting by default.
- Interactive mode keeps a chat-style prompt template.
