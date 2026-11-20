# Final Status

## Mission state

**ACQUISITION_BLOCKED**

Official native Neuware compatibility could not be established for the exact Ubuntu 20.04.6, GLIBC 2.31, MLU590-M9, driver 6.5.52, CNDev 3.12.4 and firmware v1.3.1 environment.

## Confirmed

- 8 MLU590-M9 cards are visible.
- Cambricon driver 6.5.52 is bound.
- Firmware v1.3.1 is reported.
- CNDev 3.12.4 is installed.
- CNMon 6.5.52 is working.
- Character device access is confirmed.
- The host uses GLIBC 2.31.

## Blocking evidence

- Local `/var/cntoolkit-3.13.6` packages are Ubuntu 22.04 packages.
- Cached CNRT 6.12.1 declares `libc6 >= 2.34`.
- Cached CNCC 4.13.3 declares `libc6 >= 2.34`.
- Extracted ELF payloads also expose GLIBC 2.34 requirements.
- No approved Focal CNRT/CNNL/CNCL/CNCC package set was found locally.
- Official Cambricon Focal package endpoint checks returned HTTP 502.
- MLU590 support, firmware compatibility and driver compatibility for a specific Focal SDK release were not vendor-confirmed.

## Acceptance status

| Deliverable/criterion | Status |
|---|---|
| Official compatibility | BLOCKED |
| Official compatibility matrix | CREATED - exact tuple remains UNKNOWN/BLOCKED |
| Cambricon support request | PREPARED - unsent |
| Official package endpoints | RECHECKED - HTTP 502 |
| Enterprise SDK channel | IDENTIFIED - account/access not verified |
| SDK staging | PREPARED - no vendor package artifacts |
| Package manifest | COMPLETED |
| Package acquisition | NOT COMPLETED |
| Offline package metadata audit | COMPLETED for local cache |
| Offline ELF compatibility audit | COMPLETED: incompatible cache rejected |
| CNRT initialization | NOT TESTED |
| Native BANG C compiler | NOT TESTED |
| Real Vector Add on MLU590 | NOT TESTED |
| BF16 GEMM | NOT STARTED |
| NeurX MLU integration | NOT STARTED |

## System changes

No system package was installed.

No package maintainer script was run.

No glibc package, Cambricon driver or firmware was modified.

No reboot occurred.

No existing workload was interrupted.

No file under `/app/shuwen/s` was modified.

## Required next authorization

Obtain an official Cambricon Ubuntu 20.04 package set and vendor compatibility confirmation matching this host. Then obtain explicit authorization to:

1. stage the package set;
2. inspect its metadata and checksums;
3. validate ELF and GLIBC dependencies;
4. install the approved packages;
5. run CNRT, CNCC and Vector Add acceptance.

Until then, NeurX must remain on the CPU/backend-development path.
