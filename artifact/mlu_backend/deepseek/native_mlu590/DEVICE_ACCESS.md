# Native device access

**BLOCKED.** All eight PCI `cabc:0590` devices are visible at `4f:00.0`, `53:00.0`, `6f:00.0`, `73:00.0`, `af:00.0`, `b3:00.0`, `cf:00.0`, and `d3:00.0`. Each is bound to `cambricon-pci-drv_s1m1`. Driver and all eight firmware records report 6.5.52.

| Command | Exit | Observation |
| --- | ---: | --- |
| `lspci -nnk -d cabc:0590` | 0 | Eight bound devices |
| `cat /sys/module/cambricon_drv/version` | 0 | 6.5.52 |
| `grep -h 'MLU Firmware Version:' /proc/driver/cambricon/mlus/*/information \| sort \| uniq -c` | 0 | Eight records at 6.5.52 |
| `id` | 0 | UID and GID 1001, supplementary group 65534 |
| `findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS` | 0 | A session tmpfs with `nodev` overlays devtmpfs |
| `test -c "$p"` for `/dev/cambricon_ctl` and `/dev/cambricon_dev0` through `dev7` | 1 for each | Zero visible character nodes. Access permissions cannot be assessed. |
| `cnmon info` | 255 | `cndev init failed: CNDEV_ERROR_NO_DRIVER.` |

The administrator needs to inspect those paths on the host and expose the vendor-required device node set through the approved NeurX execution environment. Verify node type, permissions and access under the NeurX account, then reserve an idle MLU for execution. The host-side node state and workload occupancy remain unknown. No privilege escalation or device configuration change was attempted. [Administrator checklist](../../native_deployment/diagnosis/ADMIN_ACTIONS.md)

## Recovery recheck

**CONFIRMED** in this session. The effective `/dev` is a `nodev` tmpfs over devtmpfs. Only the exposed layer was inspected. Driver-reported paths expect major 508 and minors 0–7. The visible v1 devices cgroup reports `a *:* rwm`, which supplies no evidence of a cgroup denial. Device ownership, host-side node presence and a usable allocation are **UNKNOWN**. The current mount namespace matches the visible Codex PID 1 and provides no host-namespace comparison. Recovering device access requires administrator-provided host evidence and sanctioned device allocation.

```text

$ lspci -nn -d cabc:0590
4f:00.0 Processing accelerators [1200]: Device [cabc:0590]
53:00.0 Processing accelerators [1200]: Device [cabc:0590]
6f:00.0 Processing accelerators [1200]: Device [cabc:0590]
73:00.0 Processing accelerators [1200]: Device [cabc:0590]
af:00.0 Processing accelerators [1200]: Device [cabc:0590]
b3:00.0 Processing accelerators [1200]: Device [cabc:0590]
cf:00.0 Processing accelerators [1200]: Device [cabc:0590]
d3:00.0 Processing accelerators [1200]: Device [cabc:0590]
exit=0

$ for p in /sys/bus/pci/devices/*; do if [ "$(cat "$p/vendor" 2>/dev/null)" = 0xcabc ]; then printf "%s %s %s\n" "${p##*/}" "$(cat "$p/device")" "$(basename "$(readlink "$p/driver")")"; fi; done
0000:4f:00.0 0x0590 cambricon-pci-drv_s1m1
0000:53:00.0 0x0590 cambricon-pci-drv_s1m1
0000:6f:00.0 0x0590 cambricon-pci-drv_s1m1
0000:73:00.0 0x0590 cambricon-pci-drv_s1m1
0000:af:00.0 0x0590 cambricon-pci-drv_s1m1
0000:b3:00.0 0x0590 cambricon-pci-drv_s1m1
0000:cf:00.0 0x0590 cambricon-pci-drv_s1m1
0000:d3:00.0 0x0590 cambricon-pci-drv_s1m1
exit=0

$ grep -hE "Device name:|Device inode path:|Device Major:|Device Minor:|MLU Firmware Version:" /proc/driver/cambricon/mlus/*/information
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev0
Device Major: 508
Device Minor: 0
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev1
Device Major: 508
Device Minor: 1
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev2
Device Major: 508
Device Minor: 2
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev3
Device Major: 508
Device Minor: 3
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev4
Device Major: 508
Device Minor: 4
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev5
Device Major: 508
Device Minor: 5
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev6
Device Major: 508
Device Minor: 6
MLU Firmware Version: 6.5.52
Device name: MLU590-M9
Device inode path: /dev/cambricon_dev7
Device Major: 508
Device Minor: 7
MLU Firmware Version: 6.5.52
exit=0

$ cat /sys/module/cambricon_drv/version
6.5.52
exit=0

$ id
uid=1001(gaozhi) gid=1001(gaozhi) groups=1001(gaozhi),65534(nogroup)
exit=0

$ readlink /proc/self/ns/mnt; readlink /proc/1/ns/mnt; ps -p 1 -o comm=
mnt:[4026552919]
mnt:[4026552919]
codex
exit=0

$ findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
TARGET SOURCE FSTYPE   OPTIONS
/dev   udev   devtmpfs ro,nosuid,nodev,noexec,relatime,size=1050582228k,nr_inodes=262645557,mode=755,inode64
/dev   tmpfs  tmpfs    rw,nosuid,nodev,relatime,mode=755,uid=1001,gid=1001,inode64
exit=0

$ cat /proc/self/cgroup; cat /sys/fs/cgroup/devices/user.slice/devices.list
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
a *:* rwm
exit=0

$ stat -Lc "%n %F %a %U:%G %t:%T" /dev/cambricon_ctl /dev/cambricon_dev{0..7}
stat: cannot stat '/dev/cambricon_ctl': No such file or directory
stat: cannot stat '/dev/cambricon_dev0': No such file or directory
stat: cannot stat '/dev/cambricon_dev1': No such file or directory
stat: cannot stat '/dev/cambricon_dev2': No such file or directory
stat: cannot stat '/dev/cambricon_dev3': No such file or directory
stat: cannot stat '/dev/cambricon_dev4': No such file or directory
stat: cannot stat '/dev/cambricon_dev5': No such file or directory
stat: cannot stat '/dev/cambricon_dev6': No such file or directory
stat: cannot stat '/dev/cambricon_dev7': No such file or directory
exit=1

$ cnmon info
cndev init failed: CNDEV_ERROR_NO_DRIVER.
exit=255

$ getconf GNU_LIBC_VERSION; grep PRETTY_NAME /etc/os-release; uname -m
glibc 2.31
PRETTY_NAME="Ubuntu 20.04.6 LTS"
x86_64
exit=0

$ ldconfig -p | grep -Ei "cnrt|cndrv|cnnl|cncl|cndev"
	libcndev.so (libc6,x86-64) => /lib/x86_64-linux-gnu/libcndev.so
exit=0

$ command -v cncc
exit=1

$ dpkg-query -W cambricon-mlu-driver-dkms cndev cntoolkit
cambricon-mlu-driver-dkms	6.5.52-30.ubuntu20.04
cndev:amd64	3.12.4-1.ubuntu20.04
cntoolkit:amd64	3.13.6-1.ubuntu22.04
exit=0
```
