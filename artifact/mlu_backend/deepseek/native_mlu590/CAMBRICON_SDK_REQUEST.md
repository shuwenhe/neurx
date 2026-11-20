# CAMBRICON_OFFICIAL_SUPPORT_REQUEST.md

**Prepared, unsent.**

No external message has been sent. Sending requires explicit user authorization.

## Subject

Official Focal native Neuware package set for 8 × MLU590-M9, driver 6.5.52 and firmware v1.3.1

## Environment

| Item | Exact value |
|---|---|
| Host | tza-0a09-ai01-em9 |
| Cards | 8 × MLU590-M9 |
| PCI vendor/device | `cabc:0590` |
| Subsystem | `cabc:8003` |
| Driver package | `cambricon-mlu-driver-dkms 6.5.52-30.ubuntu20.04` |
| Kernel module | `cambricon_drv 6.5.52` |
| Firmware | v1.3.1 |
| CNDev | 3.12.4-1.ubuntu20.04 |
| CNMon | 6.5.52 |
| OS | Ubuntu 20.04.6 LTS |
| Architecture | x86_64/amd64 |
| GLIBC | 2.31 |
| Kernel | 5.15.0-139-generic |

## Requested compatibility statement

Please identify the exact officially supported Neuware release for this combination and confirm whether a native package set exists for all components below.

1. CNToolkit/CNToolkit repository package version.
2. CNRT exact version.
3. CNCC exact version and BANG C compiler target for MLU590-M9, including `mtp_592` if applicable.
4. CNAS exact version.
5. CNNL exact version and supported MLU590 BF16/FP16 GEMM interfaces.
6. CNCL exact version and supported eight-card MLU-Link/PCIe communication.
7. CNDrv userspace exact version compatible with kernel driver 6.5.52.
8. CNDev package compatibility with installed 3.12.4.
9. CNMon compatibility with driver 6.5.52.
10. Supported firmware range, explicitly including v1.3.1.
11. Minimum and maximum Ubuntu 20.04 package dependencies.
12. GLIBC requirement, explicitly excluding GLIBC >=2.34 unless the package set is not compatible.

## Requested package artifacts

Please provide official amd64 Debian package files or an official package-repository procedure for:

- CNTookit meta-package or release bundle
- CNRT
- CNDrv userspace
- CNCC
- CNAS
- CNBIN
- CNNL
- CNCL
- CNDev
- CNMon
- MLU-OPS or BANG C development samples

For every package, provide:

- official download URL
- exact package filename
- exact package version
- architecture
- package dependencies
- official SHA-256 checksum
- release note or compatibility document
- package acquisition authorization/account requirement

## Requested examples

Please provide or point to:

1. Native BANG C Vector Add source for MLU590-M9.
2. Native host launch and memory-copy example.
3. `cncc` compile command and target option for MLU590-M9.
4. CNNL BF16 GEMM example with FP32 accumulation and output semantics.
5. FP16 GEMM example.
6. Eight-card CNCL initialization and collective communication example.
7. H2D/D2H verification example.

## Candidate validation

We have identified these public candidates for investigation only:

- CNTookit 3.8.4-1 Ubuntu 20.04 / MLU370 directory
- CNNL 1.23.2-1 Ubuntu 20.04
- CNCL 1.13.0-1 Ubuntu 20.04

Please confirm whether these packages support MLU590-M9 or provide the correct MLU590-specific package tuple. The MLU370 directory name is not sufficient evidence.

The newer public Neuware 4.7.6 release identifies MLU590-M9 and host driver 6.5.52, but it is documented on Ubuntu 24.04 and is therefore not presumed compatible with Ubuntu 20.04.

## Installation constraints

- Do not require upgrading Ubuntu.
- Do not require modifying glibc.
- Do not require modifying the kernel driver or firmware.
- Preserve existing CNDev 3.12.4 unless a compatible supported upgrade is identified.
- Provide package maintainer behavior and uninstallation/rollback instructions.

## Official references

- Official SDK download portal: https://sdk.cambricon.com/download
- Cambricon developer portal: https://developer.cambricon.com/
- Enterprise SDK catalog: https://cair.cambricon.com/
- CNTookit documentation: https://www.cambricon.com/docs/cntoolkit/index.html
- Cambricon MLU-OPS repository: https://github.com/Cambricon/mlu-ops
