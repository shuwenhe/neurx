# GEMM performance results

**BLOCKED.** Zero CNNL matmul executions ran on MLU590. No kernel latency, transfer latency or TFLOPS was measured.

After each dtype and shape passes numerical acceptance, use a pre-created queue, handle, descriptors and workspace. Record the SDK package versions, driver/firmware, device ordinal, algorithm, dimensions, input/output/accumulator dtypes, data layout, exact command, exit code, and host/device memory use. Record warm-up and measured counts. Use the approved SDK's device-event timing for the kernel interval and report median and P95 from individual measurements. Record H2D, D2H and host synchronization timings separately. Record temperature, power and utilization where accessible.

Compute achievable throughput from measured kernel time only, using `2*M*N*K / (kernel_seconds * 1e12)`. State whether the reported TFLOPS uses the median or a different statistic, and keep CPU reference wall time in a separate column. Include failed cases with their exact status and vendor diagnostic. See [numerical preparation](GEMM_NUMERICAL_RESULTS.md) and [SDK gate](CNNL_SDK_COMPATIBILITY.md).
