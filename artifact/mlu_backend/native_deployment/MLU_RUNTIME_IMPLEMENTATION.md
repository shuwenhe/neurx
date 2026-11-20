# MLU runtime implementation status

Reviewed the existing MLU S and C sources, v1 ABI header, registry, S device runtime, six boundary-audit reports and five CNRT integration reports. Existing files and uncommitted work were preserved. The audit made no runtime source changes.

| Area | Current state |
| --- | --- |
| Device ABI v1 registration | Implemented and unit-tested. The registry loads the shared object and validates ABI metadata. |
| S-first MLU policy | Implemented and unit-tested. Availability stays zero and hardware callbacks reject requests. |
| Typed native boundary | Implemented and unit-tested. C retains the loader and vendor pointers. S receives signed scalar observations. |
| Optional CNRT enumeration | Implemented and compiled against the cached official 6.12.1 header. Vendor runtime linking and execution remain blocked. The diagnostic resolves enumeration and selection symbols and only calls enumeration when they resolve. |
| Physical device context, device allocation and release, H2D/D2H/D2D, queues and synchronization | Blocked pending a compatible SDK and an assigned device. No production hardware implementation added in this phase. |

The next implementation phase begins when the vendor tuple and device assignment are verified. S should own lifecycle state, caller-facing handles, validation, ordering, and cleanup decisions. A typed C adapter should own native pointers, vendor call signatures and output-parameter storage. Public v1 handles stay integer identifiers. Define and test ownership of device, buffer and queue resources before enabling device availability. Return exact vendor failure codes through the established diagnostic path. Validate wrong-context handles, copy bounds and direction, cleanup after partially successful creation, and destruction ordering. The existing unavailable path remains the behavior for systems lacking a validated runtime.

## Reproduced checks

Run from the repository root.

```sh
make device-abi-mlu-test
make DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/cnrt_integration/with-sdk" \
  DEVICE_ABI_MLU_CNRT_INCLUDE="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware/include" \
  device-abi-mlu-test
LD_LIBRARY_PATH="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64" \
  python3 artifact/build/cnrt_integration/check_diagnostic.py \
  "$PWD/artifact/build/cnrt_integration/with-sdk/libneurx_backend_mlu.so" 0
git diff --check
```

Each command exited 0. Both contract runs printed `PASS: MLU Device ABI v1 unavailable contract`. The diagnostic printed `diagnostic=0 count=0 vendor_status=0`, the expected unloaded-runtime result. The zero vendor status is the initial output value and confirms no successful driver call.

Fresh output directories also passed. Both commands below exited 0 and compiled the S companion before running the ABI tests.

```sh
make DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_native_audit/default" device-abi-mlu-test
make DEVICE_ABI_BUILD_DIR="$PWD/artifact/build/mlu_native_audit/with-sdk" \
  DEVICE_ABI_MLU_CNRT_INCLUDE="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware/include" \
  device-abi-mlu-test
```
