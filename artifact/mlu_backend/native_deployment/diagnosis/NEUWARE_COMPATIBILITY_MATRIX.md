# Native Neuware compatibility matrix

Target tuple is Ubuntu **20.04.6 amd64**, glibc **2.31**, MLU590-M9, and driver and firmware **6.5.52**.

| Component | Exact version or version range found | Evidence and status for target tuple |
| --- | --- | --- |
| CNToolkit | `3.8.4-1.ubuntu20.04_amd64` | **UNKNOWN** for exact driver pairing. Cambricon publishes this package in its Ubuntu 20.04 MLU370 directory. The toolkit guide separately names MLU590-M9. No exact native MLU590-M9 package manifest or 6.5.52 compatibility statement was verified for this release. |
| CNRT | `6.12.1-1.ubuntu22.04` | **BLOCKED** on glibc 2.31. The cached file was inspected and failed actual load. Exact older Focal version compatible with driver 6.5.52 is **UNKNOWN**. |
| CNDrv | `2.13.2-1.ubuntu22.04` | **BLOCKED** for this cached candidate. Package metadata requires libc6 >= 2.34. Matching Focal version is **UNKNOWN**. |
| CNNL | `1.14.z–1.18.z` | **UNKNOWN** for the entire tuple. These are hardware-support ranges from the vendor's x86-64 MLU590 table, with toolkit minima 3.2.0–3.5.0. A Focal build compatible with the exact driver and CNRT bundle was not verified. |
| CNCC | `4.13.3-1.ubuntu22.04` | **BLOCKED** for this cached candidate. Metadata requires libc6 >= 2.34 and libstdc++6 >= 12. The 3.8.4 guide names MLU590 target `mtp_592`, but the exact Focal CNCC package compatible with driver 6.5.52 remains **UNKNOWN**. |
| CNCL | Exact compatible version **UNKNOWN** | No CNCL library, header or approved MLU590-M9 Focal package manifest was found. |
| CNDev | Installed `3.12.4-1.ubuntu20.04`; cached `3.12.6-1.ubuntu22.04` | Installed ELF library presence **CONFIRMED**. Cached version requires libc6 >= 2.34. Device access through CNDev is **BLOCKED** in this session. |
| CNMon | Driver package `6.5.52-30.ubuntu20.04`, embedded version `6.5.52` | Binary presence **CONFIRMED**. Hardware query **BLOCKED** by inaccessible devices. |

The exact tuple has no verified public match from this investigation. That is an evidence gap about older native releases. Cambricon's developer site says SDK downloads require enterprise access. Request a written version manifest covering all components and driver/firmware 6.5.52.

Sources

- [Cambricon Focal package index](https://sdk.cambricon.com/static/Basis/MLU370_X86_ubuntu20.04/)
- [Cambricon CNToolkit 3.8.4 native installation](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html)
- [Cambricon CNToolkit hardware and compiler target table](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)
- [Cambricon CNNL compatibility table](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html)
- [Cambricon enterprise SDK access](https://developer.cambricon.com/index/search/index.html?q=590)
- [Cached package and ELF evidence](CNRT_GLIBC_ANALYSIS.md)
