# SDK Staging Readiness

## Status

**STAGING_READY - PACKAGE_SET_NOT_AVAILABLE**

The isolated staging directory is prepared. It contains no vendor package, so no offline compatibility validation or system installation can proceed.

## Staging layout

```text
artifact/mlu_backend/deepseek/native_mlu590/sdk_staging/
  README.md
  packages/
  metadata/
  extracted/
```

## Required acquisition inputs

The package set is only acceptable when the vendor provides:

1. CNTookit/CNToolkit package exact version and official filename.
2. CNRT exact version.
3. CNCC exact version and `mtp_592` or equivalent MLU590 target confirmation.
4. CNAS exact version.
5. CNBIN exact version.
6. CNDrv userspace exact version.
7. CNNL exact version.
8. CNCL exact version.
9. CNDev exact version.
10. CNMon exact version.
11. Firmware compatibility range including v1.3.1.
12. Official SHA-256 for every package.
13. Ubuntu 20.04 amd64 package dependencies.
14. Official vendor download URL or account procedure.

## Offline validation sequence

For each package:

```bash
sha256sum package.deb
dpkg-deb -I package.deb
dpkg-deb -f package.deb Package Version Architecture Depends
dpkg-deb -x package.deb extracted/package/
find extracted/package -type f -exec file {} +
readelf --version-info extracted/.../lib*.so*
objdump -T extracted/.../lib*.so* | grep GLIBC_
```

Reject if:

- package architecture is not amd64;
- package dependency requires `libc6 >= 2.34`;
- ELF requires GLIBC 2.34 or newer;
- package is labeled Ubuntu 22.04 or later;
- package is not confirmed for MLU590-M9;
- package SHA-256 differs from the official vendor record;
- package versions are not one internally compatible Neuware release;
- CNRT/CNCC/CNNL/CNCL relationship is not documented or vendor-approved.

## Installation stop gate

Do not install until all conditions pass:

- exact official Focal package set acquired;
- official SHA-256 metadata obtained;
- package metadata inspected;
- package extracted in staging;
- ELF GLIBC requirement <=2.31;
- compiler target explicitly supports MLU590-M9;
- CNRT/CNNL/CNCL/CNCC versions belong to approved tuple;
- driver 6.5.52 compatibility documented;
- firmware v1.3.1 compatibility documented;
- user explicitly authorizes system package installation.

## Native acceptance gate

After installation authorization and successful vendor package validation:

1. CNRT initialization.
2. Enumerate eight cards.
3. Create a context on MLU0.
4. Allocate device memory.
5. H2D copy.
6. Compile a real BANG C Vector Add kernel with CNCC.
7. Launch kernel on MLU590-M9.
8. Synchronize.
9. D2H copy.
10. Verify numerical output.
11. Release streams/buffers/context.

No CPU fallback or simulated kernel can substitute for this gate.
