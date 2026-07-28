// NeurX Executor API Interface
// Phase -1: Architecture Contracts
// Purpose: Different execution modes (Eager, Compiled, JIT)

package contracts

// ExecutionMode enum
type ExecMode interface {
    name() string
}

type EagerMode struct {}
type CompiledMode struct {}
type JITMode struct {}
type AOTMode struct {}

func (EagerMode) name() string { return "eager" }
func (CompiledMode) name() string { return "compiled" }
func (JITMode) name() string { return "jit" }
func (AOTMode) name() string { return "aot" }

// Executor Interface - Execute operations
interface Executor {
    // Execution mode
    func set_mode(mode: ExecMode)
    func get_mode() -> ExecMode
    
    // Execute single operation
    func execute_op(op_name: string, inputs: []Tensor) -> Tensor
    
    // Execute computation graph
    func execute_graph(graph: ComputationGraph) -> Tensor
    
    // Profiling
    func enable_profiling(enable: bool)
    func get_profile() -> ExecutionProfile
}

// ExecutionProfile - Performance metrics
struct ExecutionProfile {
    total_time: float           // milliseconds
    kernel_times: map[string]float
    memory_peak: int            // bytes
    memory_allocated: int
    memory_freed: int
    kernel_calls: int
}

// EagerExecutor - Execute immediately
interface EagerExecutor extends Executor {
    // No additional methods, just execute immediately
}

// CompiledExecutor - Compile then execute
interface CompiledExecutor extends Executor {
    func compile(graph: ComputationGraph) -> CompiledGraph
    func optimize(graph: CompiledGraph) -> CompiledGraph
}

// CompiledGraph - Result of compilation
struct CompiledGraph {
    fused_ops: []FusedOperation
    memory_plan: MemoryPlan
    execution_order: []int
}

// FusedOperation - Multiple ops fused into single kernel
struct FusedOperation {
    ops: []string          // e.g., ["layernorm", "add"]
    inputs: []Tensor
    kernel: Kernel
}

// MemoryPlan - Pre-computed memory usage
struct MemoryPlan {
    peak_memory: int
    allocation_schedule: []MemoryEvent
    reuse_map: map[string][]int  // which tensors can reuse memory
}

// MemoryEvent - Memory allocation/deallocation at runtime
struct MemoryEvent {
    step: int
    tensor_id: string
    size: int
    action: string  // "alloc" or "free"
}

// Phase -1 Design:
// For Phase 1-8: Only EagerExecutor (execute immediately)
// CompiledExecutor: Phase 11+ (compiler optimization)
//
// EagerExecutor pattern:
// ```s
// func (e EagerExecutor) execute_op(op_name: string, inputs: []Tensor) -> Tensor {
//     dispatcher := e.dispatcher
//     kernel := dispatcher.select_kernel(op_name, inputs[0].device())
//     output := kernel.execute(inputs)
//     
//     if e.profiling_enabled {
//         e.profile.kernel_calls += 1
//         e.profile.kernel_times[op_name] += kernel_time
//     }
//     
//     return output
// }
// ```

// Phase -1 Verification
// Once implemented, verify:
// [ ] Eager executor works
// [ ] Operations execute in correct order
// [ ] Profiling collects timing data
// [ ] Profile shows performance bottlenecks
