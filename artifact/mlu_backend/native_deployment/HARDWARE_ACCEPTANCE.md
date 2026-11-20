# Ordered hardware acceptance

| Gate | Status | Evidence required |
| --- | --- | --- |
| 1. Enumeration | **BLOCKED** | The native NeurX diagnostic must produce successful real CNRT enumeration and a count of eight. Cross-check against the host PCI inventory. Actual attempt returned diagnostic 0 because the cached library could not load. |
| 2. CNRT initialization | **NOT RUN** | Record a successful native initialization-bearing call, select the administrator-assigned device and verify the current device and runtime version. Use the release-specific documented API. |
| 3. Memory | **NOT RUN** | Allocate device memory and release it successfully. Record bytes, ordinal, exit status and cleanup results. |
| 4. Data transfer | **NOT RUN** | H2D into A, D2D from A to B, then D2H from B. Check all bytes and record transfer times by direction. |
| 5. Stream | **NOT RUN** | Create a queue, issue an asynchronous operation, synchronize, verify data and destroy the queue. Log statuses, ordering and synchronization time. |
| 6. Vector Add | **NOT RUN** | Compile and execute a genuine BANG C FP32 add kernel for the assigned MLU590, compare every output with CPU FP32 and record kernel time, transfer times, sync time, error and exit status. |

Gate 1 stopped the sequence. No card was reserved or used. The first kernel should use a fixed recorded seed and inputs with signed values, including zeros and a non-aligned length to exercise tails. Record element count, bytes, exact compiler version, flags, device ordinal, and device event timing. Use `abs(actual - expected) <= 1e-6 + 1e-6 * abs(expected)`, reject nonfinite values, and report mismatch count and maximum absolute error. CPU reference calculation is for verification. Any kernel-launch, synchronization, transfer, cleanup or reference failure makes the test fail.
