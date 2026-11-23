# Standalone native GEMM development

## Plan

Use the deployed CNNL 2.2.18 and CNRT 7.7.3 headers as the interface baseline. Implement packed row-major FP16 and BF16 inputs, FP32 accumulation and output, and independent FP32 comparison. Compile the harness and implementation against those headers before hardware testing. A reserved card and explicit authorization are required for execution. Measure repeated launches with queue notifiers and report transfer time separately.

## Existing implementation trace

The deployed `glm53_serve` editable package is rooted at `/workspace/vllm-v0.25.1+mlu0.16.0.pt212/vllm_mlu`. Its `model_executor/layers/linear.py:74` calls `_mlu_ops.py:matmul`, which delegates to `torch_mlu_ops/_ops.py:matmul` and its registered native extension. Read-only symbol inspection of deployed `torch_mlu_ops/lib/libtorch_mlu_ops.so` found undefined references to `cnnlMatMulEx_v2`, `cnnlBatchMatMulEx` and `cnnlGroupGemm`. The library also contains call diagnostic strings for those APIs and exports a custom MLU grouped-GEMM offset kernel. This establishes compiled CNNL GEMM paths and a custom grouped-GEMM helper. It does not identify the exact algorithm used for a particular production request.

The standalone NeurX baseline uses the documented `cnnlMatMul_v2` entry point. The deployed header explicitly documents half/half/float/float and bfloat16/bfloat16/float/float storage, output and compute combinations. It documents FP32 compute as multiplication and accumulation. The wrapper sets those descriptors, selects a CNNL heuristic, stages device buffers and returns the first original CNRT/CNNL status. The interface accepts rectangular packed row-major matrices and computes D=A×B. Transposed and padded user buffers are outside this version's interface. There is no CPU fallback.

## Build and acceptance

Build in an approved userspace with matching CNRT and CNNL headers and libraries. The inspected production bundle was Ubuntu 24.04 with CNRT 7.7.3, CNNL 2.2.18 and CNDrv 3.7.4. CNCC is unnecessary for this C client of a prebuilt vendor kernel. The commands below do not require changing host glibc or the production container.

```sh
sdk=/usr/local/neuware
build="$PWD/artifact/build/mlu_gemm_acceptance"
mkdir -p "$build"

cc -std=c11 -O2 -Wall -Wextra -Werror -ffp-contract=off \
  test/contract/mlu_gemm_cpu_validation.c -lm -o "$build/cpu_reference"
"$build/cpu_reference"

cc -std=c11 -O2 -Wall -Wextra -Werror -ffp-contract=off -I"$sdk/include" \
  backend/platform/mlu/native_gemm.c test/contract/mlu_native_gemm_test.c \
  -L"$sdk/lib64" -Wl,-rpath-link,"$sdk/lib64" -lcnnl -lcnrt -lm \
  -o "$build/mlu_native_gemm_test"
```

After explicit hardware authorization and exclusive assignment, first pass the [CNRT runtime gate](P0_REMEDIATION_PLAN.md). Then run the harness using the allocated CNRT ordinal as visible in the test process. Keep the CSV and stderr with the device PCI ID, driver, SDK and command exit status.

```sh
LD_LIBRARY_PATH="$sdk/lib64" "$build/mlu_native_gemm_test" "$CNRT_ORDINAL"
```

The test compares both input formats to the shared increasing-K FP32 reference for 128, 256, 512 and 1024 square sizes, an odd rectangular case and two DeepSeek projection shapes. Deterministic dyadic inputs are exactly representable in both formats. The test uses an absolute-plus-relative tolerance, rejects nonfinite outputs and reports maximum and mean errors. Relative error uses a denominator floor of 1e-6. This fixture establishes a reproducible baseline and should be extended with exponent-range and accumulation-sensitive device cases before inference acceptance.

## Execution and performance report

| Stage | Evidence |
| --- | --- |
| Implemented | `backend/platform/mlu/native_gemm.c` and `native_gemm.h` plus `test/contract/mlu_native_gemm_test.c`. The prior CPU harness and native test share `test/contract/mlu_gemm_reference.h`. |
| Compiled | Both new translation units compiled with warnings treated as errors using the deployed headers. Relocatable linking resolved the harness-to-wrapper call. |
| Linked executable | Blocked on the Ubuntu 20.04 host. Linking the deployed SDK failed on `GLIBC_2.34` and `GLIBC_2.38` symbols. |
| CPU correctness | The existing CPU suite passed all 20 shape and dtype combinations and both dtype boundary checks after extracting the shared reference. |
| MLU execution / accuracy | Blocked pending a compatible test execution environment, exclusive card assignment and explicit authorization. No GEMM was submitted to a device. |
| Performance | No hardware results. The harness records one warm-up, a 20-launch notifier interval divided by 20, separate synchronous H2D/D2H wall times, CPU reference wall time, device bytes and workspace bytes. TFLOPS uses 2MNK divided by mean kernel seconds and 10^12. The aggregate notifier interval does not provide per-launch percentiles. |

## NeurX integration design

After standalone acceptance, add an MLU operation implementation behind Device ABI v1. Create the CNNL handle and descriptors against the selected device context. Bind the handle to the operation stream, reuse the chosen algorithm and workspace for a fixed shape and dtype, and consume existing device buffer handles. Keep copies and notifiers in the standalone harness or an explicit profiling path. Preserve original vendor errors through the backend diagnostic path and validate stream lifetime and cleanup under both successful and failed launches.

DeepSeek stores BF16 linear weights in output-by-input order. The standalone test uses packed B[K,N]. In the inference adapter, validate the existing device weight layout and implement the matching CNNL transpose descriptor before eliminating any staging transpose. Establish FP32-output correctness first. Any BF16 output conversion or vendor epilogue needs its own comparison. Validate the integrated linear projection on one reserved card before grouped experts or multiple devices.
