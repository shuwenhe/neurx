# CNRT dependency audit

Commands ran on Ubuntu 20.04.6 x86-64, kernel 5.15.0-139-generic. No packages were installed. The only SDK staged for inspection came from the existing Cambricon package cache.

| Command | Exit | Evidence |
| --- | ---: | --- |
| `getconf GNU_LIBC_VERSION` | 0 | glibc 2.31 |
| `ls /usr/local/neuware/{include,lib64}` | 0 | `cndev.h`, `libcndev.so`, `libcndev.so.3.12.4` |
| `ldconfig -p \| grep -Ei 'cnrt\|cndrv\|cnnl\|cndev\|cncl'` | 0 | Only CNDev appeared |
| `dpkg-query -W \| grep -Ei 'cambricon\|cntoolkit\|cndev\|cnrt'` | 0 | Driver package 6.5.52-30.ubuntu20.04, CNDev 3.12.4, cntoolkit repository package 3.13.6 |
| `command -v cncc` | 1 | CNCC absent from PATH |
| `dpkg-deb -f /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb Version Depends` | 0 | 6.12.1-1.ubuntu22.04, libc6 >= 2.34, libstdc++6 >= 9 and CNDrv |
| `dpkg-deb -x /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb artifact/build/cnrt_integration/sdk` | 0 | Staged vendor header and shared object in the ignored workspace build directory |

For the extracted library, `readelf --version-info "$lib"` reported GLIBC_2.34. `ldd "$lib"` exited 0 while printing the missing version. An actual `ctypes.CDLL` load exited 1 with `GLIBC_2.34 not found`. The header declares `cnrtGetDeviceCount(unsigned int*)` and `cnrtSetDevice(int)`. The extracted library's dynamic symbol table contains both, as well as `cnrtGetLibVersion`, `cnrtMalloc`, `cnrtFree`, `cnrtMemcpy`, and `cnrtSyncDevice`. No `cnrtInit` declaration or dynamic symbol was found for this release. Symbol presence in an ELF file is static evidence only.
