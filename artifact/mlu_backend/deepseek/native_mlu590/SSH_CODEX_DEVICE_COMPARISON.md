# SSH and Codex device comparison

**CONFIRMED** for the evidence available. The earlier SSH session on `tza-0a09-ai01-em9` listed the Cambricon control node and all eight device paths, per the user. The current Codex session reports the same hostname and cannot resolve any of those paths. The SSH listing is user-supplied historical evidence. No SSH mount or device metadata was supplied or collected by Codex.

| Observation | Earlier SSH | Current Codex |
| --- | --- | --- |
| Hostname | `tza-0a09-ai01-em9`, user-reported | `tza-0a09-ai01-em9` |
| Mount namespace | **UNKNOWN** | `mnt:[4026552919]` for self and visible PID 1 |
| PID namespace and PID 1 | **UNKNOWN** | `pid:[4026552921]` for self and PID 1. PID 1 is `codex`. |
| Effective `/dev` | Source, filesystem and options **UNKNOWN** | UID-1001 tmpfs with `rw,nosuid,nodev` over devtmpfs whose visible mount options are `ro,nosuid,nodev,noexec` |
| `cambricon_ctl`, `cambricon_dev0`–`dev7` | Nine listed paths, user-reported | All nine returned `No such file or directory` |
| Major/minor and modes | Actual inode numbers and owner/mode **UNKNOWN** | Actual inode numbers unavailable. Shared kernel driver records expect major 508 decimal and minors 0–7 for the eight device paths. No control-node ID was established. |
| Device policy | **UNKNOWN** | Visible v1 devices cgroup `/user.slice` reports `a *:* rwm`. No effective capabilities and `NoNewPrivs=1`. |

**CONFIRMED** that Codex's execution view has a private-looking restricted `/dev` layer and its own visible Codex process tree. Together with the user-supplied SSH listing, the evidence supports a device-exposure difference between sessions. The effective `/dev` overlay is the immediate barrier in Codex. The SSH mount namespace ID and options still need a paired capture for direct comparison. The launch or provisioning mechanism responsible is **UNKNOWN**. Missing Docker/Podman marker files do not identify the runtime, and the visible cgroup rule cannot prove an open would succeed.

## Current Codex command output

```text

$ hostname; id
tza-0a09-ai01-em9
uid=1001(gaozhi) gid=1001(gaozhi) groups=1001(gaozhi),65534(nogroup)
exit=0

$ readlink /proc/self/ns/mnt; readlink /proc/1/ns/mnt; readlink /proc/self/ns/pid; readlink /proc/1/ns/pid; ps -p 1 -o pid=,comm=
mnt:[4026552919]
mnt:[4026552919]
pid:[4026552921]
pid:[4026552921]
      1 codex
exit=0

$ findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
TARGET SOURCE FSTYPE   OPTIONS
/dev   udev   devtmpfs ro,nosuid,nodev,noexec,relatime,size=1050582228k,nr_inodes=262645557,mode=755,inode64
/dev   tmpfs  tmpfs    rw,nosuid,nodev,relatime,mode=755,uid=1001,gid=1001,inode64
exit=0

$ grep " /dev " /proc/self/mountinfo
2743 2742 0:5 / /dev ro,nosuid,nodev,noexec,relatime master:2 - devtmpfs udev rw,size=1050582228k,nr_inodes=262645557,mode=755,inode64
2827 2743 0:152 / /dev rw,nosuid,nodev,relatime - tmpfs tmpfs rw,mode=755,uid=1001,gid=1001,inode64
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

$ grep -hE "Device inode path:|Device Major:|Device Minor:" /proc/driver/cambricon/mlus/*/information
Device inode path: /dev/cambricon_dev0
Device Major: 508
Device Minor: 0
Device inode path: /dev/cambricon_dev1
Device Major: 508
Device Minor: 1
Device inode path: /dev/cambricon_dev2
Device Major: 508
Device Minor: 2
Device inode path: /dev/cambricon_dev3
Device Major: 508
Device Minor: 3
Device inode path: /dev/cambricon_dev4
Device Major: 508
Device Minor: 4
Device inode path: /dev/cambricon_dev5
Device Major: 508
Device Minor: 5
Device inode path: /dev/cambricon_dev6
Device Major: 508
Device Minor: 6
Device inode path: /dev/cambricon_dev7
Device Major: 508
Device Minor: 7
exit=0

$ grep "^10:devices:" /proc/self/cgroup; cat /sys/fs/cgroup/devices/user.slice/devices.list
10:devices:/user.slice
a *:* rwm
exit=0

$ grep -E 'NoNewPrivs|CapEff' /proc/self/status
CapEff:	0000000000000000
NoNewPrivs:	1
exit=0

$ ls -ld /.dockerenv /run/.containerenv
ls: cannot access '/.dockerenv': No such file or directory
ls: cannot access '/run/.containerenv': No such file or directory
exit=2
```
