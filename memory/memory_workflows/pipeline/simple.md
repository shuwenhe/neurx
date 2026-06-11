# Memory Pipeline

Stages:
- dataset: docs -> chunk -> embed
- index: build -> update -> query
- retrieval: query -> rerank -> context
- evaluator: recall -> score -> log

IO contract:
- Input: document manifest, run config
- Output: retrieval index and metrics

