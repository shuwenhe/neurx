// NeurX Phase -1 API Summary
// Architecture Contracts - All 7 Core Interfaces

package contracts

// Phase -1 Interfaces Defined:
// 1. tensor_api.s      - Tensor interface + TensorFactory
// 2. device_api.s      - Device abstraction (CPU/CUDA/CANN/Metal)
// 3. kernel_api.s      - Device-specific kernel implementations
// 4. dispatcher_api.s  - Route operations to kernels (simple switch in Phase 1)
// 5. operator_api.s    - Device-agnostic operations
// 6. autograd_api.s    - Automatic differentiation (backward pass)
// 7. optimizer_api.s   - Parameter update algorithms
// 8. executor_api.s    - Execution modes (Eager/Compiled)

// Layer Architecture (from ARCHITECTURE_PRINCIPLES):
//
//  Model Layer
//      ↓ calls
//  Operator Layer (device-agnostic)
//      ↓ calls
//  Dispatcher Layer (selects kernel)
//      ↓ returns
//  Kernel Layer (device-specific)
//      ↓ uses
//  Device Layer (allocation, sync)
//      ↓ manages
//  Memory & Tensor Core

// 10 Core Principles (ARCHITECTURE_PRINCIPLES.md):
//
// 1. Layering: Model → Operator → Dispatcher → Kernel → Device
// 2. Device Agnosticism: No "if device == CUDA" in Operator
// 3. Reference System: All Ops aligned with PyTorch
// 4. Gradient Support: All Tensor ops support backward
// 5. Observability: Profiler from Day 1
// 6. Test Coverage: Functional → Numerical → Gradient → Integration
// 7. Checkpoint/Resume: Loss curve continuity
// 8. Minimal API: Phase 1-3 < 50 public APIs
// 9. Device Isolation: New device doesn't modify Operator
// 10. Evolution not Rewrite: Incremental changes

// Phase -1 Completion Checklist:
//
// [ ] All 8 interface files created
// [ ] All interfaces documented
// [ ] No circular dependencies
// [ ] Code compiles (s_seed)
// [ ] Team reviews and approves
// [ ] Documented in git commit

// Phase 0 Will Use These APIs:
//
// - Dispatcher selects PyTorch reference kernel
// - Operator calls dispatcher to execute
// - Autograd computes gradients
// - Optimizer updates parameters
// - Executor runs eager evaluation

// Success Criteria for Phase -1:
//
// "The entire team has reviewed these interfaces and agrees:
//  - API design is stable
//  - Layer separation is clear
//  - No circular dependencies
//  - Can proceed to implementation"

// Next Steps:
//
// Phase 0 (Days 6-10):
//   - Create reference/ directory
//   - Implement PyTorch reference code
//   - Create export tools (forward, gradient, golden)
//   - Create compare utilities
//   - Build test framework
//
// Phase 1 (Days 11-15):
//   - Implement Tensor struct (tensor.s)
//   - Implement Device interface for CPU
//   - Implement basic shape operations
//   - Run test_tensor.s
