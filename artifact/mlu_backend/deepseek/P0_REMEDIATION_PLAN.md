# NeurX MLU P0 remediation plan

Prepared 2026-11-21 for review. Target is eight Cambricon MLU590-M9 devices with host driver 6.5.52. The plan leaves production drivers and system glibc in place. Package acquisition or environment changes follow review.

## 1. Establish device access

### Post-review read-only comparison, 2026-11-21

| Check | Actual host | Sandboxed NeurX workspace process |
| --- | --- | --- |
| Identity and mount namespace | UID/GID 1001, supplementary groups sudo and docker, mount namespace `4026531841`. PID 1 is systemd. | UID/GID 1001, supplementary group nogroup, mount namespace `4026552919`, shared with the visible Codex PID 1. |
| Effective `/dev` | udev devtmpfs mounted `rw,nosuid,noexec`. | A private tmpfs mounted `rw,nosuid,nodev` covers the underlying udev devtmpfs. The underlying mount is also flagged `nodev` in this view. |
| Cambricon nodes and permissions | `cambricon_ctl` (509:0) and `cambricon_dev0` through `cambricon_dev7` (508:0–7) are character devices, all root:root mode 0666. Read and write permission checks passed for UID 1001. | All nine nodes are absent. The corresponding kernel registrations are still visible in sysfs. |
| Cgroups | The devices controller is at `/user.slice` with `devices.list` reporting `a *:* rwm`. The session is `session-10607.scope`. | Same devices controller path, device rule and session scope. |
| Driver | All eight PCI functions bind to `cambricon-pci-drv_s1m1`. Module version 6.5.52. | Same PCI bindings and module version. |
| `cnmon info` | Exit 0. All eight MLU590-M9 cards reported Good, Driver Running and Initialized On. CNMON reports driver v6.5.52 and its firmware field as v1.3.1. vLLM workers were visible on the cards. | Exit 255, `cndev init failed: CNDEV_ERROR_NO_DRIVER.` |

The host CNDEV gate passed. The NeurX environment gate remains blocked at its mount namespace's private, `nodev` device view. The matching cgroup rules and host node modes rule out those two differences as the cause of the observed missing nodes. Host CNDEV initialization does not establish CNRT compatibility or device compute acceptance.

Reproduction used `id`, `readlink /proc/self/ns/mnt`, `findmnt -T /dev`, the `/dev` entries in `/proc/self/mountinfo`, `/proc/self/cgroup`, the devices controller's `devices.list`, `lspci -nnk -d cabc:`, `/sys/class/cambricon/*/dev`, `stat` and read/write permission checks on the nine nodes, and `cnmon info` with its exit code. Namespace IDs and device major/minor numbers are observations from this session.

### Minimal remediation proposal

Have the environment owner provide a dedicated NeurX execution context with one explicitly allocated card and its vendor-required control nodes. Use its supported device mapping mechanism so the mapped character nodes can be opened. Keep the assignment scoped to that card and leave the current vLLM workloads undisturbed. Repeat the node, permission, cgroup and `cnmon info` checks as the intended NeurX identity. Expand to more cards only after allocation and single-card acceptance.

No device mappings, containers, drivers or packages were changed. Continue with the CNRT probe only after both device access and SDK compatibility are verified. GEMM remains gated on successful CNRT execution.

### Dedicated MLU 0 configuration for review

**Deployment gate BLOCKED.** Host `tza-0a09-ai01-em9` runs Docker 24.0.7 with `runc` and cgroup v1 (`cgroupfs`). Read-only Docker inspection found `ta-mlu-team1` already mapped to cards 0–3, their IPCM nodes, and the shared control node. `ta-mlu-team2` maps cards 4–7. The existing `glm53_serve` container is privileged. Host `cnmon info` again exited 0, and card 0 reported active vLLM workers, including one using 93,556 MiB. MLU 0 cannot be treated as exclusively allocated to NeurX. Review approval and confirmation of exclusive allocation by the workload owner are separate prerequisites. A momentary idle sample cannot establish reservation or loss of access by another workload.

| Host node | Decimal device number | Host mode | Proposed access and evidence |
| --- | --- | --- | --- |
| `/dev/cambricon_ctl` | 509:0 | 0666 root:root | Same path in container, `rw`. A fresh host trace showed `cnmon info` opening it with `O_WRONLY`. It is shared and may expose host-wide management telemetry. |
| `/dev/cambricon_dev0` | 508:0 | 0666 root:root | Same path, `rw`. Card 0 compute node. |
| `/dev/cambricon_ipcm0` | 505:0 | 0666 root:root | Same path, `rw`. Card 0 IPC companion observed in the host's nonprivileged per-card configuration. Its necessity for the selected CNRT build is pending runtime verification. |

This is the proposed allowlist. The exact CNRT-required subset is unverified until a compatible build can run. The host CNMON trace showed successful control-node access and unsuccessful VF probes. It provides no proof that CNMON output is restricted to the mapped card. Validate isolation with the container's device inventory and effective device policy, then verify that CNRT reports exactly one usable compute device. Keep GDR, VF nodes, and devices for cards 1–7 outside the mapping.

Proposed command for review only. `NEURX_IMAGE` must be a reviewed, digest-pinned amd64 image with a compatible CNDEV and CNRT userspace. This proposal does not change the Codex sandbox or any existing container.

```sh
docker run --rm --name neurx-mlu0-p0 --runtime=runc \
  --user 1001:1001 --cap-drop=ALL --security-opt=no-new-privileges \
  --network=none --read-only --tmpfs /tmp:rw,nosuid,nodev,mode=1777 \
  --device=/dev/cambricon_ctl:/dev/cambricon_ctl:rw \
  --device=/dev/cambricon_dev0:/dev/cambricon_dev0:rw \
  --device=/dev/cambricon_ipcm0:/dev/cambricon_ipcm0:rw \
  --mount type=bind,src=/app/shuwen/neurx,dst=/workspace/neurx,readonly \
  --workdir /workspace/neurx --entrypoint /bin/sh \
  "${NEURX_IMAGE:?set the reviewed digest-pinned image}" -c 'id; ls -l /dev/cambricon*; cnmon info'
```

Keep default seccomp and host security policy. Confirm ownership and modes inside the container. Root-owned mode 0666 nodes are readable and writable by UID/GID 1001. The proposed device rules allow read/write without granting mknod. Use a separately reviewed invocation with the same device scope for the CNRT probe. Record the effective cgroup allowlist, check that other compute and IPC nodes are absent and inaccessible, and confirm that CNRT selects the allocated card, completes the byte-exact round trip, synchronizes, and cleans up. If the SDK requires another node or permission, capture the failing call and return to review with the narrow requirement. CNRT linking and CNNL availability remain separate open gates.

**Rollback.** The diagnostic invocation exits and Docker removes the dedicated container and its ephemeral device mappings. If interrupted, inspect the name and configuration to verify that it is the dedicated test container, then stop only `neurx-mlu0-p0`. Remove that container if it remains and release the allocation through the workload owner after cleanup. The workspace mount is read-only. No production container, host node, driver, package or persistent runtime configuration changes are required.

## 2. Select a compatible SDK

| Dependency | Verified evidence | Candidate or required check |
| --- | --- | --- |
| Kernel driver and firmware | Module 6.5.52. The procfs MLU firmware field reports 6.5.52. CNMON labels its firmware field v1.3.1. Installed driver package is `6.5.52-30.ubuntu20.04`. | Retain this version. Obtain an explicit vendor or platform-owner compatibility statement for the selected userspace. |
| Userspace | Ubuntu 20.04.6 amd64 with glibc 2.31. Installed CNDev is `3.12.4-1.ubuntu20.04`. | Prefer a Focal userspace SDK confirmed for MLU590-M9 and driver 6.5.52. |
| CNToolkit, CNRT and CNDrv | Cached CNToolkit 3.13.6 components include CNRT `6.12.1-1.ubuntu22.04` and CNDrv `2.13.2-1.ubuntu22.04`. Both require libc6 ≥ 2.34. CNRT linkage and loading failed locally. | Obtain matching Focal component versions from a single approved manifest. The vendor's public CNToolkit 3.8.4 Focal material is a lead. Its exact pairing with driver 6.5.52 is unverified. |
| CNNL | Headers and libraries were absent in the inspected SDK paths and cache. Cambricon lists MLU590 support for CNNL 1.14–1.18 on x86-64. The public Focal index lists `cnnl_1.16.1-1.ubuntu20.04_amd64.deb` under MLU370. | Treat that package as a candidate for metadata inspection. Require confirmation of the exact MLU590-M9, CNRT/CNDrv and driver pairing. Verify the chosen matmul API, stored FP16 and BF16 inputs, accumulator mode, output type and stride support separately. The 1.20 release notes list BF16 support added to `cnnlMatMul_v2`. |
| CNCC/CNAS | Cached CNCC `4.13.3-1.ubuntu22.04` requires libc6 ≥ 2.34 and libstdc++6 ≥ 12. CNCC is absent from PATH. The vendor guide lists `mtp_592` for MLU590. | Pin CNCC and CNAS with the SDK if building BANG kernels. For a host C CNNL client, verify the actual application link dependencies and the selected package manifest. |

No complete SDK tuple is verified for the exact current driver. The primary route is an approved Focal bundle extracted into a workspace-local SDK prefix after review. A second route is an approved Ubuntu 22.04 execution image with assigned MLU devices and a matching vendor bundle explicitly supported against the existing host driver. Either route preserves host glibc. The isolated image route requires platform approval and its own runtime acceptance.

Before selecting a bundle, record exact file names, versions, vendor checksums, package dependency metadata and the driver compatibility reference. Inspect ELF dependencies and symbol versions for CNRT, CNDrv, CNNL and their transitive libraries with `readelf -d` and `readelf --version-info`. Verify that the intended loader resolves the bundle consistently. Extract verified userspace packages after review and use their headers and libraries only within the test process. Confirm link and load success before attempting device calls.

[Cambricon Focal package index](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/) · [CNToolkit Focal documentation](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html) · [CNCC target table](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html) · [CNNL platform and release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html)

## 3. Accept minimal CNRT execution

Use the existing `test/contract/mlu_cnrt_runtime_test.c` from the intended process environment. For an approved bundle with a Neuware-style prefix, run from the repository root with `sdk` set to that prefix.

```sh
build="$PWD/artifact/build/mlu_p0_acceptance"
mkdir -p "$build"
cc -std=c11 -Wall -Wextra -Werror -I"$sdk/include" \
  test/contract/mlu_cnrt_runtime_test.c \
  -L"$sdk/lib64" -Wl,-rpath-link,"$sdk/lib64" -lcnrt -o "$build/cnrt_runtime_test"
LD_LIBRARY_PATH="$sdk/lib64" "$build/cnrt_runtime_test"
```

Record resolved libraries, CNRT version, assigned device count, properties and every CNRT status. Require successful selection, allocation, byte-exact 4 KiB H2D/D2H transfer, queue synchronization, and cleanup on each assigned device. Start with one card and repeat on all eight once assigned. The current probe uses synchronous copies and separately checks queue synchronization.

## 4. Implement standalone native GEMM

After the runtime gate passes, build a standalone CNNL test against the verified headers. Select the vendor matmul API from the pinned release and verify the chosen algorithm's type and accumulator contract. Use explicit row-major M/N/K and leading dimensions. Cover packed and padded layouts where the API supports them. Bind the handle to the selected queue, manage workspace with deterministic cleanup and retain vendor error codes. Run FP16 first, then BF16 if the hardware, selected SDK and algorithm support it. Return an explicit unsupported status for unavailable modes.

## 5. Validate accuracy and performance

Compare real device output with the independent FP32 reference for square sizes 128, 256, 512 and 1024, rectangular and padded cases, and transformer shapes such as M=128, N=2048, K=2048 and M=128, N=1408, K=2048. Include boundary values and inputs that reflect storage rounding. Set dtype-specific tolerances before the run. Report maximum and mean absolute and relative error, the denominator rule near zero, mismatches and nonfinite outputs.

Use warmups, repeated samples and a synchronized device timing mechanism. Report median and tail kernel latency, H2D and D2H separately, and synchronized end-to-end latency. Compute TFLOPS from `2*M*N*K` divided by kernel seconds and `10^12`. Report tensor and workspace bytes and any measured device memory delta separately. Record device, algorithm, dtype, dimensions, strides, iterations and SDK versions.

## 6. Integrate with NeurX and verify inference

The existing MLU Device ABI plugin returns unavailability from execution callbacks. Device exposure and an SDK alone cannot enable this implementation. After standalone acceptance, implement native context, buffer, stream and operation lifecycle in the MLU plugin and connect the accepted GEMM path. Preserve original CNRT/CNNL codes and explicit failures without CPU fallback. Run the focused MLU contract, repeated and multi-device execution, invalid-input tests, partial-failure cleanup and applicable NeurX regressions. Track the missing CANN source that currently blocks the broader Device ABI probe separately.

DeepSeek inference then requires a complete checkpoint and a verified MLA/MoE execution path. Validate generated tokens against a trusted reference and capture evidence that the NeurX process used real MLU kernels.

## Verification status

| Stage | Status |
| --- | --- |
| Implemented | Standalone CNRT probe exists. Native runtime and GEMM integration are pending. |
| Compiled | Earlier acceptance compiled the probe to an object against cached headers. Linking failed on GLIBC_2.34 requirements. |
| CPU-tested | Earlier acceptance passed the MLU unavailability contract and 20 FP16/BF16 CPU reference cases. |
| Hardware-tested | Host CNDEV initialization passed on eight cards. No successful CNRT operation, GEMM kernel or inference run. |
| Performance-validated | Pending device execution. No MLU timing or throughput data. |

Only this plan was edited during the post-review comparison. The pre-existing acceptance report and probe were preserved. See the [acceptance report](P0_ACCEPTANCE_REPORT.md) for previous commands and results.
