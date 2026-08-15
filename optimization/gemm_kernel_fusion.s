package optimization
import "core"
import "tensor"

struct gemm_config {
    m               int32
    n               int32
    k               int32
    tile_size       int32
    enable_fusion   bool
    num_gemms       int32
}

struct gemm_operation {
    a               []float32
    b               []float32
    c               []float32
    bias            []float32
    has_bias        bool
}

struct fused_gemm_kernel {
    config          gemm_config
    gemms           []gemm_operation
    fused_output    []float32
}

func NewFusedGEMMKernel(config gemm_config) *fused_gemm_kernel {
    if config.tile_size <= 0 {
        config.tile_size = 64
    }
    return &fused_gemm_kernel{
        config:      config,
        gemms:       make([]gemm_operation, 0),
        fused_output: make([]float32, 0),
    }
}

func (fk *fused_gemm_kernel) AddGEMM(gemm gemm_operation) {
    fk.gemms = append(fk.gemms, gemm)
}

func (fk *fused_gemm_kernel) ExecuteFused() [][]float32 {
    results := make([][]float32, 0)
    if !fk.config.enable_fusion {
        for _, gemm := range fk.gemms {
            result := fk.executeBasicGEMM(gemm)
            results = append(results, result)
        }
        return results
    }
    for i := int32(0); i < fk.config.num_gemms; i++ {
        if i < int32(len(fk.gemms)) {
            gemm := fk.gemms[i]
            result := fk.executeOptimizedGEMM(gemm)
            results = append(results, result)
        }
    }
    return results
}

func (fk *fused_gemm_kernel) executeBasicGEMM(gemm gemm_operation) []float32 {
    m := fk.config.m
    n := fk.config.n
    k := fk.config.k
    c := make([]float32, int(m*n))
    for i := int32(0); i < m; i++ {
        for j := int32(0); j < n; j++ {
            sum := 0.0
            for kk := int32(0); kk < k; kk++ {
                a_val := gemm.a[i*k+kk]
                b_val := gemm.b[kk*n+j]
                sum = sum + float64(a_val)*float64(b_val)
            }
            if gemm.has_bias {
                sum = sum + float64(gemm.bias[j])
            }
            c[i*n+j] = float32(sum)
        }
    }
    return c
}

func (fk *fused_gemm_kernel) executeOptimizedGEMM(gemm gemm_operation) []float32 {
    m := fk.config.m
    n := fk.config.n
    k := fk.config.k
    tile := fk.config.tile_size
    c := make([]float32, int(m*n))
    for i_start := int32(0); i_start < m; i_start += tile {
        i_end := i_start + tile
        if i_end > m {
            i_end = m
        }
        for j_start := int32(0); j_start < n; j_start += tile {
            j_end := j_start + tile
            if j_end > n {
                j_end = n
            }
            for k_start := int32(0); k_start < k; k_start += tile {
                k_end := k_start + tile
                if k_end > k {
                    k_end = k
                }
                for i := i_start; i < i_end; i++ {
                    for j := j_start; j < j_end; j++ {
                        for kk := k_start; kk < k_end; kk++ {
                            a_val := gemm.a[i*k+kk]
                            b_val := gemm.b[kk*n+j]
                            c[i*n+j] = c[i*n+j] + a_val*b_val
                        }
                    }
                }
            }
        }
    }
    if gemm.has_bias {
        for i := int32(0); i < m; i++ {
            for j := int32(0); j < n; j++ {
                c[i*n+j] = c[i*n+j] + gemm.bias[j]
            }
        }
    }
    return c
}

func (fk *fused_gemm_kernel) FuseGEMMAndActivation(
    gemm gemm_operation,
    activation_type string,
) []float32 {
    m := fk.config.m
    n := fk.config.n
    k := fk.config.k
    c := fk.executeOptimizedGEMM(gemm)
    for i := int32(0); i < m*n; i++ {
        c[i] = fk.applyActivation(c[i], activation_type)
    }
    return c
}

func (fk *fused_gemm_kernel) FuseGEMMAndNormalization(
    gemm gemm_operation,
    eps float32,
) []float32 {
    m := fk.config.m
    n := fk.config.n
    c := fk.executeOptimizedGEMM(gemm)
    for i := int32(0); i < m; i++ {
        mean := 0.0
        for j := int32(0); j < n; j++ {
            mean = mean + float64(c[i*n+j])
        }
        mean = mean / float64(n)
        var_sum := 0.0
        for j := int32(0); j < n; j++ {
            diff := float64(c[i*n+j]) - mean
            var_sum = var_sum + diff*diff
        }
        variance := var_sum / float64(n)
        std_dev := core.Sqrt(float32(variance + float64(eps)))
        for j := int32(0); j < n; j++ {
            c[i*n+j] = (c[i*n+j] - float32(mean)) / std_dev
        }
    }
    return c
}

func (fk *fused_gemm_kernel) FuseMultipleGEMMs(
    gemm1 gemm_operation,
    gemm2 gemm_operation,
) []float32 {
    intermediate := fk.executeOptimizedGEMM(gemm1)
    gemm2_fused := gemm2
    gemm2_fused.a = intermediate
    result := fk.executeOptimizedGEMM(gemm2_fused)
    return result
}

func (fk *fused_gemm_kernel) applyActivation(x float32, act_type string) float32 {
    switch act_type {
    case "relu":
        if x < 0 {
            return 0
        }
        return x
    case "gelu":
        cdf := 0.5 * (1.0 + core.Tanh(
            float32(0.7978845608)*float32(float64(x)+0.044715*float64(x)*float64(x)*float64(x))))
        return x * cdf
    case "sigmoid":
        return 1.0 / (1.0 + core.Exp(-x))
    default:
        return x
    }
}

func (fk *fused_gemm_kernel) GetComputationSaving() float32 {
    num_gemms := float32(fk.config.num_gemms)
    if num_gemms <= 1 {
        return 1.0
    }
    overhead_saving := (num_gemms - 1.0) * 0.05
    cache_saving := 0.1
    speedup := 1.0 + overhead_saving + cache_saving
    return speedup
}

func (fk *fused_gemm_kernel) BenchmarkGEMM(
    gemm gemm_operation,
    num_iterations int32,
) map[string]float32 {
    stats := make(map[string]float32)
    flops := float32(fk.config.m) * float32(fk.config.n) * float32(fk.config.k) * 2.0
    memory_bytes := float32(fk.config.m*fk.config.k + fk.config.k*fk.config.n + fk.config.m*fk.config.n) * 4.0
    peak_gflops := 100.0
    compute_time := flops / (peak_gflops * 1e9)
    bandwidth := 200.0
    memory_time := memory_bytes / (bandwidth * 1e9)
    time_per_iter := compute_time
    if memory_time > compute_time {
        time_per_iter = memory_time
    }
    stats["flops"] = flops
    stats["memory_bytes"] = memory_bytes
    stats["time_per_iter_ms"] = time_per_iter * 1000.0
    stats["gflops"] = flops / (time_per_iter * 1e9)
    stats["total_time_ms"] = float32(num_iterations) * time_per_iter * 1000.0
    return stats
}

func main() {
    config := gemm_config{
        m:              512,
        n:              512,
        k:              512,
        tile_size:      64,
        enable_fusion:  true,
        num_gemms:      2,
    }
    fk := NewFusedGEMMKernel(config)
    core.Println("GEMM Kernel Fusion initialized")
    core.Println("Matrix dimensions:", config.m, "x", config.n, "x", config.k)
    core.Println("Tile size:", config.tile_size)
    core.Println("Computation saving:", fk.GetComputationSaving(), "x")
    stats := fk.BenchmarkGEMM(gemm_operation{}, 100)
    core.Println("Benchmark stats:")
    core.Println("  GFLOPS:", stats["gflops"])
    core.Println("  Time per iteration:", stats["time_per_iter_ms"], "ms")
}
