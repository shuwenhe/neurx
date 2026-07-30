












import "dispatcher_api"
import "autograd_api"

struct OperatorContext {
    requires_grad: bool
    dispatcher: Dispatcher
    device: Device
    profiler: Profiler
}

interface IOperator {



    forward(inputs: []Tensor, ctx: OperatorContext) -> Tensor


    backward(grad_output: Tensor) -> []Tensor


    operator_name() -> string
    num_inputs() -> i64
    num_outputs() -> i64


    supports_device(device: Device) -> bool
    supports_dtype(dtype: DType) -> bool
}


























interface IOperatorDeterminism {












    is_deterministic() -> bool


    set_seed(seed: i64) -> void
}

interface IOperatorComposition {





    compose(operators: []IOperator) -> IOperator
}

interface IOperatorAutograd {




    gradient_wrt_input(i: i64, grad_output: Tensor, forward_inputs: []Tensor) -> Tensor


    check_gradient(forward_inputs: []Tensor, eps: f64) -> f64
}

interface IOperatorPerformance {

    estimated_time_us(shapes: [][]i64) -> i64


    estimated_memory(shapes: [][]i64) -> i64


    profile(inputs: []Tensor) -> map[string]f64
}


const ProhibitedInOperators = """
❌ malloc() / new() / allocate()        → pre-allocate tensors
❌ if device == CUDA                    → use Dispatcher
❌ CUDA API calls                       → use Kernel
❌ printf() / logging                   → use context logger
❌ File I/O                             → serialization_api
❌ Random numbers (unseeded)            → use seeded RNG
❌ sleep() / timing                     → use profiler
❌ Global state access                  → thread-unsafe
❌ Kernel direct calls                  → use Dispatcher
"""


const RequiredInOperators = """
✅ Use Dispatcher.select_kernel()      → for kernel selection
✅ Pre-allocate output tensors         → caller decides memory
✅ Track computation graph             → for autograd
✅ Support all required dtypes         → (fp16, fp32, etc.)
✅ Implement backward()                → for gradients
✅ Be deterministic                    → same input → same output
✅ Validate device compatibility       → via supports_device()
✅ Document assumptions                → shapes, dtypes, etc.
"""
