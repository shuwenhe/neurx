# CPU numerical validation

**CPU_REFERENCE_PASS.** Checked every output in 20 full matrices, **11,843,454 elements**. The test-only C harness uses binary32 products and increasing-K binary32 summation, with contraction disabled. Both input encodings use round-to-nearest ties-to-even and decode into binary32. Output is binary32 with no BF16 or FP16 narrowing.

| Input | Accumulation | Output | Cases | Elements | Max abs | Max rel | Mean abs | Mismatches |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| FP16 | FP32 | FP32 | 10 | 5,921,727 | 0 | 0 | 0 | 0 |
| BF16 | FP32 | FP32 | 10 | 5,921,727 | 0 | 0 | 0 | 0 |

The independent oracle sums exact fixed-point products in integer arithmetic. A and B are multiples of 2⁻¹² after dtype rounding, and the BF16 rounding is derived independently on the input integer code. The sum of absolute integer products is bounded by `2048*512*15 < 2^24`, so every product and intermediate sum in these dense cases is exactly representable in FP32. B columns repeat every 31 columns. The oracle reuses its exact calculation for a repeated column and compares **every** corresponding output individually. Relative error excludes exact-zero reference entries. Those entries still participate in absolute error and mismatch checks. There were 2,535 such FP16 entries and 350 BF16 entries.

Padded cases use unequal leading dimensions and non-aligned sizes. Input padding is initialized to NaN. Output padding must retain its NaN sentinel. No logical output was nonfinite and no padding sentinel changed. Separate exact checks cover signed zero, signed minimum subnormals and normals, signed maximum finite values, ties, underflow to zero, boundary products, and accumulation-sensitive cancellation. The test disabled FMA contraction so sequential FP32 cancellation has the documented outcome.

```sh
b="$PWD/artifact/build/mlu_gemm_phase2"
mkdir -p "$b"
cc -std=c11 -O3 -Wall -Wextra -Werror -ffp-contract=off \
  test/contract/mlu_gemm_cpu_validation.c -lm -o "$b/cpu_validation"
"$b/cpu_validation" > "$b/cpu.csv"
```

Compilation and execution exited 0. Boundary checks printed `fp16 boundary validation passed` and `bf16 boundary validation passed`.

The existing S `cpu_matmul` passed its two full small rectangular tests via Stage4. Disassembly showed `mulsd` and `addsd` for the tested S `float` path, so it is retained as a CPU cross-check with binary64 arithmetic. The full-size FP32 results above come from the separate test harness and do not change or certify the production CPU path for FP32 accumulation.

## Complete CPU results

```csv
input,m,n,k,lda,ldb,ldc,accumulation,output,elements,max_abs,max_rel,mean_abs,mismatches,nonfinite,padding_errors,zero_outputs
fp16,128,128,128,128,128,128,fp32,fp32,16384,0,0,0,0,0,0,0
fp16,256,256,256,256,256,256,fp32,fp32,65536,0,0,0,0,0,0,9
fp16,512,512,512,512,512,512,fp32,fp32,262144,0,0,0,0,0,0,0
fp16,1024,1024,1024,1024,1024,1024,fp32,fp32,1048576,0,0,0,0,0,0,2245
fp16,2048,2048,2048,2048,2048,2048,fp32,fp32,4194304,0,0,0,0,0,0,0
fp16,128,256,512,512,256,256,fp32,fp32,32768,0,0,0,0,0,0,0
fp16,256,512,128,128,512,512,fp32,fp32,131072,0,0,0,0,0,0,0
fp16,512,256,1024,1024,256,256,fp32,fp32,131072,0,0,0,0,0,0,281
fp16,127,193,65,68,198,200,fp32,fp32,24511,0,0,0,0,0,0,0
fp16,192,80,257,268,81,89,fp32,fp32,15360,0,0,0,0,0,0,0
bf16,128,128,128,128,128,128,fp32,fp32,16384,0,0,0,0,0,0,10
bf16,256,256,256,256,256,256,fp32,fp32,65536,0,0,0,0,0,0,0
bf16,512,512,512,512,512,512,fp32,fp32,262144,0,0,0,0,0,0,32
bf16,1024,1024,1024,1024,1024,1024,fp32,fp32,1048576,0,0,0,0,0,0,0
bf16,2048,2048,2048,2048,2048,2048,fp32,fp32,4194304,0,0,0,0,0,0,266
bf16,128,256,512,512,256,256,fp32,fp32,32768,0,0,0,0,0,0,8
bf16,256,512,128,128,512,512,fp32,fp32,131072,0,0,0,0,0,0,34
bf16,512,256,1024,1024,256,256,fp32,fp32,131072,0,0,0,0,0,0,0
bf16,127,193,65,68,198,200,fp32,fp32,24511,0,0,0,0,0,0,0
bf16,192,80,257,268,81,89,fp32,fp32,15360,0,0,0,0,0,0,0
```
