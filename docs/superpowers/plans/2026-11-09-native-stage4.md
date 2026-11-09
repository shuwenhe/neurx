# NeurX Stage4 migration implementation plan

**Goal:** Compile the existing NeurX command entry points with the accepted S Stage4 compiler and verify real execution without seed or legacy fallback.
**Architecture:** Keep the existing S commands and APIs. Add a native build entry point that resolves their source packages and invokes Stage4 directly. Adapt only constructs rejected by the compiler; preserve validation, subprocess exit codes and inference behavior.
**Tech stack:** S, Python 3 build/test orchestration, accepted Linux/amd64 Stage4.
**Spec:** User request in this session: compile /root/shuwen/neurx with /root/shuwen/s self-hosted compiler; proceed with compatibility fixes.

## Global constraints
- Preserve the existing main branch and work directly in this checkout, as requested.
- Do not replace functionality with stubs or use seed/legacy fallback.
- Record compiler failures and distinguish executable tests from compilation alone.

## Review focus
- Invalid command configuration must return the existing error status.
- Child process failure must propagate, including shell quoting.
- Module resolution must not silently omit missing dependencies.
- Failed compilation must not leave a stale executable presented as current.
- Serving and distributed commands must retain their behavior; unsupported compiler/runtime features must remain explicit blockers.

### Task 1: Train and benchmark
- [x] Add native compilation/execution regression tests and observe failures.
- [x] Adapt main return declarations and command runtime string/process operations.
- [x] Compile and test configuration rejection, shell argument handling and subprocess status.

### Task 2: Native build integration and remaining commands
- [x] Add native package resolver and build target with configurable Stage4 path.
- [x] Attempt worker/controller/serve closures and minimize diagnostics; unresolved namespace imports, prefix arrays, float parsing and socket intrinsic support are blockers.
- [ ] Adapt supported syntax and APIs while retaining behavior; document any backend feature blockers with minimal probes.

### Task 3: Verification and documentation
- [x] Run native regression suite (10 pass) and existing quality gate (fails missing scripts/check_layout.sh); report pre-existing failures.
- [x] Review diff independently, fix both important findings, document commands and limitations; leave changes reviewable and uncommitted.

## Execution record

- User authorized proceeding after the first failed Stage4 build. Changes remain in the requested main checkout without new branches or commits.
- Initial real native command tests failed on string-to-int conversion; after runtime intrinsic/return-type fixes, train and benchmark compile and execute.
- Independent review found preflight stale-output and invalid member-import handling; both were reproduced by failing tests, then fixed. S_REPO_ROOT handling in tests was aligned.
- Native suite: 10 tests pass, including successful benchmark result validation and subprocess quoting/status checks.
- Ruling: do not substitute integer model weights, omit unresolved imports, stub socket operations, or use seed fallback to force success. The remaining commands require changes to S itself. An asynchronous scope question asks whether to expand work to that compiler; no answer yet.
- Full five-command build remains incomplete. Stage4 has not been modified.

## Authorized compiler extension — 2026-11-09

User chose “扩展 S 编译器，继续完成全部入口”. The scope now includes S frontend,
MIR/SSA/AMD64 floating point, and the native runtime needed by NeurX.
Work remains on the existing main checkouts, preserving the previously accepted
Stage4 under `.bootstrap/native-imports` while new compilers are built separately.

- [ ] Add failing frontend/backend/runtime probes and NeurX runtime I/O tests.
- [ ] Extend canonical syntax/semantics (float, prefix arrays and actual NeurX constructs).
- [ ] Extend MIR/SSA/AMD64 float operations without using float in the compiler implementation itself.
- [ ] Implement required native I/O/process/socket operations with local runtime tests.
- [ ] Remove duplicate NeurX package definitions and adapt obsolete standard-library calls while preserving behavior.
- [ ] Build the extended compiler, then self-compile and verify convergence/execution.
- [ ] Compile all five real commands and execute configuration, serving fixture and local distributed tests.
