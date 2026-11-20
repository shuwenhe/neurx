# Runtime compatibility

The target is x86-64 MLU590-M9 with kernel driver and firmware 6.5.52. The host userspace is Ubuntu 20.04.6 with glibc 2.31.

| Route | Evidence and status |
| --- | --- |
| Native Ubuntu 20.04 | Cambricon's CNToolkit 3.8.4 manuals list both Ubuntu 20.04 installation and MLU590-M9 support. They do not establish that this release's CNRT and CNDrv are supported with driver 6.5.52. An exact vendor-confirmed native match was not identified. |
| Cached Ubuntu 22.04 CNRT 6.12.1 | The package needs glibc 2.34 or newer and matching CNDrv. Host loading failed. Vendor confirmation for the exact driver pairing was not found. |
| Isolated Neuware 4.7.6 | The FlagOS release maintainer explicitly lists x86-64 MLU590 with host driver 6.5.52 for its Ubuntu 24.04 Neuware 4.7.6 image. This is a published exact-driver deployment candidate. Cambricon certification and local execution were not verified. |

References

- [Cambricon CNToolkit 3.8.4 Ubuntu package installation](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_package_manager_installation/index.html)
- [Cambricon CNToolkit 3.8.4 accelerator and component support](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)
- [FlagOS Neuware 4.7.6 supported prerequisites and image contents](https://flagos-ai.github.io/release-info/base/cambricon-neuware4.7.6/)

`docker info` exited 1 with a denied daemon-socket connection. `command -v podman` found no executable. `unshare -Ur true` exited 0. A private user namespace by itself supplies neither a compatible root filesystem nor MLU device access. The image was not pulled or started. A separate process using a complete matching root filesystem and loader could address the glibc dependency, provided it also has matched vendor userspace libraries and allocated MLU device nodes. The read-only host checks found no cached libc6 package at `/var/cache/apt/archives/libc6*` or matching loader under the probed `/opt/*/lib*/ld-linux*` paths. No system loader, driver, or configuration was changed.
