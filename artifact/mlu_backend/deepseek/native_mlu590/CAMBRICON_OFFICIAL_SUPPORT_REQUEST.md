# Cambricon official technical support request

**Draft, unsent.**

**Subject** — Request for a supported native Ubuntu 20.04 Neuware bundle for eight MLU590-M9 cards

Dear Cambricon Technical Support,

We are developing a native MLU runtime in NeurX on an existing server with **8 × MLU590-M9**, PCI ID `cabc:0590`. Device access has been confirmed by the server operator. The installed driver is **6.5.52**, reported board firmware is **1.3.1**, and the host is **Ubuntu 20.04.6 LTS x86_64 (amd64)** with **glibc 2.31**. Installed device tools are **CNDev 3.12.4** and **CNMon 6.5.52**. Please identify the supported native deployment that retains this OS, libc, driver and firmware. Cached Ubuntu 22.04 CNRT 6.12.1 and CNCC 4.13.3 require a newer glibc and are unsuitable. The public Focal package endpoints returned HTTP 502.

Please provide:

1. The supported Neuware/CNToolkit release for this exact hardware, firmware, driver and OS tuple. Is the Focal build of CNToolkit 3.8.4 supported on this combination? If no native release is supported, please identify the limiting requirement.
2. Official Focal amd64 CNRT, CNDrv userspace, and CNCC packages, including matching headers and required CNAS/CNBIN dependencies. Confirm the exact compiler target for MLU590-M9 and the libc/libstdc++ requirements.
3. Compatible CNNL and CNCL packages from the supported release set. Confirm whether the existing CNDev and CNMon can be retained and identify any required replacement versions.
4. The official board, driver and firmware compatibility table, including the scope of firmware version 1.3.1 and the supported ranges. Please supply package filenames, exact versions, architecture, download links, direct dependencies, and vendor SHA-256 hashes or a signed manifest.
5. Native installation instructions and required device-node access, with package ordering and a method to inspect the bundle offline before installation.
6. A native BANG C Vector Add example for MLU590, with toolchain flags, initialization, transfers, launch, queue synchronization and cleanup.
7. A BF16 GEMM example for MLU590, specifying supported input storage, FP32 accumulation and FP32 output, descriptor layout and workspace. Please confirm FP16 support separately and indicate supported alignment and leading dimensions.
8. Eight-card CNCL configuration guidance for MLU590-M9, including supported driver/topology, bootstrap prerequisites and a minimal collective diagnostic.

If download authorization is needed, please identify the enterprise entitlement or approved offline delivery route for this specific bundle.

Regards,  
NeurX infrastructure team
