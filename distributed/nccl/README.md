# NCCL

NCCL-related code is kept here:

- `nccl_compat.h`: CUDA bridge ABI declarations and runtime loading of `libnccl.so`.
- `nccl_backend.s`: S-language NCCL backend interface.
- `nccl_backend_complete.s`: NCCL collective and point-to-point operations.

The transformer CUDA bridge includes `nccl_compat.h` from this directory and
performs gradient `AllReduce` before each optimizer update.
