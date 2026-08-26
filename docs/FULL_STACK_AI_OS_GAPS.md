# NeurX full-stack AI OS gap map

NeurX targets three products built on one kernel: datacenter AI infrastructure,
robotics control, and an automotive safety platform. Linux is the behavioral
reference, not a directory-by-directory implementation requirement.

## Shared kernel baseline

Not yet complete: SMP CPU bring-up, NUMA topology, per-CPU state, exception
recovery, timer/timekeeping, preemptive scheduling, process credentials,
signals, futexes, ELF userspace, demand paging, copy-on-write, page reclaim,
slab allocation, DMA/IOMMU, a unified device model, PCI BAR/MSI-X, storage,
initramfs/VFS integration, TCP/IP, namespaces/cgroups, audit, secure/measured
boot, suspend/reboot, crash dumps, tracing, and stable driver/user ABIs.

## Datacenter profile

Required additions: ACPI/NUMA, huge pages, CPU/GPU/NPU affinity, IOMMU and
peer-to-peer DMA, NVMe, RDMA/RoCE, bonding, containers, cgroups, distributed
checkpointing, failure-aware collectives, model serving admission control,
rolling upgrades, telemetry, and fleet orchestration.

## Robotics profile

Required additions: bounded-latency PREEMPT_RT scheduling, priority inheritance,
high-resolution timers, CAN/CAN-FD, EtherCAT or TSN, GPIO/PWM/SPI/I2C/UART,
sensor timestamp synchronization, actuator deadlines, watchdogs, safe-stop,
ROS-compatible messaging, and deterministic inference budgets.

## Automotive profile

Required additions beyond robotics: hardware safety islands, MPU/IOMMU domain
separation, measured boot and signed OTA with rollback, redundant CAN and TSN,
PTP time synchronization, health supervision, diagnostic logging, degraded
operation modes, freedom-from-interference evidence, and ISO 26262-oriented
verification artifacts. A capability gate is not a safety certification.

## Delivery order

1. Boot-to-Ring-3 test in QEMU with exceptions, timer, page reclaim and `/init`.
2. PCI/MSI-X plus virtio block/net; initramfs root; UDP and TCP smoke tests.
3. SMP, scheduler, VM/reclaim, processes, security boundaries and observability.
4. Datacenter NUMA/IOMMU/RDMA and accelerator runtime.
5. Robotics PREEMPT_RT and deterministic device I/O.
6. Automotive isolation, redundant communications and safety lifecycle.

Every claimed capability must have a build target, a deterministic test, and a
hardware or emulator log. Static status banners are not implementation proof.
