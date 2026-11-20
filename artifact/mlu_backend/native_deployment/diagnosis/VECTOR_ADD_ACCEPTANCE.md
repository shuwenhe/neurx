# Ordered Vector Add acceptance

| Gate | Status | Evidence or required evidence |
| --- | --- | --- |
| 1. MLU device-node visibility | **BLOCKED** | Zero Cambricon device nodes in the NeurX process view. |
| 2. Compatible native Neuware load | **BLOCKED** | Cached library failed to load on glibc 2.31. Exact supported Focal package combination remains unverified. |
| 3. CNRT initialization | **BLOCKED** | Requires a successful vendor call from the NeurX process after library and symbol resolution. |
| 4. Eight devices enumerate | **BLOCKED** | Requires successful CNRT enumeration of eight cards from NeurX. PCI inventory does not measure this gate. |
| 5. Context, memory, transfers and synchronization | **BLOCKED** | Use the v1 plugin on an administrator-assigned card. In order, record context creation, allocation, H2D, D2H, stream creation, synchronization and resource release. Verify transferred bytes and capture vendor status and timing. |
| 6. Real Vector Add | **BLOCKED** | Implement only after the earlier checks pass. Compile a real device kernel for the assigned MLU590-M9 with vendor CNCC, launch with device buffers, synchronize and copy back. |
| 7. Numerical comparison | **BLOCKED** | Compare every FP32 element against a CPU reference. Use a recorded input seed and size, reject nonfinite output, and record maximum absolute error and mismatches. Proposed tolerance is `abs(result - reference) <= 1e-6 + 1e-6 * abs(reference)`. |

Record source and compiler versions, commands, exit codes, ordinal, sizes, kernel execution time and H2D/D2H timings separately. No Vector Add was implemented or run during this phase because the specified prerequisites have not passed. No timing or accuracy results exist.
