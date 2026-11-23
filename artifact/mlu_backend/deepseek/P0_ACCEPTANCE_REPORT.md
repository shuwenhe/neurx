# NeurX MLU P0 acceptance

## Remediation plan

1. Reproduce the failure from the NeurX process. Compare PCI inventory, device nodes, driver status, installed SDK and loader errors.
2. Build an independent CNRT smoke test against the vendor header. Require device selection, properties, queue creation, a byte-exact device memory round trip, synchronization and successful cleanup on every visible device.
3. On a process with working device access and a compatible CNRT/CNNL SDK, pass the standalone runtime gate, then verify NeurX Device ABI runtime calls and original vendor error propagation.
4. Validate native FP16 and supported BF16 GEMM against the FP32 reference over the requested square, rectangular and transformer shapes. Record errors, device kernel and transfer timings, throughput and memory usage. Integrate after the standalone GEMM passes, then repeat across available devices and exercise failure cleanup.

## Result

**Overall P0 BLOCKED. P0-A and P0-B are both blocked.**

| Gate | Evidence |
| --- | --- |
| P0-A device access | PCI and the driver inventory expose eight MLU590-M9 records. This process has no `/dev/cambricon*` nodes. `cnmon info` exits 255 with `cndev init failed: CNDEV_ERROR_NO_DRIVER.` The upstream device assignment or mount configuration could not be inspected from this process. |
| P0-A runtime compatibility | Ubuntu 20.04.6 amd64, glibc 2.31, driver and firmware 6.5.52. The installed Neuware prefix contains CNDev 3.12.4. The cached CNRT 6.12.1 Ubuntu 22.04 library fails to load and link because it requires `GLIBC_2.34`. No CNRT function ran, so there are no vendor runtime return codes from this environment. |
| P0-A NeurX integration | Device ABI v1 currently rejects MLU execution callbacks. Its opt-in CNRT diagnostic can enumerate but does not expose an execution path. The fresh unavailability contract passed. Device initialization, allocation, transfers, synchronization and cleanup through NeurX remain unverified. |
| P0-B GEMM | No CNNL header or library was found in the installed Neuware prefix, inspected toolkit cache or workspace build artifacts. Native GEMM implementation and integration remain pending. No kernel launches, native numerical comparisons, latency, transfer timings, TFLOPS or device memory measurements were obtained. |
| CPU reference | The existing FP16/BF16 fixture passed all 20 cases against its independent oracle, including rectangular and padded layouts. Maximum absolute, maximum relative and mean absolute errors were zero. This is CPU fixture evidence. |
| Other regression | The broader Device ABI probe target exited 2 because its CANN dependency `backend/cann/device_abi_cann.cpp` is missing. The full NeurX suite was not run. |

## Files changed

- `test/contract/mlu_cnrt_runtime_test.c` adds a standalone diagnostic that reports CNRT codes and errors, selects every visible device, reads its properties, tests a 4 KiB synchronous H2D/D2H round trip, synchronizes a queue and checks cleanup. It has no CPU fallback. It compiled to an object against the cached header. The test binary did not link locally.
- `artifact/mlu_backend/deepseek/P0_ACCEPTANCE_REPORT.md` records the plan and verification evidence. Production backend code was not changed.

## Reproduction

Run from the NeurX root.

```sh
lspci -nn -d cabc:
cat /sys/module/cambricon_drv/version
grep -hE 'Device name:|MLU Firmware Version:' /proc/driver/cambricon/mlus/*/information | sort | uniq -c
ls -l /dev/cambricon*
cnmon info
getconf GNU_LIBC_VERSION
ls /usr/local/neuware/include /usr/local/neuware/lib64
ldconfig -p | grep -Ei 'cnrt|cndrv|cnnl|cncl|cndev'

sdk="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware"
python3 -S -c 'import ctypes,sys; ctypes.CDLL(sys.argv[1])' "$sdk/lib64/libcnrt.so"
cc -std=c11 -Wall -Wextra -Werror -I"$sdk/include" -c \
  test/contract/mlu_cnrt_runtime_test.c -o artifact/build/mlu_p0/mlu_cnrt_runtime_test.o
cc artifact/build/mlu_p0/mlu_cnrt_runtime_test.o -L"$sdk/lib64" -lcnrt \
  -o artifact/build/mlu_p0/mlu_cnrt_runtime_test

make device-abi-mlu-test DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_p0_acceptance_abi"
make device-abi-probe-test DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_p0_acceptance_abi"
cc -std=c11 -O2 -Wall -Wextra -Werror -ffp-contract=off \
  test/contract/mlu_gemm_cpu_validation.c -lm -o artifact/build/mlu_p0/mlu_gemm_cpu_validation
artifact/build/mlu_p0/mlu_gemm_cpu_validation
```

For hardware acceptance, repeat the compile and link commands with `sdk` set to the compatible SDK in an environment where the devices are assigned to the NeurX process. Run the probe with that SDK's libraries on the loader path.

```sh
LD_LIBRARY_PATH="$sdk/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  artifact/build/mlu_p0/mlu_cnrt_runtime_test
```

Genuine P0 acceptance still requires NeurX runtime integration and native FP16 and supported BF16 kernels on the assigned devices. Repeated execution, multi-device coverage and failure cleanup through NeurX remain pending.
