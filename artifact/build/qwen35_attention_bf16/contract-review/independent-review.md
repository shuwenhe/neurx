# Independent read-only review — 2026-11-27

Reviewer /root/contract_review, explicitly requested by user. No files modified by reviewer.

Initial review checked official model SHA, actual 1+weight semantics, original AST/observer design, FP64 diagnostic limits and gamma assumptions. Proposed conditional mean/rsqrt intervals, softmax component interval and composition matrix cross-term formulas; did not assert CUDA library implementation verified.

v2 findings: FP32 nextafter(-1) collapsed after BF16 cast; all-NaN rows reported misleading maxabs0; no actual perturbation propagation; missing BF16 ULP and signed Inf classification. Preserved v1/v2 evidence; corrected v3/v4.

Final v4 limited review verified source and saved48 Norm/72 Softmax/9 partition/3 perturbation records, true adjacent BF16 weights, null all-NaN errors, signed Inf patterns, BF16 ULP and separate local-versus-propagated changes. Four reports accurately retain PARTIAL/conditional status. No substantive blocker to publishing PARTIAL evidence. Full contract freezing remains blocked by library precision and certified interval gaps. This is not human approval.
