# NeurX runtime test results

**UNIT_TESTED.** The existing Device ABI v1 plugin passed the focused tests. No runtime source changes were required for this diagnosis.

| Check | Exit | Output or coverage |
| --- | ---: | --- |
| `make device-abi-mlu-test` | 0 | `PASS: MLU Device ABI v1 unavailable contract`. Covers layout, version, callbacks, arguments, direct loading, registry loading and error propagation. |
| SDK-header build in a fresh directory | 0 | Built S IR, S companion and C adapter with cached official headers. Same contract passed. |
| Direct contract with no CNRT | 0 | Explicit unavailable diagnostic. |
| Direct contract with inert loader fixture | 0 | Loadable-library diagnostic and reference cleanup verified. No vendor calls. |
| Registry malformed table check | 0 | `PASS: bad_version` and `PASS: bad_size`. |
| Optional diagnostic against cached CNRT | 0 | Expected rejection, `diagnostic=0 count=0 vendor_status=0`. Actual loader failure is recorded separately and exited 1. |
| Optional diagnostic against loadable marker fixture | 0 | `diagnostic=3 count=0 vendor_status=0`. Required symbols rejected. |
| S CPU, CUDA and CANN capability metadata | 0 | Fresh S compile and hosted run printed `PASS: CPU, CUDA and CANN capability metadata`. |
| `command -v nvcc` and `ldconfig -p \| grep -Ei 'ascendcl\|cudart'` | 1 each | Vendor SDK/runtime tests **BLOCKED** in this session. Capability checks are software-only. |
| `git diff --check` | 0 | No whitespace errors in tracked changes. |

```sh
b="$PWD/artifact/build/mlu_native_diagnosis"
s="$PWD/artifact/build/cnrt_integration"
out="$PWD/artifact/build/device_abi"
fixture="$PWD/artifact/build/mlu_boundary/loader-fixture"
seed=/app/shuwen/s/bin/s_seed

make device-abi-mlu-test
make DEVICE_ABI_BUILD_DIR="$b/test" \
  DEVICE_ABI_MLU_CNRT_INCLUDE="$s/sdk/usr/local/neuware/include" device-abi-mlu-test
NEURX_BACKEND_PLUGIN_DIR="$out" "$out/device_abi_mlu_unavailable_test" \
  "$out/libneurx_backend_mlu.so" 'could not load libcnrt.so'
LD_LIBRARY_PATH="$fixture" NEURX_BACKEND_PLUGIN_DIR="$out" \
  "$out/device_abi_mlu_unavailable_test" "$out/libneurx_backend_mlu.so" 'CNRT library is loadable'
LD_LIBRARY_PATH="$s/sdk/usr/local/neuware/lib64" \
  python3 -S "$s/check_diagnostic.py" "$b/test/libneurx_backend_mlu.so" 0
LD_LIBRARY_PATH="$s/loader-only" \
  python3 -S "$s/check_diagnostic.py" "$b/test/libneurx_backend_mlu.so" 3

"$seed" --compile-native-unit "$b/capabilities.ir" src/runtime/device/device_abi.s \
  artifact/build/mlu_boundary/cpu_capability.s
S_SOURCE_ROOT=/app/shuwen/s "$seed" --emit-hosted-program "$b/capabilities.ir" "$b/capabilities"
"$b/capabilities"

r="$PWD/artifact/build/mlu_boundary/default"
NEURX_BACKEND_PLUGIN_DIR="$r" python3 -S - "$r/libneurx_device.so" <<'PY'
import ctypes,sys
r=ctypes.CDLL(sys.argv[1])
r.neurx_device_probe.argtypes=[ctypes.c_char_p]
r.neurx_device_last_error.restype=ctypes.c_char_p
for name in (b'bad_version',b'bad_size'):
    assert r.neurx_device_probe(name)==0
    assert b'invalid Device ABI plugin' in r.neurx_device_last_error(0)
    print('PASS:',name.decode())
PY
git diff --check
```

The test fixture objects and helper scripts are in the workspace's ignored build directories. A zero exit from the expected-rejection test verifies error handling. It supplies no hardware acceptance evidence.
