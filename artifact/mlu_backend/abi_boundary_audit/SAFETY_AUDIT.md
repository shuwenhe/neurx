# Safety audit

- The immutable ABI table uses the existing header and the existing registry. No CPU, CUDA, or CANN implementation was edited during this audit.
- A successful plugin load establishes the presence of a valid ABI table. A loadable CNRT library establishes only that the process loader could open it. Both paths leave the device count at zero.
- The loader handle is retained in its native pointer type and released in the same call. A loader failure returns unavailable and a release failure has its own diagnostic. The loadable fixture verifies that a successful check holds no reference afterward. A failing `dlclose` was not forced.
- No resources are allocated on device, successful device handles fabricated, input strings read, or caller memory freed. The tested null text inputs, signed extrema, invalid handle values, and zero handles all reject.
- The adapter returns borrowed static ASCII strings. Callers must copy them if they need them after plugin unload. The public registry keeps its plugin reference and validates backend names.
- The loader-only fixture is a generic shared object with one inert marker. It has no CNRT symbols and exercises only dynamic loading and release.
- Real runtime initialization, transfers, synchronization, and Vector Add remain a separate hardware gate. This session lacks visible device nodes and compatible CNRT.
