Neurx - framework layer scaffold

Structure:
- s/: S source by module
- bindings/: C/Python bridges
- examples/: minimal examples
- tests/: unit tests
- docs/: design docs

Goal: provide an S-first core for tensors, autodiff, IR, runtime, and ops; keep high-performance kernels in C/CUDA and expose via thin bridges.