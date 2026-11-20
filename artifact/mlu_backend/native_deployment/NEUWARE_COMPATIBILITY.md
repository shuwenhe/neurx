# Native Neuware compatibility

**BLOCKED.** No exact, officially supported native tuple was verified for Ubuntu 20.04 x86-64, glibc 2.31, MLU590-M9 and driver/firmware 6.5.52. Public documentation establishes some dimensions separately. It does not prove that a native release matching all four is unavailable.

- Cambricon's CNToolkit 3.8.4 package guide documents Ubuntu 20.04 native installation. Its component guide names MLU590-M9 and the `mtp_592` device compiler target. This release is a candidate for a vendor compatibility query. Driver/firmware 6.5.52 compatibility and the exact CNRT/CNDrv package build remain unverified. [Native package guide](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html) · [Component guide](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)
- The official CNNL notes list x86-64 MLU590 support in CNNL 1.13–1.18 and corresponding toolkit minimum versions. That evidence does not pin a native CNRT/CNDrv/CNNL/CNCL bundle for this driver. No compatible CNCL package and version were verified. [CNNL release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html)
- Cambricon's developer site directs enterprise users to authenticated SDK access. The public Ubuntu 20.04 package directory found during the search is labeled MLU370. Neither it nor general toolkit support establishes the exact MLU590-M9 pairing. [Cambricon SDK access](https://developer.cambricon.com/index/search/index.html?q=590) · [Public MLU370 package directory](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/)

## Local incompatibility reproduced

`dpkg-deb -f /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb Version Depends` exited 0. It reported `6.12.1-1.ubuntu22.04` with `libc6 (>= 2.34)`, `libstdc++6 (>= 9)` and `cndrv`. The same package cache contains Ubuntu 22.04 CNDrv 2.13.2 and CNCC 4.13.3. These are package files. Their contents are not host-installed SDK evidence.

```sh
lib="$PWD/artifact/build/cnrt_integration/sdk/usr/local/neuware/lib64/libcnrt.so"
python3 -c 'import ctypes,sys; ctypes.CDLL(sys.argv[1])' "$lib"
```

Exit 1 with `GLIBC_2.34 not found`. The cached library remains excluded from native deployment.
