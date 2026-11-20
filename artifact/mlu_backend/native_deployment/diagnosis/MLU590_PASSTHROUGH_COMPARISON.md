# MLU590-M9 Device Passthrough Comparison

Audit date: 2026-11-20

## Final status

**DEVICE_PASSTHROUGH_CONFIRMED**

**CNRT_NATIVE_RUNTIME_BLOCKED**

The fresh execution environment is not isolated from the host for PID, mount, or device namespaces. It shares PID namespace 4026531836 and mount namespace 4026531841 with PID 1 and the host `/dev` view.

Eight PCI devices are bound to the Cambricon driver, eight character device nodes exist, all nodes are readable/writable by `gaozhi`, and `cnmon` enumerates all eight MLU590-M9 cards. This disproves the earlier “Codex environment has no device passthrough” diagnosis.

## Fresh environment evidence

### Identity

```text
uid=1001(gaozhi)
gid=1001(gaozhi)
hostname=tza-0a09-ai01-em9
```

### PID namespace

```text
PID namespace PID 1: pid:[4026531836]
PID namespace self: pid:[4026531836]
Mount namespace PID 1: mnt:[4026531841]
Mount namespace self: mnt:[4026531841]
```

Exit 0 for namespace reads.

PID 1 is `/sbin/init splash`, not a container entrypoint.

### Mount namespace

```text
/dev: udev devtmpfs
root: /dev/sdb2 ext4
```

No container overlay or `/dev` tmpfs overlay is present in the fresh environment.

The following mount check returned host `udev`:

```text
findmnt -T /dev
TARGET=/dev SOURCE=udev FSTYPE=devtmpfs
OPTIONS=rw,nosuid,noexec,relatime,...
```

## PCI evidence

Eight PCI devices are confirmed:

```text
0000:4f:00.0
0000:53:00.0
0000:6f:00.0
0000:73:00.0
0000:af:00.0
0000:b3:00.0
0000:d3:00.0
0000:cf:00.0
```

Vendor/device: `0xcabc:0x0590`

Each device reports:

- Subsystem: `0xcabc:0x8003`
- Kernel driver: `cambricon-pci-drv_s1m1`
- Kernel modules: `cambricon_drv`, `cambricon_gdrdrv`

NUMA and links:

| PCI BDF | NUMA | Current link |
|---|---:|---|
| 4f:00.0 | 2 | x16 / 16 GT/s |
| 53:00.0 | 2 | x16 / 16 GT/s |
| 6f:00.0 | 3 | x16 / 16 GT/s |
| 73:00.0 | 3 | x16 / 16 GT/s |
| af:00.0 | 5 | x16 / 16 GT/s |
| b3:00.0 | 5 | x16 / 16 GT/s |
| cf:00.0 | 6 | x16 / 16 GT/s |
| d3:00.0 | 6 | x16 / 16 GT/s |

## Character devices

The following nodes exist with mode `crw-rw-rw-`:

```text
/dev/cambricon_ctl
/dev/cambricon_dev0
/dev/cambricon_dev1
/dev/cambricon_dev2
/dev/cambricon_dev3
/dev/cambricon_dev4
/dev/cambricon_dev5
/dev/cambricon_dev6
/dev/cambricon_dev7
/dev/cambricon_gdr
/dev/cambricon_ipcm0 through /dev/cambricon_ipcm7
```

Major/minor examples:

```text
cambricon_ctl: 509,0
cambricon_dev0: 508,0
cambricon_dev7: 508,7
cambricon_gdr: 10,122
```

An RDWR open test returned `RDWR_OK` for `/dev/cambricon_dev0` through `/dev/cambricon_dev7`.

Exit 0.

## Cgroup evidence

The current cgroup is a normal user systemd session scope:

```text
/user.slice/user-1001.slice/session-10473.scope
```

Devices policy returned:

```text
a *:* rwm
```

Combined with successful character-device opens, effective cgroup access is confirmed rather than merely configured.

## Runtime monitoring evidence

CNMon result:

```text
cnmon all -l exit=0
MLU 0 through MLU 7: MLU590-M9
```

CNMon version:

```text
cnmon version:6.5.52
exit=0
```

The official CNDev sample result:

```text
cndev lib version:3.12.4
card num=8
Card 0 through Card 7: MLU590-M9
HealthState=1
Driver Version=6.5.52
exit=0
```

This confirms real device enumeration and health access through CNDev.

## SDK/runtime status

GLIBC:

```text
GLIBC 2.31
```

Only `libcndev.so` is registered:

```text
libcndev.so => /lib/x86_64-linux-gnu/libcndev.so
```

Host search found no CNRT, CNNL, CNCL, CNCC, or CNAS executable/library.

The package cache contains Ubuntu 22.04 CNRT 6.12.1 packages, but this task explicitly prohibits retrying or installing that incompatible package on glibc 2.31.

## Isolation boundary conclusion

The exact boundary was not a container/pass-through boundary in the fresh environment.

It was a stale or environment-specific observation:

- Earlier Codex evidence indicated zero `/dev/cambricon_*` nodes and `cnmon CNDEV_ERROR_NO_DRIVER`.
- Fresh evidence shows those nodes and CNDev enumeration.
- `/proc/1`, namespace IDs, mount source, PCI sysfs, character nodes, cgroup, CNMon, and CNDev all agree with host-native execution.

Fresh evidence is stronger than the earlier cached result.

## Safe remediation plan

### 1. Preserve host device access

Do not add or change container/passthrough rules. Current access is confirmed.

Do not load/unload modules, change udev permissions, or modify systemd Cambricon services.

### 2. Resolve native runtime compatibility

Acquire or install a runtime package set that is:

- compatible with Ubuntu 20.04;
- compatible with glibc 2.31;
- compatible with driver 6.5.52;
- compatible with CNDev 3.12.4;
- approved for firmware 1.3.1.

Use a compatible CNRT/CNNL/CNCL package set, not the cached Ubuntu 22.04 CNRT 6.12.1 package.

### 3. Validate runtime before NeurX

1. Verify `ldconfig -p` for CNRT/CNNL/CNCL.
2. Check `ldd` dependencies for GLIBC 2.34 or later symbols.
3. Run a vendor enumeration example.
4. Create a CNRT context on card 0.
5. Allocate device and host memory.
6. Copy host-to-device and device-to-host.
7. Synchronize.
8. Run a small BF16 GEMM.
9. Confirm numerics.
10. Test one or all MLU-Link/CNCL collectives.

## Final validation matrix

| Layer | Status |
|---|---|
| PCIe hardware detected | CONFIRMED |
| PCI binding | CONFIRMED |
| Character nodes | CONFIRMED |
| Effective cgroup access | CONFIRMED |
| Character device RDWR open | CONFIRMED |
| CNMon enumeration | CONFIRMED |
| CNDev enumeration | CONFIRMED |
| Health state | CONFIRMED |
| Host glibc | CONFIRMED 2.31 |
| CNRT host runtime | NOT FOUND |
| CNRT compatibility | BLOCKED |
| CNNL host runtime | NOT FOUND |
| CNCL host runtime | NOT FOUND |
| Native MLU kernel launch | NOT TESTED |
| H2D/D2H copy | NOT TESTED |
| BF16 computation | NOT TESTED |
| Eight-card collective | NOT TESTED |
| NeurX MLU plugin | NOT IMPLEMENTED |
