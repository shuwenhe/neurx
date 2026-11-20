# Device access diagnosis

**CONFIRMED.** Eight PCI devices `cabc:0590` are bound to `cambricon-pci-drv_s1m1`. Kernel records identify them as MLU590-M9 with driver and firmware 6.5.52. The current process can see zero Cambricon character nodes and `cnmon info` exited 255 with `CNDEV_ERROR_NO_DRIVER`.

The directly observed access blocker is the current session's effective `/dev`. A UID-1001 tmpfs with `nodev` is mounted over a devtmpfs at the same path. The overlay contains no Cambricon nodes. A character file on a `nodev` mount would also be unusable for device I/O. The process and its visible PID 1 share mount namespace `4026553129`. PID 1 is `codex`, so this comparison only establishes the scope of the current execution environment. `NoNewPrivs=1` and `CapEff=0`.

| Hypothesis | Status and evidence |
| --- | --- |
| A. Host driver never created nodes | **UNKNOWN.** Kernel records list expected paths. The covered devtmpfs was not inspected. |
| B/F. Session mount isolation hides device paths | **CONFIRMED.** Overmount and zero visible nodes are directly observed. Presence of those specific files under the overlay is unknown. |
| C. Device passthrough mechanism absent | **UNKNOWN.** This session has no usable device exposure. The launch mechanism and its configuration were not inspected. |
| D. Owner/group permissions | **UNKNOWN.** Current UID/GID is 1001 with group 65534. No nodes exist in the visible path to inspect or open. |
| E. Device cgroup denial | **UNKNOWN** for end-to-end device access. The visible v1 devices cgroup at `/user.slice` reports `a *:* rwm`. It does not demonstrate a cgroup denial, and no actual open was possible. |

The requested `find /sys/bus/pci/devices ...` returned no hits because PCI entries are symlinks and the command does not follow them. The rerun with `find -L` found eight. See [administrator actions](ADMIN_ACTIONS.md) for host-side confirmation and sanctioned device exposure.

## Exact command output

```text

$ whoami
gaozhi
exit=0

$ id
uid=1001(gaozhi) gid=1001(gaozhi) groups=1001(gaozhi),65534(nogroup)
exit=0

$ uname -a
Linux tza-0a09-ai01-em9 5.15.0-139-generic #149~20.04.1-Ubuntu SMP Wed Apr 16 08:29:56 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
exit=0

$ cat /etc/os-release
NAME="Ubuntu"
VERSION="20.04.6 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.6 LTS"
VERSION_ID="20.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=focal
UBUNTU_CODENAME=focal
exit=0

$ ldd --version
ldd (Ubuntu GLIBC 2.31-0ubuntu9.18) 2.31
Copyright (C) 2020 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
Written by Roland McGrath and Ulrich Drepper.
exit=0

$ lspci -nn | grep -i cabc
4f:00.0 Processing accelerators [1200]: Device [cabc:0590]
53:00.0 Processing accelerators [1200]: Device [cabc:0590]
6f:00.0 Processing accelerators [1200]: Device [cabc:0590]
73:00.0 Processing accelerators [1200]: Device [cabc:0590]
af:00.0 Processing accelerators [1200]: Device [cabc:0590]
b3:00.0 Processing accelerators [1200]: Device [cabc:0590]
cf:00.0 Processing accelerators [1200]: Device [cabc:0590]
d3:00.0 Processing accelerators [1200]: Device [cabc:0590]
exit=0

$ lsmod | grep cambricon
cambricon_peermem      20480  0
cambricon_gdrdrv       24576  8
cambricon_drv        5496832  39 cambricon_peermem,cambricon_gdrdrv
ecdh_generic           16384  1 cambricon_drv
exit=0

$ ls -l /dev/cambricon* 2>&1
ls: cannot access '/dev/cambricon*': No such file or directory
exit=2

$ find /sys/bus/pci/devices -maxdepth 2 -name vendor -exec sh -c 'grep -il 0xcabc "$1"' _ {} \;
exit=0

$ readlink /proc/self/ns/mnt
mnt:[4026553129]
exit=0

$ readlink /proc/1/ns/mnt
mnt:[4026553129]
exit=0

$ cat /proc/self/cgroup
13:net_cls,net_prio:/
12:memory:/user.slice/user-1001.slice/session-10473.scope
11:blkio:/user.slice
10:devices:/user.slice
9:misc:/
8:cpuset:/
7:rdma:/
6:hugetlb:/
5:cpu,cpuacct:/user.slice
4:pids:/user.slice/user-1001.slice/session-10473.scope
3:perf_event:/
2:freezer:/
1:name=systemd:/user.slice/user-1001.slice/session-10473.scope
0::/user.slice/user-1001.slice/session-10473.scope
exit=0

$ cat /proc/1/cgroup
13:net_cls,net_prio:/
12:memory:/user.slice/user-1001.slice/session-10473.scope
11:blkio:/user.slice
10:devices:/user.slice
9:misc:/
8:cpuset:/
7:rdma:/
6:hugetlb:/
5:cpu,cpuacct:/user.slice
4:pids:/user.slice/user-1001.slice/session-10473.scope
3:perf_event:/
2:freezer:/
1:name=systemd:/user.slice/user-1001.slice/session-10473.scope
0::/user.slice/user-1001.slice/session-10473.scope
exit=0

$ grep -E 'NoNewPrivs|CapEff' /proc/self/status
CapEff:	0000000000000000
NoNewPrivs:	1
exit=0

$ findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
TARGET SOURCE FSTYPE   OPTIONS
/dev   udev   devtmpfs ro,nosuid,nodev,noexec,relatime,size=1050582228k,nr_inodes=262645557,mode=755,inode64
/dev   tmpfs  tmpfs    rw,nosuid,nodev,relatime,mode=755,uid=1001,gid=1001,inode64
exit=0

$ ps -p 1 -o pid=,comm=
      1 codex
exit=0

$ cat /sys/module/cambricon_drv/version
6.5.52
exit=0

$ grep -hE "Device name:|Device inode path:|MLU Firmware Version:" /proc/driver/cambricon/mlus/*/information
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev0
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev1
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev2
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev3
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev4
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev5
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev6
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev7
MLU Firmware Version: 6.5.52
exit=0

$ for p in /sys/bus/pci/devices/*; do if [ "$(cat "$p/vendor" 2>/dev/null)" = 0xcabc ]; then printf "%s device=%s driver=%s\n" "${p##*/}" "$(cat "$p/device")" "$(readlink "$p/driver")"; fi; done
0000:4f:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:53:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:6f:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:73:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:af:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:b3:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:cf:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
0000:d3:00.0 device=0x0590 driver=../../../../../../../../../../../../bus/pci/drivers/cambricon-pci-drv_s1m1
exit=0

$ find /dev -type c \( -name "cambricon*" -o -name "cnmon*" \) -print
exit=0

$ cnmon info
cndev init failed: CNDEV_ERROR_NO_DRIVER.
exit=255
```

Additional checks exited 0.

```text
$ grep " /dev " /proc/self/mountinfo
2743 2742 0:5 / /dev ro,nosuid,nodev,noexec,relatime master:2 - devtmpfs udev rw,size=1050582228k,nr_inodes=262645557,mode=755,inode64
2827 2743 0:152 / /dev rw,nosuid,nodev,relatime - tmpfs tmpfs rw,mode=755,uid=1001,gid=1001,inode64
$ cat /sys/fs/cgroup/devices/user.slice/devices.list
a *:* rwm
$ find -L /sys/bus/pci/devices -maxdepth 2 -name vendor -exec grep -il "^0xcabc$" {} +
/sys/bus/pci/devices/0000:af:00.0/vendor
/sys/bus/pci/devices/0000:6f:00.0/vendor
/sys/bus/pci/devices/0000:d3:00.0/vendor
/sys/bus/pci/devices/0000:53:00.0/vendor
/sys/bus/pci/devices/0000:cf:00.0/vendor
/sys/bus/pci/devices/0000:4f:00.0/vendor
/sys/bus/pci/devices/0000:b3:00.0/vendor
/sys/bus/pci/devices/0000:73:00.0/vendor
```
