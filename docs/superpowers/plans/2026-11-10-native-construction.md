# Native Construction Implementation Plan

> Execute inline with superpowers:executing-plans and test-driven-development. Architecture evaluation was delegated by the user; design independently reviewed. Continue on main only. No acceptance from diagnostic binaries.

**Goal:** Replace quadratic tensor construction with safe builder/bulk operations, verify official Stage4 installation, and generate at least 32 genuine Qwen tokens.

**Architecture:** Preserve immutable ordinary arrays. Add typed opaque construction handles rooted in existing GC globals, checked seal/take publication, and pure bulk numeric operations. Integrate these primitives into real model/tokenizer construction without alternative inference engines.

**Tech Stack:** S canonical MIR/SSA/amd64 compiler, existing freestanding C runtime-extension generator, native GC, BF16 safetensors, Python test/measurement orchestration only.

**Spec:** `docs/superpowers/specs/2026-11-10-native-construction-design.md` and the user's mission.

## Global Constraints
- Work only inside `/home/shuwen/shuwen/neurx`, main branch (including local compiler copy).
- Preserve previous logs, patches, recovery bundles, source changes and model files.
- No global in-place array_set, no weakened validation, no diagnostic-as-Stage4 substitution.
- New evidence under `artifact/local-inference/array-construction-20261110/`.
- Final acceptance requires officially installed Stage4 plus genuine full checkpoint inference.

## Review Focus
- GC must retain unpublished descriptor/backing references across allocation.
- Stale/copied handles cannot mutate a published array; ordinary aliases remain value copies.
- Empty data, malformed input, overflow and partial reads must have distinct checked outcomes.
- Native numeric slot ABI and IEEE decode must match independent references.
- Benchmarks and real-model evidence must record the compiler stage and exclude mock success.

### Task 1: Runtime primitives and memory safety
- [x] Add failing C sanitizer/runtime tests for typed create/write/seal/take/release, invalid IDs/kinds/bounds, alias invalidation and IEEE bulk reads.
- [x] Implement registry-backed builders and bulk operations in local compiler runtime C.
- [x] Add explicit registry root slots, exact MIR/SSA signatures, and generator target names; regenerate and check output.
- [x] Run C ASan/UBSan and generator tests; preserve allocation/copy statistics.

### Task 2: Native S integration and construction regressions
- [x] Build a new diagnostic compiler from modified sources without overwriting old stages.
- [x] Add S wrapper/result types and failing native tests for GC roots, global/non-global programs, values/aliases and errors.
- [x] Verify native ABI, repeated lifecycle and existing array behavior; retain compiler identity.
- [x] Measure 4096, 8192, 16384, 32768, 1M and 10M using indexed writes and bulk paths, with wall/CPU/RSS/allocation/copy counters.

### Task 3: NeurX loading/forward integration
- [ ] Replace tensor decode, model field assembly, weight slicing/cache patching and output construction with builder/bulk calls.
- [ ] Replace tokenizer bulk text/table construction; close builders on errors.
- [ ] Add negative/shape and alias regressions; rerun existing numerical and serving tests using the diagnostic compiler.
- [ ] Preserve a reproducible incremental compiler patch and integration report.

### Task 4: Official toolchain and real checkpoint
- [ ] After earlier gates pass, run full official bootstrap in a fresh directory and official installation inside NeurX.
- [ ] Verify all stage identities, convergence/execution logs and installed binary identity.
- [ ] Build NeurX with installed Stage4, load/validate all tensor dimensions and all 24 layers.
- [ ] Compare real logits independently; generate >=32 native tokens and record loading/TTFT/token latency/RSS.
- [ ] Run final regression and independent review. Report DONE only if every acceptance gate passes; otherwise preserve concrete failed-gate evidence and report NOT DONE.

## Ledger
- Preflight: both recovery bundles verified. Existing Seed byte-index patch inspected. Current modifications retained on main; repair branches deleted by explicit user instruction.
- Design review resolutions are appended to the spec. Runtime primitives feed S wrappers; wrappers feed NeurX construction; only installed Stage4 may feed final acceptance.
- Ruling: typed construction is explicit shared mutable state behind non-pointer IDs; only unpublished backing storage can change. Ordinary array_set remains untouched.

- 2026-11-10 continuation: Tasks 1–2 evidence includes final-core + expanded sanitizer/native GC regressions, six indexed sizes and six BF16 bulk sizes. Allocation counters cover construction operations only. LSan unavailable under sandbox; ASan/UBSan and registry/GC stress passed.
- Model assembly RED: native exits 104 for accepted wrong dimensions and 101 for absence of bulk assembly; GREEN: 2/2 in 80.780s (`hf-assembly-{red,green}.log`).
- Forward bulk RED: native exit111; implementation under numerical regression. Tokenizer bulk RED: native exit2; implementation under regression.
- Official bootstrap now at Stage4 CODEGEN; installation still pending.
- Ruling: continue inline on main as explicitly requested; preserve all evidence rather than skill-suggested cleanup. Existing LM-head fallback retained for fixture compatibility; no new untied fallback behavior introduced.

- Forward integration GREEN: 7/7 in 279.162s, before full-logit API addition. Metadata RED exit1 on valid whitespace JSON; GREEN includes whitespace, rank3 rejection, integer overflow rejection, empty file/EOF/missing file distinctions.
- Full-logits RED: unknown initializer type at `hf_logits`, confirming no full-logit vector API existed. Added real native LM-head matvec result and fail-closed nonfinite detection, plus opt-in full-logit/activation tracing and monotonic generation timings; complete native suite now running.
- Generator regression harness note: unittest discovery imported script successfully but reported zero unittest methods (exit5); direct execution of `extensions_generate_test.py` passed. Logs preserved separately.
