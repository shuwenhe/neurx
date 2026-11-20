# Device visibility and permissions

| Command | Exit | Result |
| --- | ---: | --- |
| `id` | 0 | UID and GID 1001, supplementary group 65534 |
| `cat /sys/module/cambricon_drv/version` | 0 | Loaded driver 6.5.52 |
| `grep -l '^Device name: MLU590-M9' /proc/driver/cambricon/mlus/*/information \| wc -l` | 0 | Eight kernel records |
| `grep -H -i 'firmware\|driver version' /proc/driver/cambricon/mlus/*/information` | 0 | 6.5.52 driver and firmware |
| `ls -ld /dev/cambricon* /dev/cnmon*` | 2 | No matching nodes in this session |
| `cnmon info` | 255 | `CNDEV_ERROR_NO_DRIVER` |

The kernel records name `/dev/cambricon_dev0` through `/dev/cambricon_dev7` at major 508. For each of `/dev/cambricon_ctl`, `/dev/cambricon_dev0`, `/dev/cambricon_ipcm0`, and `/dev/cnmon_dev`, both `test -c "$p"` and `test -r "$p" && test -w "$p"` returned 1. Node ownership, mode and actual open permissions cannot be established in a namespace where the nodes are absent. No device access, process termination, driver change, or reboot was attempted.
