# Administrator actions

**BLOCKED** pending host-side evidence and approved allocation. Run the read-only commands below in the authorized native host context, then run the device-view checks again as the NeurX service account in its assigned execution environment. Preserve individual exits and outputs.

```bash
run() {
  printf '\n$'; printf ' %q' "$@"; printf '\n'
  "$@"
  printf 'exit=%s\n' "$?"
}
run id
run readlink /proc/self/ns/mnt
run findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
run lspci -nnk -d cabc:0590
run cat /sys/module/cambricon_drv/version
run stat -Lc '%n %F %a %U:%G %t:%T' /dev/cambricon_ctl /dev/cambricon_dev{0..7}
run cnmon info
```

The expected device node IDs are major 508 and minors 0–7 in decimal. GNU `stat` formats `%t:%T` in hexadecimal, so the expected major is `1fc`. Confirm the full required node set and the control node's ID with Cambricon. If host nodes exist, the administrator must use the site's approved execution-environment allocation mechanism to expose the real nodes and verify permissions under the NeurX identity. If nodes are missing on the host, send the driver and device evidence to the driver owner for investigation before changing any configuration. Confirm current occupancy and reserve an idle MLU for the test.

Provide the vendor-confirmed Focal bundle and its checksum manifest. Inspect it in the workspace using `sha256sum -c SHA256SUMS`, `dpkg-deb -f "$pkg" Package Version Architecture Depends`, and `readelf -d` / `readelf --version-info` on the approved payload. No root action is prescribed because the allocator and the host-side node state are unknown. No device node creation, mounting, cgroup change or driver restart was attempted.
