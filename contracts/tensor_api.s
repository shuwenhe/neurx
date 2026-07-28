// NeurX Tensor API Interface
// Phase -1: Architecture Contracts
// Purpose: Define the core Tensor interface that all operations depend on

package contracts

// DataType enum
type DataType interface {
    name() string
}

type Float32 struct {}
type Float64 struct {}
type Int32 struct {}
type Int64 struct {}

func (Float32) name() string { return "float32" }
func (Float64) name() string { return "float64" }
func (Int32) name() string { return "int32" }
func (Int64) name() string { return "int64" }

// Device interface (forward declaration, fully defined in device_api.s)
type Device interface {
    name() string
    allocate(size: int) -> []byte
    deallocate(buffer: []byte)
}

// Tensor Interface - Core data structure for all computations
interface Tensor {
    // Properties
    func shape() -> []int
    func dtype() -> DataType
    func device() -> Device
    func numel() -> int              // Total number of elements
    func requires_grad() -> bool
    
    // Shape operations (zero-copy via stride)
    func reshape(shape: []int) -> Tensor      // Change shape, may change stride
    func transpose(axes: []int) -> Tensor     // Permute dimensions
    func view(shape: []int) -> Tensor         // Unsafe reshape, requires contiguous
    func squeeze(dim: int) -> Tensor          // Remove dimension of size 1
    func unsqueeze(dim: int) -> Tensor        // Add dimension of size 1
    
    // Data access
    func get(indices: []int) -> float         // Get single element
    func set(indices: []int, value: float)    // Set single element
    func contiguous() -> Tensor               // Ensure C-contiguous layout
    
    // Gradient tracking
    func backward()                           // Compute gradients
    func grad() -> Tensor                     // Get gradient
    func zero_grad()                          // Clear gradient
    
    // Metadata
    func is_contiguous() -> bool
    func stride() -> []int                    // Memory stride for each dimension
    func storage_offset() -> int              // Offset in underlying storage
    
    // Memory
    func nbytes() -> int                      // Total bytes used
    func data_ptr() -> int                    // Pointer to underlying data (for advanced use)
}

// TensorFactory Interface - Create tensors
interface TensorFactory {
    func zeros(shape: []int, dtype: DataType, device: Device) -> Tensor
    func ones(shape: []int, dtype: DataType, device: Device) -> Tensor
    func randn(shape: []int, dtype: DataType, device: Device) -> Tensor     // Normal distribution
    func rand(shape: []int, dtype: DataType, device: Device) -> Tensor      // Uniform [0, 1)
    func arange(start: float, end: float, step: float, dtype: DataType, device: Device) -> Tensor
    func eye(n: int, m: int, dtype: DataType, device: Device) -> Tensor     // Identity matrix
}

// Operation - Tracks computation for autograd
struct Operation {
    name: string
    inputs: []Tensor
    backward_fn: func(grad_output: Tensor) -> []Tensor
}

// Constants for Phase -1 testing
const (
    PHASE_1_TARGET_SHAPES = 100  // Number of shape operations to test
)

// Phase -1 Verification
// Once implemented, verify:
// [ ] All shape operations preserve data (no unintended copies)
// [ ] Gradient tracking is enabled when requires_grad=true
// [ ] Device is correctly propagated
// [ ] stride calculation is correct for all operations
