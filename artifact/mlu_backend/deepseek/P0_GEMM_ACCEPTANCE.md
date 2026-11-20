# P0 GEMM acceptance

## Existing compute path

The CPU reference already exists as `cpu_matmul` in `backend/platform/cpu/compute_backend.s`. The existing `src/compute/gpu_gemm.s` checks dimensions and returns tensor metadata. It does not establish kernel execution. The current S runtime's `device_ops.s`, `device_binding.s`, and `device_tensor.s` provide the descriptor, binding, and resource interfaces to reuse. The CUDA and CANN lowering code contains vendor-specific paths. An MLU implementation needs an explicit MLU lowering and a real vendor launch before it can report success. Existing interfaces and backend behavior were preserved.

## Verified CPU reference

`test/contract/mlu_p0_cpu_gemm_reference.s` calls the existing S CPU implementation for two row-major rectangular cases, including signed fractional inputs. It checks every output against independent expected values. Compile, emit and execution each exited 0.

```sh
b="$PWD/artifact/build/mlu_p0"
mkdir -p "$b"
stage=/app/shuwen/s/.bootstrap/native-imports/stage4
"$stage" --compile-unit "$b/mlu_p0_cpu_gemm_reference.sasm" \
  backend/platform/cpu/compute_backend.s test/contract/mlu_p0_cpu_gemm_reference.s
"$stage" --emit-bin "$b/mlu_p0_cpu_gemm_reference.sasm" "$b/mlu_p0_cpu_gemm_reference"
"$b/mlu_p0_cpu_gemm_reference"
```

The exploratory seed-hosted reference probe compiled and linked but exited 1 at execution with `error[5] at 0:0: unknown arg value: float`. The verified test uses Stage4 native codegen. The seed-hosted limitation was not changed.

## Native acceptance and benchmark protocol

After the native gate passes, test row-major `A[M,K] * B[K,N]` for square `M=N=K` of **128, 256, 512, 1024 and 2048**, separately for BF16 and FP16. Also retain rectangular cases to detect order and transpose errors. Select the approved CNNL or BANG API against the actual vendor package. Keep pointers in typed native code and lifecycle policy in S.

For accuracy, round inputs to the tested dtype before computing the CPU reference, accumulate using at least FP32 precision, and apply the expected output rounding. Record accumulator/output dtypes, max absolute and relative error and mismatch count. Compare all outputs with a documented dtype-specific tolerance. Check repeated execution, synchronization, resource cleanup and failure handling before timing.

Publish measurements only for accepted configurations. Record the exact command and exit, M/N/K, dtype, warm-up and sample counts, median and P95 kernel latency, throughput using `2*M*N*K` operations per GEMM, memory consumption, temperature, power and utilization. Log H2D, D2H and host synchronization separately from device kernel time. Record the CPU reference time separately. There are no P0 MLU measurements yet.

Following GEMM acceptance, the operator order is RMSNorm, RoPE, Softmax, SwiGLU, MLA projections, MLA Attention, KV Cache, Expert Routing, Top-K, Grouped GEMM, and Token Dispatch/Combine. Multi-card CNCL work follows single-card kernels. No later operators were modified.
