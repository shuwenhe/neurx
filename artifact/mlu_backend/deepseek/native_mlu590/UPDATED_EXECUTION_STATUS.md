# Native MLU590-M9 execution update

**BLOCKED.** The new SSH evidence narrows the problem to a difference in device exposure between the earlier SSH terminal and the current Codex execution view. The historical SSH listing reports all nine paths. The current Codex `stat` exits 1 with none visible, and an effective `nodev` tmpfs overlays `/dev`. The SSH namespace ID, mount options and actual device IDs still need a matching transcript. The exact administrator provisioning mechanism is unknown.

| Gate | Status |
| --- | --- |
| Earlier SSH device listing | User-reported evidence |
| Codex device node visibility | Confirmed absent in this session |
| Authorized device assignment | Blocked |
| Actual device open | Not tested |
| Approved native Neuware tuple | Existing investigation preserved and unresolved |
| CNRT initialization and device enumeration | Not tested |
| Native workloads | Not tested |

No incompatible CNRT load was retried. No CPU operator, simulation, or hardware kernel ran. The previous Neuware compatibility report and repository changes were preserved. Only the three comparison and handoff reports were added.

[Comparison evidence](SSH_CODEX_DEVICE_COMPARISON.md) · [Administrator remediation](DEVICE_ACCESS_REMEDIATION.md) · [Existing Neuware compatibility evidence](NEUWARE_COMPATIBILITY.md)
