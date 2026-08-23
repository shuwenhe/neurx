# NeurX Benchmarks

This directory owns reproducible performance comparisons. Marketing claims in
the project README must link to a committed result produced by this suite.

## Required comparison controls

NeurX, vLLM, and SGLang runs must use the same:

- model and exact weight revision;
- accelerator model, count, power mode, and driver stack;
- input dataset, tokenizer, prompt lengths, and output lengths;
- precision, tensor/pipeline parallel settings, and quantization mode;
- request arrival pattern, concurrency, warm-up, and measured duration.

Record at least three runs and report the median. Keep raw measurements under
`artifacts/benchmarks/`; commit only reviewed summaries under
`benchmarks/results/`.

## Metrics

- TTFT: time to first token in milliseconds, including queueing.
- TPOT: inter-token latency in milliseconds after the first token.
- Throughput: output tokens per second and completed requests per second.
- Latency: request latency at p50, p95, and p99.
- Efficiency: output tokens per second per accelerator and peak memory usage.
- Reliability: error rate, timeout rate, and benchmark configuration hash.

Every result must conform to `result.schema.json`. A speedup is calculated from
the measured medians and must identify whether higher or lower is better.
