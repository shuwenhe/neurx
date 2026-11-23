/* CPU-only P0 fixture and FP32 reference validation. No vendor runtime. */
#include <fenv.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "mlu_gemm_reference.h"

_Static_assert(FLT_RADIX == 2 && FLT_MANT_DIG == 24 && FLT_MAX_EXP == 128 &&
               FLT_EVAL_METHOD == 0, "reference requires binary32 arithmetic");

enum { PERIOD = 31 };
struct shape { int m, n, k, pa, pb, pc; };
static const struct shape cases[] = {
    {128,128,128,0,0,0}, {256,256,256,0,0,0}, {512,512,512,0,0,0},
    {1024,1024,1024,0,0,0}, {2048,2048,2048,0,0,0},
    {128,256,512,0,0,0}, {256,512,128,0,0,0}, {512,256,1024,0,0,0},
    {127,193,65,3,5,7}, {192,80,257,11,1,9},
};

static float quantize(float x, int bf16) {
    if (x == 0.0f) return x;
    int exponent;
    frexpf(x, &exponent);
    int step = exponent - (bf16 ? 8 : 11);
    int minimum = bf16 ? -133 : -24;
    if (step < minimum) step = minimum;
    return ldexpf(nearbyintf(ldexpf(x, -step)), step);
}

static int a_code(int i, int p) { return (37*i + 13*p) % 1023 - 511; }
static int b_code(int p, int j) { return (11*p + 7*(j % PERIOD)) % 31 - 15; }

/* Independent integer RNE for the bounded fixed-point fixture. */
static int oracle_a(int q, int bf16) {
    int mag = abs(q);
    if (bf16 && mag >= 256 && mag % 2) {
        mag = 2 * (mag / 2 + (mag / 2) % 2);
        return q < 0 ? -mag : mag;
    }
    return q;
}

static int validate(struct shape s, int bf16) {
    int lda = s.k+s.pa, ldb = s.n+s.pb, ldc = s.n+s.pc;
    float *a = malloc((size_t)s.m*lda*sizeof(*a));
    float *b = malloc((size_t)s.k*ldb*sizeof(*b));
    float *c = malloc((size_t)s.m*ldc*sizeof(*c));
    if (!a || !b || !c) {
        free(a); free(b); free(c);
        fputs("CPU validation allocation failed\n", stderr);
        return 1;
    }
    for (int i = 0; i < s.m; ++i)
        for (int p = 0; p < lda; ++p)
            a[i*lda+p] = p < s.k ? quantize(a_code(i,p)*0x1p-12f,bf16) : NAN;
    for (int p = 0; p < s.k; ++p)
        for (int j = 0; j < ldb; ++j)
            b[p*ldb+j] = j < s.n ? quantize(b_code(p,j)*0x1p-12f,bf16) : NAN;
    for (int i = 0; i < s.m; ++i)
        for (int j = 0; j < ldc; ++j) c[i*ldc+j] = NAN;

    mlu_gemm_reference(a,b,c,s.m,s.n,s.k,lda,ldb,ldc);
    double max_abs = 0, max_rel = 0, sum_abs = 0;
    size_t mismatches = 0, nonfinite = 0, padding_errors = 0, zero_outputs = 0;
    for (int i = 0; i < s.m; ++i) {
        int exact[PERIOD] = {0};
        for (int j = 0; j < PERIOD && j < s.n; ++j)
            for (int p = 0; p < s.k; ++p)
                exact[j] += oracle_a(a_code(i,p),bf16)*b_code(p,j);
        for (int j = 0; j < s.n; ++j) {
            double expected = exact[j % PERIOD]*0x1p-24;
            if (expected == 0) ++zero_outputs;
            double actual = c[i*ldc+j];
            if (!isfinite(actual)) { ++nonfinite; ++mismatches; continue; }
            double err = fabs(actual-expected);
            if (err != 0) ++mismatches;
            max_abs = fmax(max_abs,err);
            if (expected != 0) max_rel = fmax(max_rel,err/fabs(expected));
            sum_abs += err;
        }
        for (int j = s.n; j < ldc; ++j)
            if (!isnan(c[i*ldc+j])) ++padding_errors;
    }
    size_t count = (size_t)s.m*s.n;
    printf("%s,%d,%d,%d,%d,%d,%d,fp32,fp32,%zu,%.9g,%.9g,%.9g,%zu,%zu,%zu,%zu\n",
           bf16 ? "bf16" : "fp16", s.m,s.n,s.k,lda,ldb,ldc,count,
           nonfinite ? NAN : max_abs, nonfinite ? NAN : max_rel,
           nonfinite ? NAN : sum_abs/count,mismatches,nonfinite,padding_errors,zero_outputs);
    free(a); free(b); free(c);
    return mismatches != 0 || padding_errors != 0;
}

static int boundaries(int bf16) {
    float ulp = bf16 ? 0x1p-7f : 0x1p-10f;
    float minimum = bf16 ? 0x1p-133f : 0x1p-24f;
    float normal = bf16 ? 0x1p-126f : 0x1p-14f;
    float maximum = bf16 ? 0x1.fep127f : 65504.0f;
    const float input[] = {0, -0.0f, minimum, -minimum, normal, -normal, maximum, -maximum,
                           1+ulp/2, 1+3*ulp/2, minimum/2};
    const float expected[] = {0, -0.0f, minimum, -minimum, normal, -normal, maximum, -maximum,
                              1, 1+2*ulp, 0};
    for (size_t i = 0; i < sizeof(input)/sizeof(*input); ++i)
        if (quantize(input[i],bf16) != expected[i] ||
            !!signbit(quantize(input[i],bf16)) != !!signbit(expected[i])) return 1;

    const float b[] = {4096,1,4096};
    float c[1];

    const float cancel[] = {4096,1,-4096};
    mlu_gemm_reference(cancel,b,c,1,1,3,3,1,1);
    if (c[0] != 0) return 1; /* FP64 increasing-K would produce 1. */
    mlu_gemm_reference(&maximum,&(const float){0.5f},c,1,1,1,1,1,1);
    if (c[0] != maximum/2) return 1;
    mlu_gemm_reference(&minimum,&(const float){1.0f},c,1,1,1,1,1,1);
    return c[0] != minimum;
}

int main(void) {
    if (fegetround() != FE_TONEAREST) {
        fputs("CPU validation requires round-to-nearest-even\n", stderr);
        return 1;
    }
    int failed = 0;
    puts("input,m,n,k,lda,ldb,ldc,accumulation,output,elements,max_abs,max_rel,mean_abs,mismatches,nonfinite,padding_errors,zero_outputs");
    for (int bf16 = 0; bf16 <= 1; ++bf16) {
        if (boundaries(bf16)) {
            fprintf(stderr,"%s boundary validation failed\n",bf16 ? "bf16" : "fp16");
            failed = 1;
        } else {
            fprintf(stderr,"%s boundary validation passed\n",bf16 ? "bf16" : "fp16");
        }
        for (size_t i = 0; i < sizeof(cases)/sizeof(*cases); ++i)
            failed |= validate(cases[i],bf16);
    }
    return failed;
}
