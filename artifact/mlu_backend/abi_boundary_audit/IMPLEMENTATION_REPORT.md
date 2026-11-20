# MLU Device ABI v1 boundary hardening report

The hardened plugin preserves the Device ABI v1 header, table, and registry contract. It eliminates the truncated loader-pointer round trip through the hosted S FFI. C performs typed POSIX loader transport and ABI conversion. S classifies the loader observation and owns availability and operation rejection. This report supersedes the boundary description in the original MLU implementation report.

## Modified files

| File | Change |
| --- | --- |
| `backend/platform/mlu/device_abi_mlu.c` | Keeps the POSIX loader pointer in C, balances the loader reference, serializes adapter entry into the S interpreter, and validates S output before returning ABI statuses. |
| `backend/platform/mlu/device_abi_mlu.s` | Removes pointer-bearing FFI calls and classifies integer loader observations. |
| `backend/platform/mlu/CMakeLists.txt` | Links POSIX loader and thread dependencies. |
| `makefile` | Links those dependencies in the MLU plugin recipe. |
| `test/contract/device_abi_mlu_unavailable_test.cpp` | Pins the v1 LP64 layout and validates callback rejection, signed widths, loader cleanup, and registry error propagation. |
| `artifact/mlu_backend/abi_boundary_audit/` | Adds the six audit deliverables, including exact build and test commands and exit codes. |

## Acceptance gates

| Gate | Result |
| --- | --- |
| ABI v1 compatibility | **PASS** on Linux x86-64. Shared header, 120-byte layout, 8-byte alignment, all field offsets and all callback slots verified. |
| C/S boundary | **PASS** for the unavailable contract. Signed scalar transport, C pointer isolation, and typed loader cleanup verified. |
| Registry loading | **PASS**. Valid MLU plugin loaded. Unsupported version and undersized table rejected. |
| Missing CNRT | **PASS**. Explicit unavailable diagnostic and no context or buffer handles. |
| CPU, CUDA and CANN regression | **PARTIAL**. Focused capability metadata passed. Existing CPU model and vendor targets are blocked by build errors or unavailable tooling. See [test results](TEST_RESULTS.md). |
| Real MLU execution | **BLOCKED**. No visible MLU device or driver and no loadable compatible CNRT in this environment. Cached CNRT requires glibc 2.34 and the host has 2.31. |

CMake and leak-sanitizer coverage remain blocked. The loadable-library test exercised POSIX loading and unloading with a generic shared object. Real CNRT initialization, memory transfers, synchronization, and Vector Add remain unverified. No changes were made to the S checkout, ABI headers, other backend implementations, or system configuration during the audit.
