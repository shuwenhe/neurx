# Native MLU590-M9 execution status

**BLOCKED at hardware access and SDK compatibility.** The kernel enumerates eight driver-bound devices with driver and firmware 6.5.52. The NeurX session sees none of the device character nodes and CNDev initialization fails. The cached CNRT package's GLIBC_2.34 requirement is incompatible with the native glibc 2.31 environment. An approved native replacement package tuple was not established.

| Phase | Result |
| --- | --- |
| PCI inventory and installed driver | Confirmed |
| Device access and CNDev initialization | Blocked |
| Approved native Neuware and CNRT initialization | Blocked |
| Native context, memory, stream and copy operations | Not run |
| Native GEMM and DeepSeek operators | Not run |
| Numerical and performance acceptance | Not run |

Execution stopped at these prerequisites. Earlier Phase 2 changes were preserved. This turn did not run any CPU operator or fallback, substitute backend, or simulated MLU workload. No system libraries, drivers, S checkout or workloads were changed. Only these seven reports were added. `git diff --check` exited 0.

[Device access](DEVICE_ACCESS.md) · [SDK compatibility](NEUWARE_COMPATIBILITY.md) · [CNRT initialization](CNRT_INITIALIZATION.md) · [Native GEMM](NATIVE_GEMM_IMPLEMENTATION.md) · [Numerical results](GEMM_NUMERICAL_RESULTS.md) · [Performance results](GEMM_PERFORMANCE_RESULTS.md)

## Recovery update

**CONFIRMED** PCI binding, kernel inventory and driver/firmware 6.5.52. **BLOCKED** on device exposure and SDK compatibility. **UNKNOWN** host-side node presence and approved Focal package tuple. **NOT_TESTED** CNRT initialization, native Vector Add and BF16 GEMM. No substitute backend, simulation or CPU operator was run in this recovery phase. No package, driver, runtime code or checkpoint changed.

Build compatibility was reviewed separately using the existing Phase 2 ABI artifacts. Seed's shared object exports the named signed 64-bit scalar probe and `s_abi_last_error`. The recorded Stage4 direct shared export attempt exited 2, and the object path with the Seed-style named export exited 1 at parsing. An ordinary Stage4 object could link into a DSO but exposes generated `s_native_*` symbols instead of the named C export. The installed compiler reports revision `9cb73e41a68cb045bf9be6e5c018071e6f1f38aa`. Keep the existing Seed build path until independent Stage4 interoperability acceptance. This is software ABI evidence only.

[Administrator actions](ADMIN_ACTIONS.md) · [Vendor request](CAMBRICON_SDK_REQUEST.md) · [Vector Add acceptance](VECTOR_ADD_ACCEPTANCE.md)
