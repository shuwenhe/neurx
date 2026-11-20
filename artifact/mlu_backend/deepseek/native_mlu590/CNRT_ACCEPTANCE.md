# CNRT Acceptance

## Status

**NOT TESTED - BLOCKED**

## Why acceptance cannot run

- No approved Focal CNRT package was acquired.
- The cached CNRT 6.12.1 package requires GLIBC 2.34.
- Host GLIBC is 2.31.
- The package must not be loaded or installed.
- No substitute runtime was downloaded.

## Existing evidence

CNDev 3.12.4 initialization and enumeration pass:

```text
cndev lib version=3.12.4
card num=8
Card 0 through 7=MLU590-M9
HealthState=1
Driver Version=6.5.52
exit=0
```

This proves device monitoring and character-node access, but not CNRT initialization or kernel execution.

## Required acceptance sequence after approval

1. Install only the vendor-approved Focal package set.
2. Confirm `ldd` reports no missing GLIBC ≥2.34 symbols.
3. Confirm CNRT, CNDev and CNNL libraries load.
4. Enumerate eight devices.
5. Initialize CNRT.
6. Create one card context.
7. Allocate host and device buffers.
8. Copy host-to-device.
9. Synchronize.
10. Copy device-to-host.
11. Destroy buffers and context.
12. Repeat on every card.

No acceptance PASS may be claimed until these operations execute with real hardware.
