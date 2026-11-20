# GEMM numerical preparation

**CPU fixtures prepared and spot-checked. MLU comparison is BLOCKED.** The reference below ran on the CPU and exited 0. It checks two input rounding ties per dtype, a case that distinguishes sequential FP32 accumulation from a higher-precision sum, a known dot product, and three entries for each prepared shape/dtype. It does not compute or validate a full output matrix in this smoke run.

| Case type | M, N, K | Dtypes |
| --- | --- | --- |
| Square | 128³, 256³, 512³, 1024³, 2048³ | BF16 and FP16 independently |
| Rectangular | (127, 193, 65), (192, 80, 257) | BF16 and FP16 independently |

Use the deterministic formulas below for full matrix materialization and compare every output entry after the hardware gate. The host reference rounds finite inputs to the input dtype using round-to-nearest, ties-to-even. It computes products and the increasing-K sum in IEEE binary32 with a rounding step for each multiply and add. Output storage is binary32 with no BF16 or FP16 output cast. Also retain the small exact rectangular S oracle in `test/contract/mlu_p0_cpu_gemm_reference.s`.

For hardware comparison, reject nonfinite results. Use a bound that allows FP32 reduction-order and FMA differences. A proposed starting threshold is `abs(actual-ref) <= 1e-6 + 4*gamma(2*K)*sum(abs(A[i,p]*B[p,j]))`, where `gamma(n)=n*u/(1-n*u)` and `u=2^-24`. Confirm tolerance against the approved computation mode, record maximum absolute/relative errors and mismatch counts, and include cancellation and accumulator-sensitive cases independently. FP32 output and passing this bound alone do not prove how the vendor accumulates.

## Reproduce the CPU-only smoke test

Save this block as `cpu_reference.py` and run `python3 -S cpu_reference.py`.

```python
import struct

BASE_CASES = [(n, n, n) for n in (128, 256, 512, 1024, 2048)]
CASES = BASE_CASES + [(127, 193, 65), (192, 80, 257)]

def fp32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]

def quantize(x, dtype):
    if dtype == "fp16":
        return struct.unpack("<e", struct.pack("<e", x))[0]
    bits = struct.unpack("<I", struct.pack("<f", x))[0]
    rounded = (bits + 0x7fff + ((bits >> 16) & 1)) & 0xffff0000
    return struct.unpack("<f", struct.pack("<I", rounded))[0]

def dot(a, b):
    acc = 0.0
    for x, y in zip(a, b):
        acc = fp32(acc + fp32(x * y))
    return acc

def entry(i, j, k, dtype):
    a = (quantize(((37*i + 13*p) % 251 - 125)/127, dtype) for p in range(k))
    b = (quantize(((19*p + 29*j) % 241 - 120)/113, dtype) for p in range(k))
    return dot(a, b)

if __name__ == "__main__":
    assert quantize(1 + 2**-8, "bf16") == 1
    assert quantize(1 + 3*2**-8, "bf16") == 1 + 2**-6
    assert quantize(1 + 2**-11, "fp16") == 1
    assert quantize(1 + 3*2**-11, "fp16") == 1 + 2**-9
    assert dot([16777216, 1, -16777216], [1, 1, 1]) == 0
    assert dot([1, 2, 3], [7, 9, 11]) == 58
    for dtype in ("bf16", "fp16"):
        for m, n, k in CASES:
            coordinates = ((0, 0), (m//2, n//2), (m-1, n-1))
            values = [entry(i, j, k, dtype) for i, j in coordinates]
            assert all(abs(x) <= 2*k for x in values)
            print(dtype, (m, n, k), values)
```

Captured CPU output for first, middle, and last row-major coordinates in each case.

```text
bf16 (128, 128, 128) [5.4321417808532715, -1.2188712358474731, -5.72886848449707]
bf16 (256, 256, 256) [1.6834831237792969, -2.080031394958496, 5.279121398925781]
bf16 (512, 512, 512) [2.763423442840576, 0.17401659488677979, -1.664440631866455]
bf16 (1024, 1024, 1024) [6.145641803741455, 0.7657852172851562, 5.624440670013428]
bf16 (2048, 2048, 2048) [0.8611142635345459, -2.9554693698883057, 7.493816375732422]
bf16 (127, 193, 65) [1.7679343223571777, -3.0685875415802, -0.6740976572036743]
bf16 (192, 80, 257) [2.001049041748047, -1.8513305187225342, 3.132205009460449]
fp16 (128, 128, 128) [5.414323806762695, -1.2244731187820435, -5.72412633895874]
fp16 (256, 256, 256) [1.675567388534546, -2.0623838901519775, 5.264091491699219]
fp16 (512, 512, 512) [2.7541308403015137, 0.18166160583496094, -1.666792869567871]
fp16 (1024, 1024, 1024) [6.122234344482422, 0.7972093224525452, 5.604030609130859]
fp16 (2048, 2048, 2048) [0.8752528429031372, -2.928232431411743, 7.496885776519775]
fp16 (127, 193, 65) [1.7567205429077148, -3.0808475017547607, -0.6825838685035706]
fp16 (192, 80, 257) [1.9931999444961548, -1.8488742113113403, 3.1123650074005127]
```
