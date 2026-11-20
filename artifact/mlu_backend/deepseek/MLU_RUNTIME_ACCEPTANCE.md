# Native MLU runtime acceptance

| Check | Exit or status | Evidence |
| --- | --- | --- |
| `lspci -nn \| grep -i cabc` | 0 | Eight `cabc:0590` entries at 4f:00.0, 53:00.0, 6f:00.0, 73:00.0, af:00.0, b3:00.0, cf:00.0 and d3:00.0. |
| `cat /sys/module/cambricon_drv/version` | 0 | 6.5.52 |
| `grep -hE 'Device name:\|MLU Firmware Version:' /proc/driver/cambricon/mlus/*/information \| sort \| uniq -c` | 0 | Eight MLU590-M9 records, eight firmware 6.5.52 records. |
| `test -c "$p"` for `/dev/cambricon_ctl` and `/dev/cambricon_dev0` through `dev7` | 1 each | No visible Cambricon character nodes. |
| `cnmon info` | 255 | `cndev init failed: CNDEV_ERROR_NO_DRIVER.` MLU memory and utilization are unknown in this session. |
| `ps -eo pid,user,comm \| awk 'tolower($3) ~ /vllm/ {print}'` | 0 | No visible vLLM workers. Host workload occupancy is unknown. |
| `ldconfig -p \| grep -Ei 'cnrt\|cndrv\|cnnl\|cncl\|cndev'` | 0 | Only CNDev appears. |
| `ls /usr/local/neuware/include /usr/local/neuware/lib64` | 0 | `cndev.h` and CNDev 3.12.4. No CNRT, CNNL or CNCL in the inspected prefix. |
| `command -v cncc` | 1 | Absent from PATH. |
| `getconf GNU_LIBC_VERSION` | 0 | glibc 2.31 |
| Actual cached CNRT load | 1 | `GLIBC_2.34 not found`. |
| `make device-abi-mlu-test` | 0 | `PASS: MLU Device ABI v1 unavailable contract`. |
| Existing SDK-enabled diagnostic with cached library | 0 | Expected rejection, `diagnostic=0 count=0 vendor_status=0`. The vendor call was never reached. |

The loader and diagnostic checks ran from the NeurX root.

```sh
sd="$PWD/artifact/build/cnrt_integration"
python3 -S -c 'import ctypes,sys; ctypes.CDLL(sys.argv[1])' \
  "$sd/sdk/usr/local/neuware/lib64/libcnrt.so"
LD_LIBRARY_PATH="$sd/sdk/usr/local/neuware/lib64" \
  python3 -S "$sd/check_diagnostic.py" "$sd/with-sdk/libneurx_backend_mlu.so" 0
```

CNRT loading, initialization, eight-device runtime enumeration and property retrieval remain blocked. The v1 plugin exposes explicit unavailability. No workload was interrupted and no vendor packages, proxies, drivers or system libraries were changed. The existing native diagnosis gives the administrator-side device checks and explains why a vendor-approved Focal package manifest is still needed. [Native administrator checklist](../native_deployment/diagnosis/ADMIN_ACTIONS.md) · [Compatibility matrix](../native_deployment/diagnosis/NEUWARE_COMPATIBILITY_MATRIX.md)
