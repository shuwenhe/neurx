# Official Neuware Compatibility

Audit date: 2026-11-20

## Final classification

**BLOCKED - OFFICIAL COMPATIBILITY NOT ESTABLISHED**

No approved native Neuware package set was identified for the exact combination of:

- Ubuntu 20.04.6 amd64
- glibc 2.31
- MLU590-M9
- Cambricon driver 6.5.52
- CNDev 3.12.4
- firmware v1.3.1

## Exact installed environment

| Component | Confirmed version |
|---|---|
| OS | Ubuntu 20.04.6 LTS |
| Architecture | amd64 |
| GLIBC | 2.31 |
| MLU model | MLU590-M9 |
| Card count | 8 |
| Driver package | cambricon-mlu-driver-dkms 6.5.52-30.ubuntu20.04 |
| Kernel module | cambricon_drv 6.5.52 |
| Firmware | v1.3.1 |
| CNDev | 3.12.4-1.ubuntu20.04 |
| CNMon | 6.5.52 |

## Local cache result

The local `/var/cntoolkit-3.13.6` cache contains Ubuntu 22.04 packages only.

Relevant packages:

| Package | Version | Compatibility with host |
|---|---|---|
| cnrt | 6.12.1-1.ubuntu22.04 | BLOCKED: Debian Depends on libc6 >=2.34 |
| cncc | 4.13.3-1.ubuntu22.04 | BLOCKED: libc6 >=2.34 and libstdc++ >=12 |
| cndev | 3.12.6-1.ubuntu22.04 | BLOCKED: libc6 >=2.34 |
| cnbin | 1.13.2-1.ubuntu22.04 | BLOCKED: libc6 >=2.34 |
| cnas | 4.13.1-1.ubuntu22.04 | BLOCKED: libc6 >=2.34 |

No usable CNRT/CNNL/CNCL package set for Ubuntu 20.04 was found in local caches.

## Official-source evidence

Official Cambricon SDK documentation and source Dockerfiles document Ubuntu 20.04 package naming under:

```text
https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/
```

An official Cambricon MLU-OPS Dockerfile documents CNTookit 3.7.2-1 and CNNL 1.21.1-1 for Ubuntu 20.04.

Official Cambricon documentation also documents CNTookit 3.8.4-1 and CNNL 1.23.2-1 package names for Ubuntu 20.04.

However:

- neither package line is confirmed compatible with driver 6.5.52;
- neither line is confirmed compatible with firmware v1.3.1;
- neither line is confirmed compatible with CNDev 3.12.4;
- MLU590 support is not established from the Ubuntu 20.04 package URLs alone;
- these paths use MLU370 naming and were not treated as an exact MLU590 match.

## Official vendor endpoint result

Direct official endpoint checks for CNTookit/CNNL/CNCL Focal packages returned HTTP 502 Bad Gateway.

```text
https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cntoolkit_3.8.4-1.ubuntu20.04_amd64.deb
HTTP 502

https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cnnl_1.23.2-1.ubuntu20.04_amd64.deb
HTTP 502

https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/cncl_1.13.0-1.ubuntu20.04_amd64.deb
HTTP 502
```

This prevents exact package acquisition and checksum verification.

## Compatibility matrix

| Criterion | Status |
|---|---|
| Ubuntu 20.04 | PARTIALLY SUPPORTED by official historical package URLs |
| amd64 | CONFIRMED |
| glibc 2.31 | UBUNTU22 cache packages incompatible |
| MLU590-M9 | CHIP line appears in other Neuware releases, but exact Focal SDK line is NOT CONFIRMED |
| Driver 6.5.52 | Exact compatible SDK package NOT CONFIRMED |
| CNDev 3.12.4 | Exact compatible package set NOT CONFIRMED |
| Firmware v1.3.1 | Exact compatible SDK package NOT CONFIRMED |
| CNRT | NOT FOUND for Focal |
| CNNL | NOT FOUND for Focal |
| CNCL | NOT FOUND for Focal |
| CNCC | NOT FOUND for Focal |

## Required administrator/vendor action

Obtain written or vendor-published compatibility confirmation and official Focal package downloads for:

- CNTookit/CNRT/CNCC/CNDev/CNMon line compatible with driver 6.5.52;
- CNNL and CNCL package line from the same Neuware release;
- MLU590-M9 support;
- Ubuntu 20.04 amd64 and glibc 2.31;
- firmware v1.3.1.

## Official acquisition recheck, 2026-11-20

**BLOCKED** for acquisition and **UNKNOWN** for the exact approved tuple. This recheck uses firmware **1.3.1** and confirmed device access as supplied by the operator. Hardware diagnostics were not repeated. No authenticated bundle or vendor response was available. The historical public index is under an MLU370 path. Its package names and a compiler architecture table are insufficient to approve this MLU590-M9 deployment.

| Component | Version, OS, architecture and dependency evidence | Status for this server |
| --- | --- | --- |
| CNToolkit | Publicly indexed `3.8.4-1.ubuntu20.04_amd64`; Focal amd64. Archive and its advertised MD5 endpoint both returned 502. Individual dependencies and official SHA-256 are unavailable. [Package index](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/) · [Native Focal installation section](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html) | **CONFIRMED** publication evidence. **UNKNOWN** exact target compatibility. |
| CNRT | Cached `6.12.1-1.ubuntu22.04` amd64 requires libc6 ≥ 2.34, libstdc++6 ≥ 9, and CNDrv. Its ELF requires GLIBC_2.34. Exact native Focal runtime version and approved driver pairing are unknown. [Toolkit component documentation](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html) | **BLOCKED** cached package. **UNKNOWN** approved Focal version. |
| CNCC | Cached `4.13.3-1.ubuntu22.04` amd64 requires libc6 ≥ 2.34, libstdc++6 ≥ 12, CNAS and matching development libraries. The 3.8.4 guide names `mtp_592` for MLU590-M9. The exact Focal compiler archive and compatible native dependencies remain unavailable. [CNCC target table](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html) | **CONFIRMED** documented target. **BLOCKED** cached binary. **UNKNOWN** approved Focal bundle. |
| CNNL | Historical candidate URL `1.23.2-1.ubuntu20.04_amd64` returned 502. Release notes for that series give CNToolkit ≥ 3.8.0 and describe specific BF16/Half matmul modes. Exact Focal archive dependencies, official SHA-256, storage/accumulation tuple, and target-driver compatibility are unverified. [CNNL platform/dependency and matmul release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html) | **UNKNOWN** approved BF16/FP16 GEMM support for the exact environment. |
| CNCL | Publicly indexed `1.13.0-1.ubuntu20.04_amd64` returned 502. Dependencies and official SHA-256 unavailable. No verified official eight-card compatibility statement for this tuple. [Historical package index](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/) | **UNKNOWN** compatible CNCL version and eight-card support. |
| CNDrv userspace | Cached `2.13.2-1.ubuntu22.04` amd64 declares libc6 ≥ 2.34, libstdc++6 ≥ 5.2 and CNBIN. The kernel driver package is `6.5.52-30.ubuntu20.04` amd64. Kernel-driver package presence does not establish the matching CNDrv userspace version. [CNDrv component documentation](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html) | **BLOCKED** cached userspace. **UNKNOWN** approved Focal userspace pairing. |
| CNDev | Installed `3.12.4-1.ubuntu20.04` amd64, dependencies libc6 ≥ 2.29, libgcc-s1 ≥ 3.0, libstdc++6 ≥ 5.2. [CNDev manual entry](https://developer.cambricon.com/index/document/details/classid/7/cid/31/id/590.html) | **CONFIRMED** installed version. **UNKNOWN** joint compatibility with the requested bundle. |
| CNMon | Operator-reported 6.5.52; supplied by `cambricon-mlu-driver-dkms 6.5.52-30.ubuntu20.04` amd64. Package dependencies include DKMS ≥ 1.95, libc6 ≥ 2.17, libgcc-s1 ≥ 3.0 and libstdc++6 ≥ 4.5. [Vendor monitoring and driver checks](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_pre_installation_actions/index.html) | **CONFIRMED** local package. **UNKNOWN** vendor certification with the future SDK. |
| Firmware | Operator reports board firmware 1.3.1 on MLU590-M9. Requested vendor document must distinguish firmware fields and specify the approved range with driver 6.5.52. [Vendor pre-install driver and firmware inspection](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_pre_installation_actions/index.html) | **UNKNOWN** supported firmware range for a Focal SDK. |

### SHA-256 evidence

No official SHA-256 was retrieved for a candidate Focal archive. The following values were computed over the named **local** files and have no vendor-checksum verification.

| File | Local SHA-256 |
| --- | --- |
| Cached CNRT 6.12.1 Jammy archive | `57b9d75aa2ae93eda63935391163fa04a2fb248595c36adc6251fbdd0d8f38d6` |
| Cached CNCC 4.13.3 Jammy archive | `7ae4c3eb811ce3e9e31d919d1f662e6c9cdcc3dec4b5838a9e765507e54cfe0e` |
| Cached CNDrv 2.13.2 Jammy archive | `0da3db8c06a68a7f5b8b81698a6c4dea98eda5ae782099ab02bf1798eb36a9ed` |
| Installed `/usr/bin/cnmon` ELF | `ad548b5b71cc7ed96fedb1622f06dc186b78e7723690b3b9135226bfb9ee6ca8` |
| Installed `/usr/local/neuware/lib64/libcndev.so.3.12.4` ELF | `0af3e81b7ca73e80c4854cc96054339faeef145c46f39d2d801c70c4c41e624a` |

[Vendor support request](CAMBRICON_OFFICIAL_SUPPORT_REQUEST.md) · [Endpoint recheck and acquisition instructions](PACKAGE_ACQUISITION.md#official-endpoint-recheck)
