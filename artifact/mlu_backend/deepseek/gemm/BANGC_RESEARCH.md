# BANG C MLU590 research

**DESIGN_COMPLETE for an exploratory kernel.** CNCC and the approved BANG headers were unavailable. No BANG kernel compiled or ran.

| Area | Evidence and decision |
| --- | --- |
| Target | Cambricon CNToolkit 3.8.4 lists MLU590-H8/M9 under `mtp_592` and advertises the corresponding CNCC architecture selection. Reconfirm flag spelling in the approved compiler before building. |
| Matmul primitive | The official BANG matrix multiply tutorial demonstrates a matrix multiplication mapping to `__bang_conv` on its tutorial release. It does not establish an MLU590-specific BF16/FP16 matmul overload, supported register layout or FP32 accumulation. Capture the exact supported primitive and signature from the approved compiler's BANG headers and programming guide. |
| BF16, FP16 and FP32 | CNNL notes provide BF16/Half matmul evidence for specific library modes. Custom BANG hardware instruction overloads and true FP32 accumulation across K-tiles remain unverified. Hold these capabilities disabled until documented and tested individually. |
| Memory hierarchy | Vendor guide distinguishes device GDRAM, shared SRAM, per-core NRAM and WRAM. Plan for tiled A in NRAM, B packed for WRAM, and partial/destination state in NRAM where supported. Keep workspace sizing and alignment checked against the selected target and primitive. |
| Tiling and launch | Map independent output tiles to tasks. Keep the K loop within the tile to avoid cross-task accumulation. Size tiles and task/block or union shape from the approved alignment rules, resource budgets and queried topology. Handle partial M/N/K tiles with bounded loads/stores and zero-padded inputs where required. |
| Synchronization | Start with synchronous intra-kernel transfers and a named host queue. Confirm all local-memory dependencies before adding asynchronous transfers or shared SRAM reuse. Queue synchronization must complete before D2H, analysis or resource release. |
| Optimization | After correctness, measure reuse of packed B panels, GDRAM coalescing, SRAM sharing within a cluster, and NRAM/WRAM double-buffering with explicit pipeline synchronization. Avoid hard-coding vector-add alignment or historical GEMM packing as an MLU590 matmul requirement. |

The staged CNRT 6.12.1 header at `artifact/build/cnrt_integration/sdk/usr/local/neuware/include/cnrt.h:1989` declares the launch entry below. This declaration is cached-release evidence. It does not select a launch mechanism for the approved SDK or prove any kernel is compatible.

```c
cnrtRet_t cnrtInvokeKernel(const void *kernel, cnrtDim3_t dim,
                           cnrtFunctionType_t ktype, void **args,
                           size_t reserved, cnrtQueue_t queue);
```

The same header declares `cnrtQueueSync(cnrtQueue_t queue)`. The typed native adapter will own the selected release's launch argument storage, queue and native pointers. S will own the logical tile-independent GEMM contract, submission and lifecycle decisions.

- [Cambricon BANG matrix multiplication tutorial](https://developer.cambricon.com/index/curriculum/expdetails/id/8/classid/8.html)
- [Cambricon BANG C development guide](https://github.com/Cambricon/mlu-ops/blob/master/docs/BANG-C-OPS-Develop-Guide.md)
- [Cambricon CNToolkit architecture and target table](https://sdk.cambricon.com/static/independent/CNToolkit/3.8.4/releasenote/3.8.4/build/html/chapter_components/index.html)
