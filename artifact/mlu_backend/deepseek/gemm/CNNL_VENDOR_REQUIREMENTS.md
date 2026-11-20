# CNNL vendor requirements

**SDK_COMPATIBILITY_PASS: blocked.** Reviewed the existing [SDK gate](../CNNL_SDK_COMPATIBILITY.md), [runtime acceptance](../MLU_RUNTIME_ACCEPTANCE.md) and [native implementation readiness](../GEMM_NATIVE_IMPLEMENTATION.md). Rechecked the approved header inputs and critical runtime conditions. No new package was installed or loaded. The environment still provides glibc 2.31 and driver module 6.5.52, with no visible Cambricon device nodes.

| Component | Evidence and missing dependency |
| --- | --- |
| CNRT | No approved native Focal library or matching target header. Cached Ubuntu 22.04 CNRT 6.12.1 needs GLIBC_2.34. Its staged header provides API evidence only. |
| CNDrv userspace | Matching Focal userspace package and exact firmware/driver compatibility confirmation are needed. Cached Ubuntu 22.04 CNDrv is incompatible. |
| CNCC | Not on PATH. Need official Focal compiler with `mtp_592` support and the matching BANG headers and libraries. Cached 4.13.3 Ubuntu 22.04 is excluded. |
| CNNL | No approved target header/library. Need the exact matmul API family and descriptor/algorithm/workspace contract, including an explicit guarantee of FP32 accumulation with BF16 or FP16 storage and FP32 output on MLU590-M9. |
| CNCL | No usable library/header was established. Needed for later multi-card work after single-card acceptance. |
| CNDev | Installed 3.12.4 Focal. Vendor telemetry remains unverified in this namespace. |
| CNMon | Installed with driver package 6.5.52. Prior native acceptance reproduced `CNDEV_ERROR_NO_DRIVER` with no device nodes. |

Cambricon documents native Ubuntu 20.04 installation and MLU590-M9 compiler targeting in CNToolkit 3.8.4. CNNL v1.20.0 notes identify BF16 support for `cnnlMatMul_v2`. The v1.23.0 notes separately describe FP32 off-chip output with BF16 or Half on-chip input for `cnnlMatMul`. None of those statements establishes the exact Focal package combination for driver and firmware 6.5.52, stored input dtype, FP32 accumulation, and FP32 output on the board. Obtain the official tuple and a release-specific capability table before implementation.

- [Cambricon native package guide](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html)
- [Cambricon MLU590-M9 compiler targets](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)
- [Cambricon CNNL support and release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html)

Required vendor evidence is exact Focal package versions and checksums, ELF compatibility on glibc 2.31, board/firmware/driver compatibility, header prototypes, storage and accumulation dtypes, layout/stride constraints, queue and workspace lifetimes, and accepted tail shapes. Native verification also requires administrator-approved access to the actual node set. [Existing administrator checklist](../../native_deployment/diagnosis/ADMIN_ACTIONS.md)
