# Administrator actions

**BLOCKED** pending an administrator-operated host comparison and vendor package manifest. These commands were prepared for the administrator's sanctioned host session. They were not run with elevated privileges.

```bash
run() {
  printf '\n$'; printf ' %q' "$@"; printf '\n'
  "$@"; printf 'exit=%s\n' "$?"
}
run id
run readlink /proc/self/ns/mnt
run readlink /proc/1/ns/mnt
run findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
run grep ' /dev ' /proc/self/mountinfo
run cat /proc/self/cgroup
run bash -c 'ls -l /dev/cambricon* /dev/cnmon*'
run stat -Lc '%n %F %a %U:%G %t:%T' /dev/cambricon_ctl /dev/cambricon_dev{0..7}
run cat /sys/fs/cgroup/devices/user.slice/devices.list
run cnmon info
run bash -c 'ps -eo pid,user,comm | awk '\''tolower($3) ~ /vllm/ {print}'\'''
```

1. If the host has the nodes, compare their ownership and major/minor numbers with the driver records. Use the site's approved device allocation mechanism to give the NeurX account an execution session with the vendor-required node set and policy. Retest `findmnt -T /dev` and `stat` from that account. The current environment exposes neither the underlying host namespace nor its launch configuration, so no specific mutating command is prescribed.
2. If the host also lacks the nodes, collect read-only evidence before deciding on remediation. Run `journalctl -k -b --no-pager | grep -Ei 'cambricon|cabc'` and `lsmod | grep cambricon` in the administrator session. Consult the driver owner before any driver or udev action. Confirm occupancy with vendor telemetry and reserve a card before executing tests.
3. Obtain official Focal amd64 packages for the exact tuple. Ask for CNRT, CNDrv, CNNL, CNCC, CNCL, CNDev and CNMon versions, checksums, driver range, and documented node requirements. In the workspace, check `sha256sum -c SHA256SUMS`, `dpkg-deb -f "$pkg" Package Version Architecture Depends` and `dpkg-deb -x "$pkg" "$stage"`. Extraction runs no maintainer scripts. Check `readelf --version-info "$stage/usr/local/neuware/lib64/libcnrt.so"` and actual loading on glibc 2.31 before enabling the runtime.
4. Run [the native SDK build and enumeration commands](../NATIVE_INSTALLATION_PLAN.md#administrator-checklist-for-native-deployment) with the approved package directory. Record device paths and native status. Progress through [the gates](VECTOR_ADD_ACCEPTANCE.md) only after both blockers are resolved. No system upgrade, workload interruption or privilege escalation is part of this checklist.
