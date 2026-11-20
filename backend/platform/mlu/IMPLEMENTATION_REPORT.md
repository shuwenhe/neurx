# MLU Device ABI v1 implementation report

## Dependency check before implementation

- The Neuware prefix at `/usr/local/neuware` exposes `cndev.h`, `libcndev.so.3.12.4`, and CNDev samples. The package database lists CNDev 3.12.4, the Cambricon DKMS package 6.5.52, and cntoolkit 3.13.6.
- The loader cache and searches of the accessible SDK and system directories yielded no CNRT library or headers and no CNNL headers. CNCC was absent from PATH. Package metadata alone does not verify that an SDK component is usable.
- In this session `cnmon info` reported `CNDEV_ERROR_NO_DRIVER`, and no MLU device nodes were visible under `/dev`. The earlier MLU audit recorded eight cards in its execution environment.

## Implementation scope

The ABI v1 registry loads a backend-named shared object and validates its ABI version, minimum table size, and backend name. The CUDA and CANN plugins use positive resource handles, zero for successful status calls, and negative results for failures. The MLU foundation exposes the full callback table and reports zero availability. It distinguishes loadable CNRT from missing or unloadable CNRT without invoking any vendor entry points. S owns that policy. A C adapter supplies the v1 function-pointer table and adapts the integer-only S shared-library exports to the C signatures.

## Modified files

| File | Change |
| --- | --- |
| `backend/platform/mlu/device_abi_mlu.s` | S implementation of the unavailable probe and operation status. Checks whether Linux can load `libcnrt.so` when a diagnostic is requested. |
| `backend/platform/mlu/device_abi_mlu.c` | ABI v1 entry point, callback table, C signature adapters, and diagnostic strings. |
| `backend/platform/mlu/CMakeLists.txt` | Standalone Linux build for the plugin and its S companion library. |
| `makefile` | Adds the isolated `device-abi-mlu-build` and `device-abi-mlu-test` targets. Uses an existing S seed compiler. |
| `src/runtime/device/device_abi.s` | Recognizes `mlu` as its own backend and exposes zero advertised capabilities. |
| `test/contract/device_abi_mlu_unavailable_test.cpp` | Checks v1 metadata, the complete callback table, rejected operations, and registry error propagation. |

## Build and test results

- `make device-abi-mlu-test` built the plugin and passed in a fresh output directory. The system loader resolved its S companion library from the same directory through the plugin's `$ORIGIN` runpath.
- An S program compiled against the public Device ABI and confirmed that `device_probe` reports the MLU identity, zero availability and features, and that `device_open` returns an invalid context with a zero handle.
- The cached Ubuntu 22.04 package exposed CNRT 6.12.1 headers and binaries after extraction into a temporary directory. Its library requires glibc 2.34, and this environment runs glibc 2.31. The ABI test still passed when that temporary library directory was on the process loader path. The loader rejected CNRT and the plugin continued to reject context creation.
- CMake and NVCC were unavailable in this session. The default `device-abi-build` target also has a pre-existing stale CANN path under `backend/cann/`. The MLU target is independent of that build.

## Hardware validation blockers

A compatible, loadable CNRT and a visible MLU driver and device are required. This foundation performs loader detection and exposes unavailable behavior. Real CNRT initialization, device memory transfers, synchronization, and Vector Add still need to be implemented and verified before hardware support can be claimed. The branch that reports a loadable CNRT library has yet to run with a compatible vendor runtime.
