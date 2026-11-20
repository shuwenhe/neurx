# Official Compatibility Matrix

## Status legend

- **CONFIRMED**: evidence directly establishes the value.
- **UNKNOWN**: no official exact-combination evidence was obtained.
- **BLOCKED**: evidence establishes incompatibility or prevents acquisition/validation.

## Matrix

| Component | Required information | Evidence | Status |
|---|---|---|---|
| CNTookit | Exact Focal amd64 package and release | Public Cambricon MLU-OPS instructions document Ubuntu 20.04 CNTookit packages, including historical 3.8.4-1. Official package endpoint currently returned HTTP 502. This path is named MLU370 and not confirmed for MLU590. | UNKNOWN |
| CNRT | Exact version; GLIBC and driver compatibility | Installed host has no CNRT. Cached CNRT 6.12.1 is Ubuntu 22.04, declares `libc6 >= 2.34`, and ELF inspection exposes GLIBC 2.34. It is unusable on GLIBC 2.31. | BLOCKED |
| CNCC | Exact version and MLU590 `mtp_592` support | Cached CNCC 4.13.3 is Ubuntu 22.04 and requires GLIBC 2.34/libstdc++12. No official Focal package or compiler target matrix is confirmed for MLU590-M9. | UNKNOWN / BLOCKED for cached package |
| CNNL | Exact version and MLU590 BF16/FP16 GEMM | Public Focal CNNL 1.23.2-1 naming exists in official Cambricon MLU-OPS documentation, but no official package checksum or MLU590/driver/GLIBC compatibility evidence was obtained. | UNKNOWN |
| CNCL | Exact version and eight-card communication | Public Focal CNCL 1.13.0-1 naming exists in official Cambricon MLU-OPS documentation, but no package or MLU590 eight-card compatibility evidence was obtained. | UNKNOWN |
| CNDrv | Userspace compatibility with driver 6.5.52 | No approved userspace CNDrv package found. Cached CNDrv 2.13.2 is Ubuntu 22.04 and requires GLIBC 2.34. | BLOCKED |
| CNDev | Compatibility with installed 3.12.4 | CNDev 3.12.4-1.ubuntu20.04 is installed and successfully enumerates eight cards. Replacement 3.12.6 is Ubuntu 22.04 and requires GLIBC 2.34. Exact package-line compatibility for a full SDK is not vendor-confirmed. | PARTIALLY CONFIRMED |
| CNMon | Compatibility with driver 6.5.52 | CNMon 6.5.52 is installed and works with driver 6.5.52. | CONFIRMED |
| Firmware | Supported firmware range | Firmware v1.3.1 is confirmed on all cards. No official supported-firmware range was obtained. | UNKNOWN |
| MLU590-M9 | Exact SDK and runtime support | The Neuware 4.7.6 release information confirms MLU590 and host driver 6.5.52, but only for an Ubuntu 24.04 base image. This is not evidence of Ubuntu 20.04 compatibility. | BLOCKED for Focal; MLU590 line confirmed elsewhere |
| Ubuntu 20.04.6 | amd64 package support | Official public Cambricon CNTookit/CNNL/CNCL documentation and package URLs show historical Focal support; exact package candidates and endpoint metadata are not verified. | PARTIALLY CONFIRMED |
| GLIBC | Maximum host requirement 2.31 | Host GLIBC is 2.31. All candidate Ubuntu 22.04 cache packages declare or expose GLIBC 2.34+. | CONFIRMED host; incompatible candidates BLOCKED |

## Exact local evidence

### Host

```text
OS=Ubuntu 20.04.6
Architecture=amd64
GLIBC=2.31
Driver=6.5.52
Firmware=v1.3.1
CNDev=3.12.4-1.ubuntu20.04
CNMon=6.5.52
Cards=8
```

### Cached incompatible packages

| Package | Version | Dependency/ELF result |
|---|---|---|
| CNRT | 6.12.1-1.ubuntu22.04 | `libc6 >= 2.34`; ELF exposes GLIBC 2.34 |
| CNCC | 4.13.3-1.ubuntu22.04 | `libc6 >= 2.34`; `libstdc++6 >= 12` |
| CNDev | 3.12.6-1.ubuntu22.04 | `libc6 >= 2.34`; ELF exposes GLIBC 2.34 |
| CNDrv | 2.13.2-1.ubuntu22.04 | `libc6 >= 2.34` |
| CNBIN | 1.13.2-1.ubuntu22.04 | `libc6 >= 2.34` |
| CNAS | 4.13.1-1.ubuntu22.04 | `libc6 >= 2.34` |

## Official source URLs

- MLU-OPS repository: https://github.com/Cambricon/mlu-ops
- MLU-OPS Ubuntu 20.04/CNTookit documentation: https://github.com/Cambricon/mlu-ops/blob/master/docker/ubuntu20.04-x86_64/Dockerfile
- CNTookit installation guide: https://www.cambricon.com/docs/cntoolkit/index.html
- CNNL release notes: https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html
- BANG C development guide: https://github.com/Cambricon/mlu-ops/blob/master/docs/BANG-C-OPS-Develop-Guide.md
- Enterprise SDK catalog: https://cair.cambricon.com/#/home/catalog?type=SDK%20Release
- SDK download portal: https://sdk.cambricon.com/download

## Package endpoint recheck

The following official Focal candidate URLs were rechecked on 2026-11-20 and returned HTTP 502:

- `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cntoolkit_3.8.4-1.ubuntu20.04_amd64.deb`
- `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cnnl_1.23.2-1.ubuntu20.04_amd64.deb`
- `https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cncl_1.13.0-1.ubuntu20.04_amd64.deb`

No unofficial mirror was used.
