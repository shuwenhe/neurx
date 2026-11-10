# Canonical S array syntax repair

Goal: normalize all active NeurX S sources to Type[] / Type[size], retaining array rank and semantics. Work on main only; preserve the current dirty worktree and all prior recovery/bootstrap/evidence artifacts.

- [ ] Inventory and archive all project S sources before edits; keep initial Git diff/status.
- [ ] Add failing normalization and repository regressions for declarations, signatures, make/literals, nested/fixed arrays, pointers/maps/generics, and strings/comments/index-expression preservation.
- [ ] Implement a lexical, type-aware migration/check tool and inspect its dry-run inventory. Exclude artifact/ and artifacts/ (historical evidence and compiler installations).
- [ ] Normalize project source files and repair malformed historical typed-make forms encountered in the same array syntax audit.
- [ ] Check no executable legacy prefix array types remain, ensure idempotence and review the diff.
- [ ] Compile/run representative canonical array programs using installed Stage4; run full native-stage4 and construction regressions. Record unrelated legacy syntax failures without claiming a whole-project successful compile.

Execution is inline, authorized by the user's explicit request. No branch/worktree changes and no compiler changes. Recovery/evidence: artifact/local-inference/array-syntax-20261110/.
