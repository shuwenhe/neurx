# Benchmark Plan

No benchmark estimates or performance claims are included. Run benchmarks only after the runtime and approved test scope are confirmed.

## 1. CPU matrix multiplication

- Baseline existing NeurX CPU GEMM.
- Record matrix sizes, dtype, warmups, iterations, and median/p95 latency.
- Verify output against a reference implementation.

## 2. MLU matrix multiplication

- First execute a one-card CNRT/CNNL GEMM smoke test.
- Test FP16 and BF16.
- Verify output numerically against CPU or high-precision reference.
- Record shape, memory, launch, and synchronized kernel time separately.

## 3. FP16 and BF16

- Test elementwise and GEMM paths in both dtypes.
- Check dtype support and numerical error thresholds.
- Do not claim BF16 support until kernel execution succeeds.

## 4. Memory bandwidth

- Run host-readable copy microbenchmarks for host-to-device and device-to-host.
- Measure device-to-device copy within and across NUMA domains.
- Report per-card peak and sustained bandwidth separately.

## 5. Host-to-device transfer

- Pin host buffers.
- Test unpinned and pinned host memory.
- Sweep transfer sizes and report NUMA placement.

## 6. Device-to-host transfer

- Repeat transfer sweeps in the reverse direction.
- Measure copy and synchronization costs separately.

## 7. Attention kernels

- Test standard attention and paged attention.
- Sweep context and batch sizes.
- Validate output and KV-cache behavior.
- Test BF16/FP16 if supported.

## 8. Single-card inference

- Run a small Qwen model or native acceptance checkpoint.
- Measure prefill, decode, time-to-first-token, tokens/s, memory, and utilization.
- Compare numerical output with CPU or a known reference.

## 9. Eight-card tensor parallel inference

- Require working CNCL collectives first.
- Test all-reduce, all-gather, reduce-scatter, and broadcast.
- Validate TP4/TP8 sharding.
- Record NUMA, MLU-Link, and PCIe behavior.
- Do not benchmark until execution correctness passes.

## Evidence requirements

Each benchmark report must include:
- exact command and exit code,
- card and process mapping,
- runtime/compiler versions,
- firmware and driver versions,
- synchronized timing,
- numerical validation,
- memory use,
- temperature/power,
- failure details and no estimated values.
