# NeurX CUDA validation — 2026-11-17

**Overall: BLOCKED. GPU inference has not passed acceptance.**

## Root cause and environment

The host's `/proc/driver/nvidia/gpus/0000:01:00.0/information` reports an
NVIDIA GeForce RTX 4060 Ti. The kernel driver reports version 580.159.03.
This execution environment exposes no `/dev/nvidia*` device nodes.
`nvidia-smi` cannot communicate with the driver. This is unavailable device
access in the current execution environment, not evidence of absent physical
hardware. Whether the restriction comes from sandboxing, a device namespace,
or another host configuration cannot be established here. Changing host
devices or passthrough is outside this repository-only task.

CUDA toolkit: nvcc 12.0.140. libcuda.so.1, libcudart.so.12 and NVML load.
CUDA_VISIBLE_DEVICES and NVIDIA_VISIBLE_DEVICES are unset.
Direct Driver API `cuInit(0)` returns 100 / CUDA_ERROR_NO_DEVICE.
Subsequent `cuDeviceGetCount` returns 3 / NOT_INITIALIZED.
Independent Runtime API `cudaGetDeviceCount` returns 100 / cudaErrorNoDevice.
The available libraries therefore cannot access a GPU; successful loading
does not establish a functioning driver connection.

## Code path and changes

S main -> gpu_available -> neurx_s_cuda_device_count -> cudaGetDeviceCount.
Previously, the bridge converted every enumeration failure to zero without
setting its error string; S printed a generic no-GPU message.

The bridge now returns -1 on enumeration error and preserves operation,
CUDA error name, numeric code, description and actionable access checks.
Zero visible devices remains distinct from an API failure. Initialization
and S-configured initialization both use this probe and explicitly select
the device and initialize the runtime-managed primary context. Device
property and context errors retain their CUDA descriptions. S prints the
diagnostic and still refuses CPU fallback.

The existing kernel test make target referenced a nonexistent backend/cuda
directory; it now references backend/platform/cuda. Other legacy CUDA make
targets still contain stale backend/cuda paths and the referenced
test/hf_decoder_cuda_parity.py is absent. Those targets are not validated.

Modified existing source: backend/platform/cuda/s_inference_cuda_bridge.cu,
backend/platform/cuda/inference_server.s, makefile.
Backups taken before edits: artifact/cuda_validation/backups/ (same paths,
with makefile directly in that directory). The prior syntax repair and the
user-modified runtime shared library were present at task start. No external
S compiler source was modified. Building regenerates the runtime library.

Added: test/cuda_runtime_acceptance.cu,
test/cuda_enumeration_diagnostic_test.py, scripts/validate_cuda_runtime.sh,
and this report. Generated executables/IR remain under artifact/.

## Audit findings and limits

The active inference build links hf_decoder_cuda and the S bridge with
cuBLAS; CUDA runtime linkage is supplied by nvcc. ldd shows no missing
dependencies. cuobjdump shows sm_52 machine code and PTX. The available PTX
provides a possible JIT path on newer hardware, but RTX 4060 Ti compatibility
has NOT been exercised. No architecture compatibility PASS is claimed.

hf_decoder_cuda uses device_buffer ownership for weights and KV cache,
checked cudaMalloc/cudaMemcpy, checked cuBLAS operations, a configured
transformer layer loop and LM head. It checks kernel launch status and uses
blocking device-to-host logits copies to synchronize results. Source review
does not prove that these operations work on this GPU. Destructors currently
ignore cudaFree/cublasDestroy errors; a failed constructor after cublasCreate
also deserves a resource-lifetime review. Leak freedom, asynchronous error
behavior and multi-device/thread context ownership are not established.
No speculative decoder rewrite was made without an executable GPU test.

## Actual tests

* Before fix: a ctypes probe of the bridge returned count=0, error='';
  assertion requiring a CUDA diagnostic failed as expected.
* `make build-s-gpu-cuda-runtime`: exit 0, build/link only.
* `python3 test/cuda_enumeration_diagnostic_test.py`: PASS, count=-1,
  cudaGetDeviceCount: cudaErrorNoDevice (100), with access guidance.
* Initial standalone nvcc compile hit the CUDA 12.0/glibc fortified-header
  incompatibility. Using the repository's existing
  -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 flags compiled successfully.
* `bash scripts/validate_cuda_runtime.sh`: acceptance executable builds;
  runtime exits 77, BLOCKED cuInit: 100 CUDA_ERROR_NO_DEVICE.
* `make hf-decoder-cuda-kernels-test`: initially failed on nonexistent source
  path; after path repair compiles and prints SKIP reason=no-CUDA-device.
  Its exit 0 is NOT a runtime PASS.
* S backend and hf_config compiled and linked with the existing external
  s_seed executable, using copies/output under artifact/cuda_validation.
  Running that backend prints the full cudaErrorNoDevice diagnostic and
  CPU fallback remains disabled. S main returns normally after printing
  initialization failure, so shell exit 0 is NOT inference success.

## Acceptance matrix

| Requirement | Result |
|---|---|
| Driver initialization | BLOCKED: cuInit error 100 |
| Correct enumeration/properties | BLOCKED: no exposed CUDA device |
| Context, allocation, H2D/D2H | NOT RUN: driver gate failed |
| Real kernel, synchronization, CPU numerical reference | NOT RUN |
| Resource cleanup / leak check | NOT RUN on GPU |
| Qwen weight upload, all 24 layers, LM head | NOT RUN |
| At least 32 generated tokens / greedy reference parity | NOT RUN |
| Logits numerical tolerance validation | NOT RUN |

The new acceptance executable checks Driver/Runtime enumeration agreement,
properties, primary context, allocations, exact transfer roundtrip, a real
vector-add kernel against an independent CPU loop (exact tolerance for the
chosen exactly representable inputs), synchronization, explicit checked
frees, memory snapshots and primary-context reset. It exits 77 if blocked.
This does not replace transformer/model numerical acceptance or a leak tool.

## Performance

GPU memory capacity, model loading time, TTFT, average token latency,
tokens/sec, peak GPU usage and inference CPU RSS: **not measured** because
no model execution occurred. CPU/GPU performance comparison: not performed.
Host GPU name/driver above are procfs observations, not successful CUDA
property queries. No model-logit tolerance has been validated.

## Next steps

1. Run this repository in an environment exposing the NVIDIA GPU device
   nodes and driver interface. Confirm nvidia-smi and cuInit succeed there;
   do not create device nodes or replace drivers based only on this report.
2. Run `bash scripts/validate_cuda_runtime.sh` and require exit 0, then run
   `compute-sanitizer --tool memcheck --leak-check full --error-exitcode 1
   artifact/cuda_validation/cuda_runtime_acceptance`. Run the decoder kernel
   tests too; require actual PASS rather than SKIP.
3. Repair/restore the separate model-parity harness and its stale targets.
   Compare identical prompt token IDs and FP32 model weights against an
   independent implementation for every step of 32 greedy tokens; check
   finite full-vocabulary logits using a predefined, justified atol/rtol,
   record maximum errors and require identical greedy IDs. No tolerance
   or greedy parity can be certified here.
4. Instrument actual model loading/layer and LM-head execution and collect
   GPU memory, peak CPU RSS, loading time, TTFT and per-token timing. Gate
   performance reporting on numerical correctness, then compare the CPU
   path with the same inputs and decoding settings.
