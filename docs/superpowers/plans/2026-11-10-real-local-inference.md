# Real Local Inference Implementation Plan

> Execute inline using superpowers:executing-plans. The user explicitly requires continuous execution; no plan approval pause.

**Goal:** Generate at least 32 genuine tokens from the existing Qwen2.5-0.5B-Instruct checkpoint with a verified, officially installed self-hosted S compiler.

**Architecture:** Preserve both repositories and build a fresh verified compiler in a separate output directory. Diagnose the historical interpreter entry separately from the native HF execution path. Repair only demonstrated defects, retain fail-closed behavior, and instrument actual checkpoint loading and generation.

**Tech Stack:** S, native Linux amd64 compiler, Python build/test orchestration, BF16 safetensors and Hugging Face BPE.

**Spec:** User mission in this conversation; acceptance prompt: Explain how a compiler performs semantic analysis.

## Global Constraints
- Preserve source, user changes, checkpoint files and existing compile.log.
- Recovery point: /home/shuwen/shuwen/neurx/artifact/local-inference/recovery.
- No Seed substitution for accepted Stage4, no weakened validation or mock responses.
- Official installation into /home/shuwen/shuwen/neurx/artifact/local-inference/toolchain; preserve the preexisting installed command.
- Log every failed gate; never claim stages passed without evidence.

## Review Focus
- Missing imported functions must fail before running an incomplete program.
- String indexing must retain the compiler-defined type through lowering and byte conversion.
- Qwen attention biases and tied embeddings must participate in forward passes.
- Missing or corrupt weights must fail without a fallback answer.
- Token count, finite logits, source dependence and weight dependence must be verified.

### Task 1: Preserve and diagnose
- [x] Capture statuses, HEADs, binary diffs, Git bundles and previous logs for both repositories.
- [ ] Trace load_real_text_engine from source through the historical build and interpreter symbol resolution; record applicable and unreachable stages.
- [ ] Create a minimal string-index reproduction and establish the baseline test failures.

### Task 2: Verify and install compiler
- [ ] Run make selfhost with a fresh bootstrap directory and isolated installation prefix.
- [ ] Inventory all compiler stages, hashes, ELF architecture, supported operations and official validation results.
- [ ] If a compiler defect blocks bootstrap, add its failing regression, fix root cause and repeat official verification in a new directory.

### Task 3: Build and repair native inference
- [ ] Run native-stage4 tests and build serve with installed compiler; preserve diagnostic logs.
- [ ] For every observed defect add a failing regression before repairing its owning component.
- [ ] Audit Qwen forward operations, biases, normalization, RoPE, attention, embedding tie and tokenizer behavior.
- [ ] Verify parsing, typing, MIR verification, emission and initialization from compiler/runtime diagnostics and regression probes.

### Task 4: Model execution and independent verification
- [ ] Run the acceptance prompt through native serve with at least 32 generated tokens.
- [ ] Record checkpoint hashes/config, accessed weights, forward/logit/decode evidence, latency and peak memory.
- [ ] Verify weight dependence and absent external/fallback paths; run regression suites.
- [ ] Produce a report with root causes, modified files, compiler compatibility, commands, logs and limitations.

## Execution Ledger
- Baseline source trees clean at neurx 35ab871c05bf74653e99cfe18ebef4a72b2ac019 and s dd0c8057838cee84fd67fdd5d451ab20dc5a061e.
- Ruling: use a new NeurX branch in the requested checkout and preserve full Git recovery bundles; do not move the user workspace or overwrite earlier bootstrap outputs.
- Ruling: any new feature design work will use brainstorming; this mission currently repairs demonstrated build/runtime defects.

- User constraint: all subsequent edits/builds/logs stay inside NeurX. External directories moved to artifact/local-inference/{evidence,recovery}; external S source and seed restored. Compiler repairs live in artifact/local-inference/compiler-source.

## Verified Progress / Blocker
- Task 1 diagnosis recorded in docs/local-inference-2026-11-10.md. Legacy single-file build omitted imported function bodies; actual old engine also imports an absent model_cpu_inference module. Closure regression is green; actual old engine fails closed at build time.
- Seed byte-index semantic and standalone-runtime mismatch repaired in local compiler copy; two added regressions, 900 integer differential cases, 64-bit and bounded-memory regressions pass. Patch exported under tool/toolchain-patches/.
- Official selfhost Stage1 produced; Stage2 parsing, semantics, specialization and MIR validation reach CHECK complete; native code generation was stopped after the concrete runtime blocker was established. No accepted Stage4 or official install exists yet.
- Prior native diagnostic suite: original 19 tests green; repaired numerics suite 3 green; first combined suite 22 green. Final reviewed 24-test suite passed (296.902 seconds).
- Independent review found an omitted attention_bias compatibility regression; reproduced RED native exit91 and fixed architecture-specific default. Final review found no further important issues.
- Concrete blocker: canonical native array_set always copies the complete array, making actual NeurX tensor initialization O(N^2). Doubling 4096→8192→16384→32768 took .07/.30/1.33/5.49 seconds. Full-model 30-second controlled attempt reached 7.21 GiB RSS and zero completed forward passes, logits or generated tokens.
- Ruling: no unconditional in-place array mutation, no alternate Python/C++ model engine and no Stage1-as-Stage4 substitution. They would fail the user's semantics/verification constraints. Acceptance remains NOT DONE.

- Final checks: 24 native diagnostic regressions green; 2 Seed index regressions green from NeurX cwd after making their subprocess cwd explicit; 8 native float fixture subcases green; compiler patch applicability and git diff --check green. Stage4 official installation and real model 32-token acceptance remain incomplete.
