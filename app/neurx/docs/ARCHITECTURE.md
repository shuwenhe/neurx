Neurx Architecture (high level)

Goals:
- S-first core for discoverability and self-hosting
- Thin C/CUDA kernels for performance
- Modular IR and passes for fusion and memory planning
- Clear bindings surface for language interop

Key modules:
- tensor, allocator
- autodiff tracer
- ir and passes
- runtime/executor
- ops and kernels
- distributed
