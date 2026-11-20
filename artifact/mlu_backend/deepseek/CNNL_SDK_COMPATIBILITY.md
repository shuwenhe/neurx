# CNNL SDK compatibility gate

**BLOCKED.** A vendor-approved native Focal amd64 CNRT/CNDrv/CNNL tuple for MLU590-M9 and driver 6.5.52 was not available to verify. This host uses glibc 2.31 and its process view contains no Cambricon device nodes. The loader cache lists CNDev only. Searches below `/usr/local/neuware`, `/usr/include`, readable `/opt` and workspace build artifacts found no `cnnl.h` or `libcnnl.so*`. The search could not read `/opt/containerd`.

## Vendor documentation and remaining ABI checks

| Area | Confirmed evidence | Required before integration |
| --- | --- | --- |
| Matmul API | Cambricon names `cnnlMatMul_v2` and the algorithm queries `cnnlGetMatMulAlgoHeuristic` and `cnnlGetMatMulHeuristicResult` as replacements for older matmul/workspace interfaces. Its CNNL v1.20.0 notes add BF16 support to `cnnlMatMul_v2`. | Record exact prototypes and descriptor/workspace types from the approved header. Select a single API family from that release. |
| BF16 / FP16 and FP32 output | CNNL v1.23.0 notes describe Float32 off-chip output with Bfloat16 or Half on-chip inputs for `cnnlMatMul`. | Verify that the chosen MLU590 algorithm accepts **stored** BF16 or FP16 A/B and FP32 C on the actual SDK. The release-note statement and the v2 BF16 announcement cover distinct API claims. |
| FP32 accumulation | Not established by an FP32 output type or by the reported on-chip input type. | Obtain the approved API's documented accumulator control and computation-mode guarantee. Verify the selected algorithm and exercise accumulation-sensitive numerical cases. |
| Layout and leading dimensions | NeurX defines packed row-major strides in elements. | Verify CNNL descriptor layout and stride semantics for the approved entry, including non-square matrices and the beta-zero output contract. Derive A/B/C descriptor dimensions and strides from the S spec. |
| CNNL handle lifecycle | Public notes name `cnnlCreate`. | Obtain the approved signature for creating a handle, binding it to the selected CNRT queue, and destroying it, with return codes and lifetime rules. No target CNNL prototypes were verified locally. |
| Device support | Public notes document MLU590 support in parts of the CNNL series. | Verify an official package manifest for Ubuntu 20.04, glibc 2.31 and driver/firmware 6.5.52. General MLU590 support does not pin this tuple. |

[Cambricon CNNL 1.23.2 release notes](https://sdk.cambricon.com/static/independent/CNNL/1.23.2/releasenote/1.23.2/build/html/cnnl.html) · [Native compatibility matrix](../native_deployment/diagnosis/NEUWARE_COMPATIBILITY_MATRIX.md)

## CNRT header evidence

The following signatures were verified against `/app/shuwen/neurx/artifact/build/cnrt_integration/sdk/usr/local/neuware/include/cnrt.h` from the official cached `cnrt_6.12.1-1.ubuntu22.04_amd64.deb`. The cache belongs to CNToolkit 3.13.6. These signatures are evidence for that release only.

```c
cnrtRet_t cnrtGetLibVersion(int *major, int *minor, int *patch);
cnrtRet_t cnrtGetDeviceCount(unsigned int *pCount);
cnrtRet_t cnrtSetDevice(int ordinal);
cnrtRet_t cnrtQueueCreate(cnrtQueue_t *pQueue);
cnrtRet_t cnrtQueueSync(cnrtQueue_t queue);
cnrtRet_t cnrtQueueDestroy(cnrtQueue_t queue);
cnrtRet_t cnrtMalloc(void **pPtr, size_t bytes);
cnrtRet_t cnrtFree(void *ptr);
cnrtRet_t cnrtHostMalloc(void **pPtr, size_t bytes);
cnrtRet_t cnrtFreeHost(void *ptr);
cnrtRet_t cnrtMemcpy(void *dst, void *src, size_t bytes, cnrtMemTransDir_t dir);
cnrtRet_t cnrtMemcpyAsync(void *dst, void *src, size_t bytes, cnrtQueue_t queue,
                         cnrtMemTransDir_t dir);
```

A syntax-only C probe checked every function-pointer type above with static assertions and exited 0. The header's asynchronous example uses pinned host storage and queue synchronization. No cached Ubuntu 22.04 library was installed, loaded, or linked for this task. Static inspection of its ELF version-needs section reproduced `GLIBC_2.34`. The prior gate recorded the actual loader rejection. [Runtime acceptance and failure log](MLU_RUNTIME_ACCEPTANCE.md)

```sh
b=artifact/build/mlu_cnnl_gate
sdk=artifact/build/cnrt_integration/sdk/usr/local/neuware
dpkg-deb -f /var/cntoolkit-3.13.6/cnrt_6.12.1-1.ubuntu22.04_amd64.deb Version Depends
cc -std=gnu11 -Wall -Wextra -Werror -fsyntax-only -I"$sdk/include" "$b/cnrt_types.c"
readelf --version-info "$sdk/lib64/libcnrt.so" | grep 'Name: GLIBC_2.34'
```

All three checks exited 0. Package metadata reports `libc6 (>= 2.34)`, `libstdc++6 (>= 9)`, and `cndrv`. Acceptance remains blocked pending a usable vendor SDK with matching headers and permitted MLU device access.
