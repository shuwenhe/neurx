# Device-access remediation

**BLOCKED** pending an authorized environment with the actual MLU nodes. This is an administrator handoff. No mounts, nodes, cgroups or system configuration were modified.

## 1. Capture matched evidence

Run this read-only command block in the authorized SSH session and again under the NeurX execution identity in the intended execution environment. Return both transcripts, along with the platform's executor type and provisioning method.

```bash
run() {
  printf '\n$'; printf ' %q' "$@"; printf '\n'
  "$@"
  printf 'exit=%s\n' "$?"
}
run hostname
run id
run readlink /proc/self/ns/mnt
run readlink /proc/1/ns/mnt
run readlink /proc/self/ns/pid
run ps -p 1 -o pid=,comm=
run findmnt -T /dev -o TARGET,SOURCE,FSTYPE,OPTIONS
run grep ' /dev ' /proc/self/mountinfo
run stat -Lc '%n %F %a %U:%G %t:%T' /dev/cambricon_ctl /dev/cambricon_dev{0..7}
run grep -hE 'Device inode path:|Device Major:|Device Minor:' /proc/driver/cambricon/mlus/*/information
run cat /proc/self/cgroup
```

Check each board node against its driver record. `stat` formats `%t:%T` in hex, so expected board device IDs are `1fc:0` through `1fc:7`. Obtain the control and any required IPC node IDs from the host and Cambricon's documentation. Capture ownership, mode and group under the actual service account.

## 2. Use the supported provisioning route

Cambricon documents using its driver-provided device inode paths. OpenAI documents OS-level sandboxing and a separately provisioned self-hosted executor for administrators who control the environment. I found no documented Cambricon device allowlist or passthrough option for this managed Codex session. Changing workspace write permissions would not establish device exposure. The exact device assignment setting is **UNKNOWN** until the administrator identifies the actual executor and confirms supported provisioning with its owner. [Cambricon device checks](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_pre_installation_actions/index.html) · [Codex sandbox behavior](https://openai.com/index/inside-the-codex-sandbox/) · [OpenAI self-hosted executor option](https://developers.openai.com/api/docs/guides/agents-api/environments/self-hosted)

Ask the administrator to provision an approved native hardware execution session under the NeurX identity with the real control, assigned board and vendor-required auxiliary nodes, using the platform's documented device allocation mechanism. Request visibility to all eight only if authorized for the inventory check, and reserve an idle board before execution. If the current Codex executor has no supported assignment mechanism, have the administrator run the hardware validation in an authorized native SSH or batch session and return the evidence. No sandbox disablement or manual device creation is part of this handoff.

## 3. Verify actual access after allocation

Only after administrator approval, run the following as the intended NeurX identity on the assigned device. Set `ALLOCATED_MLU_NODE` to the exact path supplied by the administrator. An open failure reports the kernel errno. A successful open is one gate. CNRT remains a separate gate.

```bash
python3 -S - /dev/cambricon_ctl "${ALLOCATED_MLU_NODE:?administrator must supply the allocated node}" <<'PY'
import os
import stat
import sys

for path in sys.argv[1:]:
    try:
        flags = os.O_RDWR | os.O_CLOEXEC | os.O_NOFOLLOW
        with os.fdopen(os.open(path, flags), "rb", buffering=0) as device:
            info = os.fstat(device.fileno())
            if not stat.S_ISCHR(info.st_mode):
                raise OSError("opened object is not a character device")
            print(f"{path}: open OK, major={os.major(info.st_rdev)} minor={os.minor(info.st_rdev)}")
    except OSError as error:
        print(f"{path}: open FAIL errno={error.errno}: {error}", file=sys.stderr)
        sys.exit(1)
PY
```

With an approved, separately verified Focal SDK, record successful CNRT initialization for the assigned device using its documented API, followed by enumeration and device properties in the same execution context. The [existing typed NeurX diagnostic](../cnrt_integration/HARDWARE_ACCEPTANCE.md#dedicated-enumeration-probe) covers enumeration. Where the approved release provides implicit initialization, capture the real initialization-bearing call and successful device selection separately. Preserve the device ordinal, vendor codes, version and exit status. Do not use cached CNRT 6.12.1 for this check.
