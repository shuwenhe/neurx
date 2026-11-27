# Attention BF16 Contract Review Plan

Goal: independently assess Norm, Softmax and composition without Native code.
Architecture: pinned official functions on GPU; independent FP64 same-operands diagnostics and conditional analytic error bounds; no tolerance fitting.
Spec: user numerical-contract-final-review request; existing TOLERANCE candidate.

Constraints: preserve original traces and22 hashes; no Native, Bridge, Preflight or production changes; no generic rtol; unknown library guarantees remain UNVERIFIED.

- [x] Audit HEAD/index/diff/source hashes and protected baseline.
- [x] Add standalone diagnostic with immutable separate evidence directory. Norm head dimensions6/8/64/256, seeds521/1807, zero/near-zero/extreme-safe/overflow; official unchanged RMSNorm. Capture actual FP32 dispatch stages.
- [x] Softmax lengths1/3/63/64/65/257, causal finite-min mask, -inf all-mask, finite all-mask, extreme logits, tiny probabilities. Preserve nonfinite classification rather than reject it.
- [x] Compare canonical prefill/decode/chunks using official outputs and same-operands node diagnostics; distinguish local vs total partition errors.
- [x] Run real GPU diagnostics and original seven reference tests; record exit codes/environment. CPU diagnostics never count as GPU execution.
- [x] Write four reports, conditional theory and exact rules; independently review read-only and record limitations; hash final contract candidate, no human approval implied.

Outcome: diagnostics/review delivered PARTIAL. No numerical contract human approval or SHA freeze; no Native implementation.
