# CNRT initialization

**BLOCKED.** CNRT initialization and runtime enumeration were not attempted because the current process lacks device nodes and an approved runtime. The eight PCI entries establish host inventory. They do not establish CNRT enumeration or usable device access.

The existing Device ABI v1 registration, S lifecycle boundary and typed CNRT diagnostic were preserved. Initialization, eight-device enumeration, allocation, H2D, D2H, stream creation, synchronization, cleanup and vendor error propagation through the production runtime remain unverified. [Device access](DEVICE_ACCESS.md) · [SDK evidence](NEUWARE_COMPATIBILITY.md)

## Recovery gate

**NOT_TESTED** for CNRT initialization, runtime enumeration, and device property retrieval. **BLOCKED** by zero exposed character nodes and no approved native SDK. `cnmon info` exited 255 with `CNDEV_ERROR_NO_DRIVER`. The existing optional NeurX diagnostic was not invoked against any vendor library during recovery. Once both gates are satisfied, require positive, real CNRT enumeration and properties for the allocated MLU590-M9 before allocating or submitting work. Keep Device ABI v1 and the typed native boundary unchanged until the supported API is confirmed.
