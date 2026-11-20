# Driver Report

## Kernel binding

All eight PCI devices bind to the kernel PCI driver name `cambricon-pci-drv_s1m1`. The `/sys/bus/pci/drivers/` link also shows this binding.

Loaded modules:
- `cambricon_drv`
- `cambricon_gdrdrv`
- `cambricon_peermem`

Module evidence:
- `/lib/modules/5.15.0-139-generic/updates/dkms/cambricon-drv.ko`
- Module version: `6.5.52`
- DKMS package: `cambricon-mlu-driver-dkms 6.5.52-30.ubuntu20.04`

`modinfo cambricon-pci-drv_s1m1` returned exit 1 because that is a PCI binding name, not a loadable module name. `modinfo cambricon_drv` returned module metadata successfully.

## Device nodes

As `gaozhi`, the following nodes exist with mode `crw-rw-rw- root:root`:
- `/dev/cambricon_ctl`
- `/dev/cambricon_dev0` through `/dev/cambricon_dev7`
- `/dev/cambricon_gdr`
- `/dev/cambricon_ipcm0` through `/dev/cambricon_ipcm7`
- `/dev/vfio/vfio`

## Access

- Current user: `gaozhi`
- Groups: `gaozhi sudo docker`
- Card nodes are mode 0666 and can be opened by `gaozhi`.
- A process launched as `gaozhi` compiled and ran the official CNDev `devicequery` sample successfully.
- The CNDev sample initialized CNDev, enumerated 8 cards, and read memory, version, health, utilization, frequency, ECC, power, temperature, SN, and MLU-Link fields.

This confirms user-space device access and driver/runtime initialization through CNDev/CNMon. It does not by itself prove a general CNRT kernel launch.

## Kernel logs

No clear Cambricon initialization failure was found in the current `dmesg` substring search. The search matched container-network noise but not a card initialization error.

## Container isolation

The audit is running in the host systemd init scope, not identified as a Docker/OCI container by `/proc/1/cgroup`. `/proc/self/status` reported `NoNewPrivs: 0`.

No container device-passthrough restriction was detected for `/dev/cambricon_dev*`.

## Health

CNMon reported for all eight cards:
- Device: Good
- Driver: Running
- Health: confirmed for monitoring/runtime enumeration
- Firmware: v1.3.1
- ECC count result in devicequery: not shown as a failure

## Classification

- **CONFIRMED:** driver package, module, binding, device nodes, permissions, CNDev initialization, and 8-card enumeration.
- **PARTIALLY CONFIRMED:** kernel health and runtime initialization.
- **NOT TESTED:** actual compute launch and memory copies.
