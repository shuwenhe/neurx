# Build and test results

All commands were run from `/app/shuwen/neurx`. Build products and fixtures are under the repository's ignored `artifact/build`.

| Command or check | Exit | Result |
| --- | ---: | --- |
| `make DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_boundary/default" device-abi-mlu-test` before the fix | 2 | Regression test rejected the former S boundary. |
| Same command after the fix | 0 | Built S IR, the S shared library, the C adapter and registry, and passed the ABI test. |
| `make device-abi-mlu-test` | 0 | Exact requested target passed. It exercised local shared-library loading, ABI version and layout, every callback, null arguments, invalid handles, CNRT unavailability, C/S symbol resolution, and registry diagnostics. |
| Direct test with missing CNRT | 0 | Explicit missing-library diagnostic. |
| Direct test with a generic loader-only shared object | 0 | Loadable-library diagnostic, zero device availability and no retained loader reference. |
| Registry with malformed version and size fixtures | 0 | Registry rejected v2 and undersized v1 tables. |
| `make device-abi-contract-test` | 2 | Existing IR runner link omitted libdl and failed to resolve `dlsym`. |
| Same target with an audit-local compiler wrapper that appends `-ldl` | 2 | Runner linked. Existing S test compilation rejected an index expression at 17:22 because its inferred type was `any`. |
| `make collective-abi-test` | 0 | Expected NCCL-unavailable behavior. |
| Sanitizer build before disabling leak detection | 2 | The test assertions passed. LeakSanitizer could not run in this execution environment. |
| Sanitizer build with `ASAN_OPTIONS=detect_leaks=0` | 0 | ASan and UBSan passed for the C adapter, C++ registry and test. The externally generated S companion was not sanitizer-instrumented. |
| `make hf-decoder-cpu-parity-test PYTORCH_PYTHON=python3` | 2 | Existing target refers to missing `test/hf_decoder_cpu_probe.cpp` and `src/runtime/model/decoder_cpu.cpp`. |
| Direct compile of existing CPU Transformer contract | 1 | S compiler rejected `src/model/formats/safetensors_embedding.s:47` with `for condition expects bool/int`. |
| Focused S CPU, CUDA and CANN capability regression | 0 | Existing backend names, capability flags, and collective mappings passed. |
| `make DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_boundary/default" device-abi-probe-test` | 2 | Existing target points to the absent `backend/cann/device_abi_cann.cpp`. Full vendor regression remains blocked. NVCC and system CUDA and Ascend SDK paths were also absent. |
| `command -v cmake` | 1 | **BLOCKED**. Standalone CMake build was not run. |
| `cnmon info` | 255 | `CNDEV_ERROR_NO_DRIVER`. |
| `git diff --check` | 0 | Passed. |

## Command details

```sh
b="$PWD/artifact/build/mlu_boundary"
out="$PWD/artifact/build/device_abi"
seed=/app/shuwen/s/bin/s_seed

make device-abi-mlu-test
"$seed" backend/platform/mlu/device_abi_mlu.s "$out/device_abi_mlu.ir"
S_SOURCE_ROOT=/app/shuwen/s "$seed" --emit-shared "$out/device_abi_mlu.ir" "$out/libneurx_mlu_s.so"

NEURX_BACKEND_PLUGIN_DIR="$out" "$out/device_abi_mlu_unavailable_test" \
  "$out/libneurx_backend_mlu.so" 'could not load libcnrt.so'
LD_LIBRARY_PATH="$b/loader-fixture" NEURX_BACKEND_PLUGIN_DIR="$out" \
  "$out/device_abi_mlu_unavailable_test" "$out/libneurx_backend_mlu.so" 'CNRT library is loadable'

ASAN_OPTIONS=detect_leaks=0 make DEVICE_ABI_BUILD_DIR="$b/sanitized" \
  CC='gcc -fsanitize=address,undefined' \
  CXX='g++ -fsanitize=address,undefined -fno-omit-frame-pointer' device-abi-mlu-test

"$seed" --compile-native-unit "$b/cpu/cpu.ir" src/model/formats/safetensors_embedding.s \
  backend/platform/cpu/transformer_decode.s test/contract/cpu_transformer_test.s
"$seed" --compile-native-unit "$b/cpu_capability.ir" src/runtime/device/device_abi.s "$b/cpu_capability.s"
S_SOURCE_ROOT=/app/shuwen/s "$seed" --emit-hosted-program "$b/cpu_capability.ir" "$b/cpu_capability"
"$b/cpu_capability"

make device-abi-contract-test
printf '%s\n' '#!/bin/sh' 'exec gcc "$@" -ldl' > "$b/cc-libdl"
chmod +x "$b/cc-libdl"
make CC="$b/cc-libdl" S_RUNNER_BUILD_DIR="$b/abi-runner" \
  S_RUNNER_BIN="$b/abi-runner/NeurX" device-abi-contract-test

readelf -d "$out/libneurx_backend_mlu.so"
git diff --check
```

The two S build commands above are also the recipe used by Make with absolute output paths. The registry negative test compiled two fixtures with `cc -x c -Ibackend/api -shared -fPIC`, then used `NEURX_BACKEND_PLUGIN_DIR="$b/default" python3 - "$b/default/libneurx_device.so"` to call the public probe and error APIs. It checked that both malformed tables produced the registry's invalid-plugin diagnostic. The loader fixture was compiled with `cc -x c -fPIC -shared -o "$b/loader-fixture/libcnrt.so" -` from an inert marker function.
