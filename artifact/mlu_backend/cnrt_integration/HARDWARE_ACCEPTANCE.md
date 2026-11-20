# Hardware acceptance

| Gate | Status | Evidence required or obtained |
| --- | --- | --- |
| 1. CNRT and required symbols resolve | **BLOCKED** | Real CNRT exports the required symbols in its ELF table. Runtime load failed with `GLIBC_2.34 not found`. A loadable marker DSO correctly failed symbol validation. |
| 2. CNRT initializes | **BLOCKED** | This SDK exposes implicit runtime initialization through runtime calls, with no standalone `cnrtInit`. Record a successful real initialization-bearing call and its return code in the compatible environment. |
| 3. Device enumeration succeeds | **BLOCKED** | Record a successful real `cnrtGetDeviceCount` call and positive count. The eight kernel records establish host inventory only. |
| 4. Allocate and release | **NOT RUN** | Select an allocated device, call `cnrtMalloc` and `cnrtFree`, and capture the return statuses. |
| 5. H2D, D2H and synchronization | **NOT RUN** | Record both copy directions, synchronization, and byte-for-byte round-trip evidence. |
| 6. Vector Add kernel | **NOT RUN** | Compile a real FP32 BANG C kernel for MLU590, dispatch it through an SDK-supported launch path, and record launch and synchronization results. |
| 7. CPU reference | **NOT RUN** | Compare every result with a CPU FP32 reference. Proposed tolerance is `abs(actual - expected) <= 1e-6 + 1e-6 * abs(expected)`. Reject non-finite results and record maximum absolute error and mismatch count. |

No hardware gate passed in this session. Rerun gates in order in a device-assigned environment with compatible Neuware. Preserve the runtime/driver versions, commands, exit codes, device ordinal, data sizes and numerical results. Plugin load and offline symbol inspection supply boundary evidence only.

## Dedicated enumeration probe

After building with the matching SDK headers, run the following in the device-assigned environment with the vendor runtime on the process loader path. The program exits zero only for a successful CNRT call with a positive count. It still does not exercise device selection or memory.

```sh
python3 - "$PWD/artifact/build/cnrt_integration/with-sdk/libneurx_backend_mlu.so" <<'PY'
import ctypes as c
import sys

plugin = c.CDLL(sys.argv[1])
diagnose = plugin.neurx_mlu_cnrt_diagnose
diagnose.argtypes = [c.POINTER(c.c_uint), c.POINTER(c.c_uint32)]
diagnose.restype = c.c_int
count, vendor = c.c_uint(), c.c_uint32()
status = diagnose(c.byref(count), c.byref(vendor))
print(f"diagnostic={status} count={count.value} vendor_status={vendor.value}")
sys.exit(0 if status == 6 and count.value > 0 and vendor.value == 0 else 1)
PY
```
