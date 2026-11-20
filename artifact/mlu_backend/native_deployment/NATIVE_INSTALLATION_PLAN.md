# Administrator checklist for native deployment

1. Obtain a vendor-supported Ubuntu 20.04 amd64 package manifest via the enterprise Cambricon distribution channel. Request exact versions and checksums for CNRT, CNDrv userspace, CNNL, CNCL and CNCC, explicit compatibility with MLU590-M9 and driver/firmware 6.5.52, and the documented device-node access requirements. Stop if the approved tuple requires altering the host driver or glibc. [Cambricon SDK channel](https://developer.cambricon.com/index/search/index.html?q=590)
2. On the administrator's native host session, run the read-only checks below and retain command output and exits. Map the eight nodes to the PCI BDFs in [Host audit](HOST_AUDIT.md). Confirm per-card memory and utilization, find the active vLLM workers, and correlate their device allocation with vendor-supported telemetry or open descriptors. Missing process visibility or unavailable telemetry leaves occupancy unknown.
3. Stage verified packages under the NeurX workspace with `dpkg-deb -x`. Check `sha256sum -c SHA256SUMS` against the parsed vendor manifest and inspect `dpkg-deb -f "$pkg" Package Version Architecture Depends` for each file. Use `readelf --version-info "$library"` to check GLIBC and GLIBCXX symbol versions and a native `ctypes.CDLL` to check actual loadability. Stop on unresolved dependencies. Do not run package maintainer scripts or change global loader paths during this preflight.
4. Have the administrator expose the documented driver nodes under the site's normal device-allocation policy. Verify character-node type, ownership and permissions from the NeurX account. Obtain explicit allocation of an idle card for execution. Do not infer an idle card from current namespace visibility.
5. Build the SDK-enabled diagnostic in a fresh workspace output directory using the approved header path. Set the runtime library search path for this process only. Run the [existing enumeration command](../cnrt_integration/HARDWARE_ACCEPTANCE.md#dedicated-enumeration-probe) under the NeurX account and retain the vendor result and count. Count eight is required for the inventory gate. Select only the administrator-assigned device for subsequent hardware tests. Follow [the ordered gates](HARDWARE_ACCEPTANCE.md).

```bash
id
cat /etc/os-release
getconf GNU_LIBC_VERSION
uname -rm
cat /sys/module/cambricon_drv/version
grep -H -E 'Device name:|Driver Version:|MLU Firmware Version:' /proc/driver/cambricon/mlus/*/information
stat -c '%n %F %a %U:%G %t:%T' /dev/cambricon_ctl /dev/cambricon_dev{0..7}
cnmon info
ps -eo pid,user,comm | awk 'tolower($3) ~ /vllm/ {print}'
```

The administrator commands were prepared but not executed in the host's unrestricted device context. No request was sent to the vendor.

For the approved native SDK, substitute its staged header directory and library directory below. These commands are conditional on items 1–4.

```bash
out="$PWD/artifact/build/mlu_native_approved"
make DEVICE_ABI_BUILD_DIR="$out" DEVICE_ABI_MLU_CNRT_INCLUDE="$approved_include_dir" device-abi-mlu-test
LD_LIBRARY_PATH="$approved_lib_dir" python3 - "$out/libneurx_backend_mlu.so" <<'PY'
import ctypes as c
import sys

plugin = c.CDLL(sys.argv[1])
diagnose = plugin.neurx_mlu_cnrt_diagnose
diagnose.argtypes = [c.POINTER(c.c_uint), c.POINTER(c.c_uint32)]
diagnose.restype = c.c_int
count, native = c.c_uint(), c.c_uint32()
status = diagnose(c.byref(count), c.byref(native))
print(f"diagnostic={status} count={count.value} vendor_status={native.value}")
sys.exit(0 if status == 6 and count.value == 8 and native.value == 0 else 1)
PY
```
