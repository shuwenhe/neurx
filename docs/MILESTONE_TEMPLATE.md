# Milestone Template

**Feature**: [Feature Name]  
**Date**: [YYYY-MM-DD]  
**Status**: [In Progress / Complete / Blocked]

---

## Phase Tracking

| Phase | Status | Evidence | Notes |
|-------|--------|----------|-------|
| **Design** | ❌/⏳/✅ | Design doc / PR | Architecture complete |
| **Implementation** | ❌/⏳/✅ | Code committed | All functions written |
| **Compile** | ❌/⏳/✅ | `make build-*` | Zero errors |
| **Unit Test** | ❌/⏳/✅ | Test results | All PASS |
| **Numerical Validation** | ❌/⏳/✅ | Golden comparison | Error < 1e-5 |
| **Integration Test** | ❌/⏳/✅ | E2E test | System works |
| **Performance Validation** | ❌/⏳/✅ | Benchmark | Meets target |

---

## Quick Status Example

```
FlashAttention

Design          ✓
Implementation  ✓
Compile         ✓
Unit Test       ✓
Numerical       ✓
Integration     ✗
Performance     ✗
```

**Current Phase**: Integration Testing  
**Blocker**: None / [Description]

---

## Checklist

### Design
- [ ] Architecture document written
- [ ] API defined
- [ ] Dependencies identified
- [ ] Review complete

### Implementation
- [ ] All functions implemented
- [ ] Code follows style guide
- [ ] Comments added
- [ ] PR merged

### Compile
- [ ] Compiles without errors
- [ ] Compiles without warnings
- [ ] All platforms pass (CPU/CUDA/CANN)

### Unit Test
- [ ] Unit tests written
- [ ] All tests pass
- [ ] Code coverage > 80%
- [ ] Edge cases covered

### Numerical Validation
- [ ] Golden tests generated (PyTorch/NumPy)
- [ ] Outputs match reference (error < 1e-5)
- [ ] Tested on multiple inputs
- [ ] Gradient check pass (if applicable)

### Integration Test
- [ ] Integrates with existing system
- [ ] E2E test passes
- [ ] No regressions
- [ ] Documentation updated

### Performance Validation
- [ ] Benchmark written
- [ ] Meets performance target
- [ ] Profiled for bottlenecks
- [ ] Optimizations documented

---

## Evidence

**Compile**:
```bash
make build-feature
# Output: compiled feature.s -> feature.ir
```

**Unit Test**:
```bash
make test-feature
# Output: 10/10 tests PASS
```

**Numerical**:
```bash
make verify-golden-feature
# Output: max_error = 3.2e-7 < 1e-5 ✓
```

**Integration**:
```bash
make integration-test-feature
# Output: E2E test PASS
```

**Performance**:
```bash
make benchmark-feature
# Output: 15.2 ms (target: < 20 ms) ✓
```

---

## Notes

- **Blockers**: [List blockers]
- **Dependencies**: [List dependencies]
- **Next Steps**: [Next actions]
- **Risks**: [Known risks]

---

## Sign-off

- [ ] All phases complete
- [ ] Documentation updated
- [ ] Release notes written
- [ ] Approved by: [Name]

---

**Last Updated**: [Date]  
**Owner**: [Name]
