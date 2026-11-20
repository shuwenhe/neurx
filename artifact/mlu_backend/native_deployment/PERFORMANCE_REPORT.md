# Performance report

**PERFORMANCE_VALIDATED: no.** No hardware workload ran. This session could not read MLU utilization or memory telemetry. There are no benchmark results or estimates.

| Measurement | Baseline to record after hardware acceptance |
| --- | --- |
| GEMM TFLOPS | Validated CNNL baseline per dtype and shape. Device-event elapsed time and documented operation count. |
| Device bandwidth and H2D/D2H | Verified byte counts and time for each direction, separating host wall time from device time where available. |
| Attention latency and MoE throughput | Single-card validated baseline over fixed sequence lengths and batch sizes, with the fixture and dtype recorded. |
| Prefill/decode throughput and TTFT | Pinned checkpoint, tokenizer, prompt lengths, batch sizes and generated token counts. Report prefill and decode separately. |
| Memory, utilization, temperature and power | Administrator-approved telemetry with timestamp and sampling interval, recorded with workload and idle baselines. |
| Inter-card collectives | Compare validated topology-aware runs with fixed payloads. Record ranks, NUMA, PCIe and MLU-Link topology. |

Capture runtime, driver, firmware, executable revision, device ordinal, warm-up and repeat counts, medians and tail latency, and all process exit codes. Compare each optimization with the baseline under identical input and hardware allocation.
