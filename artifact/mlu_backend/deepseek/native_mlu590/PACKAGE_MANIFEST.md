# Package Manifest

## Installed packages

| Package | Exact version | Architecture | Source |
|---|---|---|---|
| cambricon-mlu-driver-dkms | 6.5.52-30.ubuntu20.04 | amd64 | dpkg |
| cndev | 3.12.4-1.ubuntu20.04 | amd64 | dpkg |
| cntoolkit | 3.13.6-1.ubuntu22.04 | amd64 | dpkg |

## Local incompatible cache packages

| Package file | Size | SHA-256 |
|---|---:|---|
| `/var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb` | 235140 | `57b9d75aa2ae93eda63935391163fa04a2fb248595c36adc6251fbdd0d8f38d6` |
| `/var/cntoolkit-3.13.6/cncc_4.13.3-1.ubuntu22.04_amd64.deb` | 43664540 | `7ae4c3eb811ce3e9e31d919d1f662e6c9cdcc3dec4b5838a9e765507e54cfe0e` |
| `/var/cntoolkit-3.13.6/cndev_3.12.6-1.ubuntu22.04_amd64.deb` | 361332 | `ba407a50c2d55ac3dd10f5edd7277e1b199858559bf7afb3fc54e414c5d11705` |
| `/var/cntoolkit-3.13.6/cnbin_1.13.2-1.ubuntu22.04_amd64.deb` | 2786664 | `e7150ff631778103375835e90d933073a224a609f62a3dcf3dbca4eebe2cc69f` |
| `/var/cntoolkit-3.13.6/cnas_4.13.1-1.ubuntu22.04_amd64.deb` | 3215302 | `de16d51a2caf44f7729cab1f4e7527b693007ff152d581101bc7451759f99f70` |

These package hashes verify the local cache files. They do not imply host compatibility.

## Required Focal package set

Not acquired:

- CNRT
- CNCC / BANG C compiler
- CNAS
- CNBIN
- CNNL
- CNCL
- Focal CNDev
- Focal CNMon
- CNDRV package compatible with kernel/driver line

## Package metadata

The cached Ubuntu 22.04 packages declare:

```text
cnrt: Depends libc6 >=2.34
cncc: Depends libc6 >=2.34
cndev: Depends libc6 >=2.34
cnbin: Depends libc6 >=2.34
cnas: Depends libc6 >=2.34
```

The host GLIBC is 2.31. No package from this cache passed offline compatibility validation.
