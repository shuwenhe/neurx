#define _POSIX_C_SOURCE 200809L
#include "../../backend/platform/mlu/native_gemm.h"
#include "mlu_gemm_reference.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum { REPEATS = 20 };

/* Exact values in both input encodings, with mixed signs and zeros. */
static void fill(uint16_t *bits, float *values, size_t count, int index_stride,
                 neurx_gemm_dtype dtype) {
    const int bias = dtype == NEURX_GEMM_BF16 ? 127 : 15;
    const int fraction_bits = dtype == NEURX_GEMM_BF16 ? 7 : 10;
    for (size_t i = 0; i < count; ++i) {
        int code = (int)((i % 97) * (size_t)index_stride % 97) - 48;
        unsigned magnitude = (unsigned)abs(code);
        unsigned exponent = 0;
        for (unsigned v = magnitude; v > 1; v >>= 1)
            ++exponent;
        unsigned leading = 1u << exponent;
        bits[i] = magnitude == 0 ? 0 : (uint16_t)(
            (code < 0 ? 0x8000u : 0) |
            ((unsigned)(bias - 8 + (int)exponent) << fraction_bits) |
            ((magnitude - leading) << (fraction_bits - exponent)));
        values[i] = (float)code / 256.0f;
    }
}

static int run_case(int device, neurx_gemm_dtype dtype, int m, int n, int k) {
    size_t na = (size_t)m * k, nb = (size_t)k * n, nc = (size_t)m * n;
    uint16_t *a = malloc(na * sizeof(*a)), *b = malloc(nb * sizeof(*b));
    float *af = malloc(na * sizeof(*af)), *bf = malloc(nb * sizeof(*bf));
    float *out = malloc(nc * sizeof(*out)), *ref = malloc(nc * sizeof(*ref));
    int failed = 1;
    if (!a || !b || !af || !bf || !out || !ref) {
        fputs("host allocation failed\n", stderr);
        goto cleanup;
    }
    fill(a, af, na, 13, dtype);
    fill(b, bf, nb, 29, dtype);
    struct timespec cpu_start, cpu_end;
    if (clock_gettime(CLOCK_MONOTONIC, &cpu_start) != 0) {
        perror("start CPU reference clock");
        goto cleanup;
    }
    mlu_gemm_reference(af, bf, ref, m, n, k, k, n, n);
    if (clock_gettime(CLOCK_MONOTONIC, &cpu_end) != 0) {
        perror("finish CPU reference clock");
        goto cleanup;
    }
    const double cpu_us = (cpu_end.tv_sec - cpu_start.tv_sec) * 1e6
                        + (cpu_end.tv_nsec - cpu_start.tv_nsec) / 1e3;
    for (size_t i = 0; i < nc; ++i)
        out[i] = NAN;

    neurx_gemm_metrics timing;
    const neurx_gemm_status status =
        neurx_mlu_gemm(device, dtype, m, n, k, a, b, out, REPEATS, &timing);
    if (status.domain != NEURX_GEMM_OK) {
        fprintf(stderr, "GEMM %dx%dx%d failed: %s domain=%d code=%d\n",
                m, n, k, status.operation, status.domain, status.code);
        goto cleanup;
    }

    double max_abs = 0, max_rel = 0, sum_abs = 0, sum_rel = 0;
    size_t mismatches = 0;
    for (size_t i = 0; i < nc; ++i) {
        if (!isfinite(out[i])) {
            ++mismatches;
            continue;
        }
        const double scale = fabs(ref[i]);
        const double error = fabs((double)out[i] - ref[i]);
        const double rel = error / fmax(scale, 1e-6);
        max_abs = fmax(max_abs, error);
        max_rel = fmax(max_rel, rel);
        sum_abs += error;
        sum_rel += rel;
        if (error > 1e-5 + 1e-5 * scale)
            ++mismatches;
    }
    const double tflops = timing.kernel_us > 0
        ? 2.0 * m * n * k / (timing.kernel_us * 1e6) : NAN;
    printf("%s,%d,%d,%d,%zu,%.9g,%.9g,%.9g,%.9g,%.3f,%.3f,%.3f,%.3f,%.6g,%zu,%zu\n",
           dtype == NEURX_GEMM_BF16 ? "bf16" : "fp16", m, n, k, mismatches,
           max_abs, max_rel, sum_abs/nc, sum_rel/nc, cpu_us, timing.h2d_us, timing.kernel_us,
           timing.d2h_us, tflops, timing.workspace_bytes, timing.device_bytes);
    failed = mismatches != 0 || !isfinite(tflops);

cleanup:
    free(ref);
    free(out);
    free(bf);
    free(af);
    free(b);
    free(a);
    return failed;
}

int main(int argc, char **argv) {
    if (argc != 2 || argv[1][0] < '0' || argv[1][0] > '7' || argv[1][1]) {
        fprintf(stderr, "usage: %s <allocated CNRT device ordinal 0-7>\n", argv[0]);
        return 2;
    }
    const int device = argv[1][0] - '0';
    const int shapes[][3] = {
        {128,128,128}, {256,256,256}, {512,512,512}, {1024,1024,1024},
        {127,193,65}, {128,3072,2048}, {128,1408,2048},
    };
    puts("dtype,m,n,k,mismatches,max_abs,max_rel,mean_abs,mean_rel,cpu_reference_us,h2d_us,kernel_us,d2h_us,tflops,workspace_bytes,device_bytes");
    for (int dtype = NEURX_GEMM_FP16; dtype <= NEURX_GEMM_BF16; ++dtype)
        for (size_t i = 0; i < sizeof(shapes)/sizeof(*shapes); ++i)
            if (run_case(device, (neurx_gemm_dtype)dtype, shapes[i][0], shapes[i][1], shapes[i][2]))
                return 1;
    return 0;
}
