# Native Neuware compatibility

**BLOCKED.** No vendor-approved native package tuple was verified for Ubuntu 20.04.6 amd64, glibc 2.31, MLU590-M9, and driver/firmware 6.5.52.

| Component | Observed status |
| --- | --- |
| CNRT | No approved Focal runtime available. Cached 6.12.1 Ubuntu 22.04 requires GLIBC_2.34. |
| CNCC | `command -v cncc` exited 1. |
| CNNL | No approved header and runtime available. Exact target matmul configuration and FP32 accumulation remain unverified. |
| CNCL | No approved native library and header established. |
| CNDev | Installed 3.12.4-1.ubuntu20.04. |
| CNMon | Installed through driver package 6.5.52-30.ubuntu20.04. CNDev initialization failed in this process view. |

`getconf GNU_LIBC_VERSION` reported 2.31 (exit 0), and `ldconfig -p | grep -Ei 'cnrt|cndrv|cnnl|cncl|cndev'` found only CNDev (exit 0). `dpkg-deb -f /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb Version Depends` and static `readelf --version-info` both exited 0 and confirm the cached release's libc requirement. The cached library was not loaded, linked or installed for this turn.

Cambricon's public documentation covers Ubuntu 20.04 and MLU590 in parts of the toolkit and CNNL series. It does not establish the exact approved package combination for this driver. Request the native Focal package manifest and compatibility statement from Cambricon before integration. [Cambricon package guide](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html) · [Cambricon CNNL release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html) · [Existing version matrix](../../native_deployment/diagnosis/NEUWARE_COMPATIBILITY_MATRIX.md)

## Recovery recheck

**UNKNOWN** for the exact officially supported Ubuntu 20.04 amd64, glibc 2.31, MLU590-M9, driver/firmware 6.5.52 SDK combination. **BLOCKED** for native execution. No administrator-provided or vendor-approved candidate package manifest was available. Cambricon documents the Focal installation route and publishes SDKs through enterprise access. The public Focal package index inspected is labeled MLU370 and cannot establish MLU590-M9 compatibility. The available official material leaves the exact older-package and driver pairing open. [Cambricon Focal package index](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/) · [Cambricon enterprise SDK access](https://developer.cambricon.com/index/search/index.html?q=590)

Cached Jammy packages are excluded by their mandatory libc6 >= 2.34 dependency. CNRT also has direct ELF version evidence. The other excluded archives were inspected at the package metadata level and their binaries were not extracted or run. CNDev 3.12.4 and CNMon can be inspected as installed local components. Their highest observed GLIBC versions are 2.29 and 2.14 respectively. This does not establish usable device access. CNNL and CNCL target headers, libraries, dependencies and driver support remain **UNKNOWN** pending the approved package manifest.

The cached CNRT header remains available at `artifact/build/cnrt_integration/sdk/usr/local/neuware/include/cnrt.h`. Existing syntax-only verification and signatures are recorded in [the CNNL compatibility gate](../CNNL_SDK_COMPATIBILITY.md). No cached Jammy executable or library was used. Request scope and exact evidence are in [the vendor request](CAMBRICON_SDK_REQUEST.md).

```text

$ dpkg-deb -f /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb Package Version Architecture Depends
Package: cnrt
Version: 6.12.1-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libstdc++6 (>= 9), cndrv
exit=0

$ dpkg-deb -f /var/cntoolkit-3.13.6/cncc_4.13.3-1.ubuntu22.04_amd64.deb Package Version Architecture Depends
Package: cncc
Version: 4.13.3-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libgcc-s1 (>= 3.4), libstdc++6 (>= 12), cnas, libc6-dev, libc6-dev-i386
exit=0

$ dpkg-deb -f /var/cntoolkit-3.13.6/cndrv_2.13.2-1.ubuntu22.04_amd64.deb Package Version Architecture Depends
Package: cndrv
Version: 2.13.2-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libstdc++6 (>= 5.2), cnbin
exit=0

$ dpkg-deb -f /var/cntoolkit-3.13.6/cndev_3.12.6-1.ubuntu22.04_amd64.deb Package Version Architecture Depends
Package: cndev
Version: 3.12.6-1.ubuntu22.04
Architecture: amd64
Depends: libc6 (>= 2.34), libgcc-s1 (>= 3.0), libstdc++6 (>= 5.2)
exit=0

$ readelf -d artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so | grep NEEDED
 0x0000000000000001 (NEEDED)             Shared library: [libstdc++.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [ld-linux-x86-64.so.2]

$ readelf --version-info artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so | grep "Name: GLIBC_2.34"
  0x0100:   Name: GLIBC_2.34  Flags: none  Version: 10

$ readelf -d /usr/local/neuware/lib64/libcndev.so.3.12.4 | grep NEEDED
 0x0000000000000001 (NEEDED)             Shared library: [libpthread.so.0]
 0x0000000000000001 (NEEDED)             Shared library: [libstdc++.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libgcc_s.so.1]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [ld-linux-x86-64.so.2]

$ readelf --version-info /usr/local/neuware/lib64/libcndev.so.3.12.4 | grep -oE "GLIBC_[0-9.]+" | sort -Vu
GLIBC_2.2.5
GLIBC_2.3
GLIBC_2.3.2
GLIBC_2.3.4
GLIBC_2.4
GLIBC_2.7
GLIBC_2.14
GLIBC_2.29

$ readelf -d /usr/bin/cnmon | grep NEEDED
 0x0000000000000001 (NEEDED)             Shared library: [libdl.so.2]
 0x0000000000000001 (NEEDED)             Shared library: [libpthread.so.0]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libgcc_s.so.1]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]

$ readelf --version-info /usr/bin/cnmon | grep -oE "GLIBC_[0-9.]+" | sort -Vu
GLIBC_2.2.5
GLIBC_2.3
GLIBC_2.3.2
GLIBC_2.3.3
GLIBC_2.3.4
GLIBC_2.4
GLIBC_2.7
GLIBC_2.14

```
