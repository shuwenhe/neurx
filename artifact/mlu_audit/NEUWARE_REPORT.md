# Neuware Report

## Installed packages

- `cambricon-mlu-driver-dkms`: 6.5.52-30.ubuntu20.04
- `cndev`: 3.12.4-1.ubuntu20.04
- `cntoolkit`: repository package 3.13.6-1.ubuntu22.04

## CNDev

- CNDev library: `/usr/local/neuware/lib64/libcndev.so.3.12.4`
- CNDev header: `/usr/local/neuware/include/cndev.h`
- CNMon: `/usr/bin/cnmon`
- CNMon version: 6.5.52
- CNDev sample: `/usr/local/neuware/samples/cndev/devicequery/devicequery.c`
- Official sample compile: successful
- Official sample execution as `gaozhi`: successful
- Official sample result: `cndev lib version:3.12.4`, `card num = 8`

## Missing host-visible components

The following commands were not found:
- `cncc`
- `cnas`
- `cnperf`
- `cnrt`

Host search did not find:
- `libcnrt.so*`
- `libcndrv.so*`
- `libcnnl.so*`
- `libcncl.so*`
- CNRT/CNNL/CNCL headers

`ldconfig -p` did not register CNRT, CNDRV, CNNL, or CNCL libraries.
No CNRT, CNDRV, CNNL, or CNCL environment variables were set.

## CNTookit package cache

`cntoolkit` 3.13.6 repository metadata includes Ubuntu 22.04 package cache entries for CNRT 6.12.1, CNCC 4.13.3, CNAS 4.13.1, CNDRV 2.13.2, CNNL equivalents in CNMLRT/package metadata, and CNPerf 5.12.4. These are package-cache entries, not evidence of installed host components.

The toolkit cache package names and versions must not be reported as installed versions.

## Runtime compatibility

- CNDev 3.12.4 and CNMon 6.5.52 are installed and compatible enough to initialize and enumerate all cards.
- Host-visible CNRT, CNNL, CNCL, CNCC, and CNAS are **NOT FOUND**.
- An existing set of eight `VLLM::Worker_TP*` processes is visible and consumes MLU memory, but the host audit could not resolve an executable or host runtime library path for these processes. This is not enough to establish direct NeurX CNRT availability.

## Classification

- **CONFIRMED:** CNDev 3.12.4, cnmon 6.5.52, driver 6.5.52, firmware 1.3.1.
- **NOT FOUND:** host CNRT, CNNL, CNCL, CNCC, CNAS, and CNPerf executables/libraries.
- **PARTIALLY CONFIRMED:** toolkit repository availability.
- **BLOCKED:** native NeurX compilation and execution until approved runtime components are made host-visible or a supported container is identified.
