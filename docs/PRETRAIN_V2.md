# CUDA pretraining v2

`make pretrain-gpu` now builds `cuda/neurx_transformer_train_v2.cu`. The trainer
streams JSONL records and extracts the first non-empty string field in this
order: `text`, `content`, `xml`. This keeps the current Wikipedia shards
(which use `xml`) usable while preferring the standard `text` field.

## Configuration

```bash
NEURX_TOKENIZER_VOCAB=/path/to/vocab.json \
NEURX_TOKENIZER_MERGES=/path/to/merges.txt \
NEURX_TRANSFORMER_DIM=256 \
NEURX_TRANSFORMER_HEADS=8 \
NEURX_TRANSFORMER_FFN=768 \
NEURX_TRANSFORMER_NUM_LAYERS=4 \
NEURX_PRETRAIN_MICRO_BATCH=4 \
NEURX_GRADIENT_ACCUMULATION_STEPS=8 \
make pretrain-gpu
```

If the two tokenizer paths are omitted, byte-level tokenization with a
256-token vocabulary is used. The BPE loader accepts the conventional flat
`vocab.json` token-to-id object and a `merges.txt` file containing ranked
space-separated token pairs. The checkpoint records a hash and paths for both
files and refuses to resume if the tokenizer content changes.

`NEURX_PRETRAIN_STEPS` counts micro-batches. One optimizer update consumes
`micro_batch_size * gradient_accumulation_steps` sequences, each containing
`NEURX_PRETRAIN_SEQ_LEN` next-token targets.

## Checkpoints

The atomic checkpoint is `transformer_v2.ckpt` with magic `NXTRFMV2`. It stores:

- model and tokenizer configuration;
- every layer's parameters, gradients, and AdamW first/second moments;
- global and optimizer steps plus a partial accumulation step;
- shard index, JSONL line, document/token counters, and unconsumed token IDs.

The model manifest is written beside it as
`checkpoint/NeurX-1.3/NeurX-1.3.neurx` by default. Set
`NEURX_PRETRAIN_MODEL_NAME` and `NEURX_PRETRAIN_OUTPUT_DIR` together to use a
different model name and directory.

An existing byte-level `transformer.ckpt` with magic `NXTRFMR1` is imported
automatically when no v2 checkpoint exists. Its single block becomes layer 0,
additional layers retain deterministic initialization, and the result is
immediately saved as v2. Because v1 stored a byte offset into a concatenated
corpus rather than a JSONL cursor, data streaming restarts at shard 0 after
migration. BPE migration from v1 is rejected because changing the vocabulary
would invalidate embedding and LM-head dimensions.
