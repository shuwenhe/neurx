# Native MLU host audit

Read-only audit on 2026-11-20. The current execution namespace can read host kernel inventory. Its device and process views are restricted.

| Command | Exit | Observation |
| --- | ---: | --- |
| `cat /etc/os-release` | 0 | Ubuntu 20.04.6 LTS, Focal |
| `getconf GNU_LIBC_VERSION` | 0 | glibc 2.31 |
| `uname -rm` | 0 | 5.15.0-139-generic x86_64 |
| `id` | 0 | UID and GID 1001, supplementary group 65534 |
| `cat /sys/module/cambricon_drv/version` | 0 | 6.5.52 |
| `grep -H -E 'Device name:\|Device inode path:\|Driver Version:\|MLU Firmware Version:' /proc/driver/cambricon/mlus/*/information` | 0 | Eight MLU590-M9 records, driver v6.5.52 and firmware 6.5.52 on all eight |
| `ls -l /dev/cambricon* /dev/cnmon*` | 2 | Both patterns had no matches |
| `test -c "$p"` and `test -r "$p" && test -w "$p"` | 1 each | Checked `cambricon_dev0` through `cambricon_dev7`, `cambricon_ctl`, `cambricon_ipcm0` and `cnmon_dev`. No node ownership, modes or open permissions could be measured. |
| `sh -c 'command -v cnmon; command -v cncc'` | 127 | CNMon at `/usr/bin/cnmon`. CNCC absent from PATH. |
| `dpkg-query -S /usr/bin/cnmon` | 0 | Owned by the Cambricon driver package. Binary version string 6.5.52. |
| `cnmon --version`, `cnmon info` | 255 each | Both reported `CNDEV_ERROR_NO_DRIVER` in this namespace. Utilization and memory usage are unobservable here. |
| `ldconfig -p \| grep -Ei 'cnrt\|cndrv\|cnnl\|cndev\|cncl'` | 0 | Only `libcndev.so` |
| `ls -l /usr/local/neuware/include /usr/local/neuware/lib64` | 0 | `cndev.h`, CNDev 3.12.4 library and symlink |
| `dpkg-query -W \| grep -Ei 'cambricon\|cntoolkit\|cndev\|cnrt\|cnnl\|cncl\|cncc'` | 0 | Driver package 6.5.52-30.ubuntu20.04, CNDev 3.12.4-1.ubuntu20.04, toolkit repository package 3.13.6-1.ubuntu22.04 |
| `find /usr/local/neuware /usr/include /usr/lib -type f \( -name cnrt.h -o -name cnnl.h -o -name cncl.h -o -name 'libcnrt.so*' -o -name 'libcnnl.so*' -o -name 'libcncl.so*' \) -print` | 0 | No matches in inspected system directories |
| `ps -eo pid,user,comm \| awk 'tolower($3) ~ /vllm/ {print}'` | 0 | No vLLM processes visible in this process namespace. Host workloads and their device allocations remain unknown. |
| `bash artifact/build/mlu_native_audit/audit.sh` | 0 | Command-by-command output in the local ignored `artifact/build/mlu_native_audit/host.log`. Individual exits are recorded above. |

The PCI vendor/device IDs are `cabc:0590` for all eight entries. Cross-check with `for p in /sys/bus/pci/devices/*; do if [ "$(cat "$p/vendor" 2>/dev/null)" = 0xcabc ]; then printf '%s ' "${p##*/}"; cat "$p/device"; fi; done` (exit 0).

| Node recorded by driver | PCI BDF |
| --- | --- |
| `cambricon_dev0` | 0000:4f:00.0 |
| `cambricon_dev1` | 0000:53:00.0 |
| `cambricon_dev2` | 0000:6f:00.0 |
| `cambricon_dev3` | 0000:73:00.0 |
| `cambricon_dev4` | 0000:af:00.0 |
| `cambricon_dev5` | 0000:b3:00.0 |
| `cambricon_dev6` | 0000:cf:00.0 |
| `cambricon_dev7` | 0000:d3:00.0 |
