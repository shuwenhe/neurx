# CNRT integration report

Reviewed all six documents under [the ABI boundary audit](../abi_boundary_audit). The Device ABI v1 struct, registry entry, callback table, and resource behavior are preserved. The default build still needs no CNRT SDK.

| File | Change |
| --- | --- |
| `backend/platform/mlu/device_abi_mlu.c` | Adds an opt-in diagnostic export, typed against the vendor SDK. It resolves `cnrtGetDeviceCount` and `cnrtSetDevice` and calls only the enumeration entry. It keeps loader handles, function pointers, and output pointers in C. The diagnostic is intended for a dedicated process. |
| `backend/platform/mlu/device_abi_mlu.s` | Classifies scalar loader and enumeration outcomes, including count range and zero devices. Device availability and resource lifecycle policy remain in S. |
| `makefile` and `backend/platform/mlu/CMakeLists.txt` | Add an optional SDK include path. Use a separate Make output directory for the SDK-enabled build. |
| `artifact/mlu_backend/cnrt_integration/` | Adds the five requested audit and acceptance reports. |

The diagnostic returns 0 for absent or unloadable CNRT, 2 for release failure, 3 for a missing required symbol, 4 when enumeration reports a CNRT error, 5 for a successful zero count, and 6 for a successful positive count. Invalid arguments or boundary failure return -1. The two output values are the count and raw CNRT return code. Before a vendor call both outputs are zero. The private diagnostic result is distinct from the v1 probe, which continues to report zero availability. No vendor context, device memory, or queue handle is created by this phase. The SDK declares no standalone `cnrtInit`, so the documented device enumeration API is the first CNRT runtime call. Device selection is reserved for the next stage.

## Verification

```sh
b="$PWD/artifact/build/cnrt_integration"
make device-abi-mlu-test
make DEVICE_ABI_BUILD_DIR="$b/with-sdk" \
  DEVICE_ABI_MLU_CNRT_INCLUDE="$b/sdk/usr/local/neuware/include" device-abi-mlu-test
git diff --check
```

All three commands exited 0. Both Make builds generated the S companion and passed the focused ABI/registry unavailable test. CMake was unavailable.

The diagnostic's test helper under the ignored build directory invoked the exported function with typed `ctypes` arguments and checked its S classifier against zero, positive, out-of-range and negative counts. It also asserted rejection of a null output pointer. The following commands all exited 0.

```sh
p="$b/with-sdk/libneurx_backend_mlu.so"
python3 "$b/check_diagnostic.py" "$p" 0
LD_LIBRARY_PATH="$b/sdk/usr/local/neuware/lib64" python3 "$b/check_diagnostic.py" "$p" 0
LD_LIBRARY_PATH="$b/loader-only" python3 "$b/check_diagnostic.py" "$p" 3
```

The first two runs returned `diagnostic=0 count=0 vendor_status=0`. The third returned `diagnostic=3 count=0 vendor_status=0` using a generic test DSO with a single marker and zero vendor APIs. It exercised symbol rejection only. Neither the host nor the fixture executed a CNRT call. CPU, CUDA, CANN, the S checkout and system configuration were preserved.
