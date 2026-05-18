Simple pretrain pipeline for GPT-Large

Stages:
- dataset: manifest -> tokenizer -> shard
- dataloader: micro-batching -> collate -> token windows
- model: init -> forward -> loss
- optimizer: compute grads -> step -> scheduler
- checkpoint: save/keep best

IO contract:
- Input: dataset manifest (paths), hyperparameters (config)
- Output: checkpoint tarball directory, eval metrics

This pipeline is intentionally implementation-agnostic. The workflow should call the runtime API or compiled IR rather than invoking CUDA kernels directly.