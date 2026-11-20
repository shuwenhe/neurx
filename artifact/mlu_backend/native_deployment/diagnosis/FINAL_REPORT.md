# Native MLU590 diagnosis final report

**BLOCKED.** Two independent blockers were reproduced. The current NeurX process sees zero MLU device nodes in its effective `/dev`, which is a `nodev` tmpfs over `devtmpfs`. The officially packaged cached CNRT 6.12.1 requests `GLIBC_2.34` and fails to load on Ubuntu 20.04 with glibc 2.31. Neither blocker was modified under the task's native, no-escalation constraints.

| Classification | Evidence |
| --- | --- |
| **CONFIRMED** | Eight PCI `cabc:0590` devices are bound to the Cambricon driver. Driver and firmware are 6.5.52. The device view and loader failure were measured in this session. |
| **UNKNOWN** | Actual node presence in the host administrator namespace, ownership and I/O permissions there, and the exact vendor-approved older native runtime tuple. |
| **IMPLEMENTED** | Existing S-first Device ABI v1 foundation with typed C boundary and optional CNRT diagnostic. No runtime code was changed for this phase. |
| **COMPILED** | SDK header build in a fresh directory, using the cached official 6.12.1 header. |
| **UNIT_TESTED** | ABI layout, callbacks, registry load and rejection, loader cleanup, unavailable diagnostics and CPU/CUDA/CANN metadata. |
| **BLOCKED** | Native SDK validation and all hardware acceptance gates. No CNRT initialization, device allocation, transfer, synchronization, Vector Add or CPU comparison was run. |

The administrator needs to compare the host and session device views and provide approved device exposure. An enterprise Cambricon manifest is required to establish a supported native Focal package tuple for the existing driver and firmware. No packages were installed. No substitute runtime, privilege escalation, driver changes, reboot, system-library changes or workload disruption were attempted. Existing repository changes and the S checkout were preserved.

[Device diagnosis](DEVICE_ACCESS_DIAGNOSIS.md) · [ELF and glibc analysis](CNRT_GLIBC_ANALYSIS.md) · [Native compatibility matrix](NEUWARE_COMPATIBILITY_MATRIX.md) · [Administrator actions](ADMIN_ACTIONS.md) · [Runtime tests](RUNTIME_TEST_RESULTS.md) · [Vector Add gates](VECTOR_ADD_ACCEPTANCE.md)
