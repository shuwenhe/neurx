# Attention BF16 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Execute sequential RED/GREEN tasks; do not cross reference/budget approval gates.

**Goal:** Fixed official eager BF16 oracle, then independently verified Native Attention BF16.
**Architecture:** Preserve old paths. Observe unchanged pinned official AST bodies before specifying numerical budgets. Implement independent BF16 session only after budget approval; test each kernel batch before proceeding.
**Tech Stack:** Python 3.12, Torch 2.6.0+cu124 (oracle only), CUDA C++/nvcc12, RTX4060Ti, existing sanitizer runner.
**Spec:** docs/reports/QWEN35_ATTENTION_BF16_TEST_PLAN.md plus current user implementation authorization.

## Global Constraints

All changes under NeurX. Preserve initial HEAD/history, dirty reports, untracked tests, FP32 Attention, DeltaNet BF16, Bridge/Preflight and external compiler. No MoE/Decoder/E2E. No Native result used to widen budget. Fail a gate: stop subsequent stages, preserve evidence. The approved design requires human review and SHA freeze of the tolerance report before Native kernels; authorization to implement the selected architecture does not establish specific numerical tolerances.

## Review Focus

- Oracle decorators/dependencies: body hashes and tampered-source rejection.
- Observer changes results: compare trace on/off and repeated exact results.
- Text RoPE/normalization dtype: capture actual op boundaries; do not copy DeltaNet rules.
- Cached decode offset/mask: nonzero prefix and chunk sequences, cache lengths and post-RoPE K.
- Error metrics: isolated same-operand FP64 semantic comparisons, explicit BF16 rounding; no self-comparison reported as numerical accuracy.

## Task A: Official dynamic reference

Files: new test/native-construction/qwen35_attention_official_reference.py and test_qwen35_attention_official_bf16.py; evidence artifact/build/qwen35_attention_bf16/reference/.
Interface: load_official(source=SOURCE) -> namespace/provenance; fixture(seed,length,dim,rotary,hidden,qh,kh) -> JSON-compatible fixture; run_reference(fixture, partition='prefill', observe=True) -> nodes, events, arrays, cache snapshots, provenance. Metrics explicitly name independent FP64 same-operand semantic reference.
- [x] Write test requiring missing harness; run and save RED.
- [x] Implement hash-pinned unchanged AST loader, module/dispatch/rotary/cache observers and independent FP64 metric calculation.
- [x] Execute host GPU tests for all required nodes/dtypes, deterministic repeat/trace on-off, hash rejection, cached decode, positions, real head width and inv_freq construction.
- [ ] Preserve logs, tensor snapshots, per-node metrics, AST/source hashes, environment, baseline snapshot. Commit only new scoped files after verification.

## Task B: Tolerance review gate

Files: docs/reports/QWEN35_ATTENTION_BF16_TOLERANCE.md and review evidence.
- [x] Define exact copy/layout/BF16 pointwise rules and FP32 comparison candidates from reference-only evidence and explicit analytic assumptions; no native implementation exists yet.
- [x] Independent review: confirm source/body provenance, coverage and that candidate budget is not reverse-fitted.
- [ ] Obtain required human review/freeze of exact tolerance content. Until then state REVIEW_REQUIRED and stop Native implementation; no numerical PASS beyond reference self-tests.

## Task C: Native batches after B approval

Files: new backend/platform/cuda/hybrid_attention_bf16.h/.cu; new qwen35_attention_bf16_probe.cu/test_qwen35_attention_bf16.py.
- [ ] Batch1 projection/QK norm RED→GREEN→GPU metrics and regression.
- [ ] Batch2 Partial RoPE/writeback RED→GREEN→GPU metrics and regression.
- [ ] Batch3 score/scale/mask/softmax/P RED→GREEN→GPU metrics and regression.
- [ ] Batch4 AV/gate/O RED→GREEN→GPU metrics and regression.
No batch starts unless previous gate is green and evidence saved.

## Task D–F: State, safety, regression after C

- [ ] KV prefill/decode/chunk/import/reset/recovery/lifetime RED→GREEN using frozen budget.
- [ ] Real host memcheck/initcheck and existing deliberate-fault controls; original suites 11/16/5/11 plus new suite.
- [ ] Record component prefill/decode latency, launch count and memory/convert overhead with measured vs estimated labels; never model TTFT/TPS.
- [ ] Save PHASE1/PHASE2/KV_CACHE/FINAL reports with actual statuses and commits; independent final review before module PASS.

## Execution ledger

- Phase A RED: missing harness self-test FAIL; initial official GPU6/6.
- Independent review: two P2 reference controls/metric completeness findings; added two failing tests, fixed by removing all hooks/wrappers in observation-off path and adding required metrics. Full GPU suite7/7 GREEN, original mathematical bodies unchanged.
- Ruling: preserve concurrent user commit c43c0577 — it contains original protected work and initial reference implementation; rolling it back would destroy user history. Protected file hashes revalidated; cost if wrong would be misattributing changes, so starting and observed HEAD are both recorded.
- Tolerance candidate remains incomplete/PENDING for FP32 norm/softmax and composition; reviewer did not grant human approval. Stop before Native kernels as required by the approved spec.
