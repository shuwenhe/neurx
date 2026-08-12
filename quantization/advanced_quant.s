package neurx.quantization.advanced_quant
struct awq_config {
    int bits
    int group_size
    int version
    bool use_symmetric
    float alpha
}
struct gptq_config {
    int bits
    int group_size
    int desc_act
    string sym
    string damp_percent
}
struct awq_quantized_weight {
    []int qweight
    []int qzeros
    []float scales
    int bits
    int group_size
}
struct gptq_quantized_weight {
    []int qweight
    []int qzeros
    []float scales
    int bits
    int group_size
    []float h
}
func new_awq_config(int bits, int group_size) awq_config {
    awq_config{
        bits: bits,
        group_size: group_size,
        version: 0,
        use_symmetric: true,
        alpha: 0.5,
    }
}
func new_gptq_config(int bits, int group_size) gptq_config {
    gptq_config{
        bits: bits,
        group_size: group_size,
        desc_act: 0,
        sym: "true",
        damp_percent: "0.01",
    }
}
func quantize_with_awq(
    []float weights,
    awq_config config,
) awq_quantized_weight {
    group_size := config.group_size
    bits := config.bits
    num_groups := weights.len / group_size
    if weights.len % group_size != 0 {
        num_groups = num_groups + 1
    }
    qweight := []int{}
    qzeros := []int{}
    scales := []float{}
    g := 0
    while g < num_groups {
        start := g * group_size
        end := start + group_size
        if end > weights.len {
            end = weights.len
        }
        group_min := weights[start]
        group_max := weights[start]
        i := start
        while i < end {
            if weights[i] < group_min {
                group_min = weights[i]
            }
            if weights[i] > group_max {
                group_max = weights[i]
            }
            i = i + 1
        }
        scale := (group_max - group_min) / float((1 << bits) - 1)
        if scale < 0.00001 {
            scale = 0.00001
        }
        scales = append_float(scales, scale)
        zero_point := 0
        if !config.use_symmetric {
            zero_point = int(0.0 - group_min / scale)
        }
        qzeros = append_int(qzeros, zero_point)
        i = start
        while i < end {
            normalized := (weights[i] - group_min) / scale
            if normalized < 0.0 {
                normalized = 0.0
            }
            if normalized > float((1 << bits) - 1) {
                normalized = float((1 << bits) - 1)
            }
            quantized := int(normalized + 0.5)
            qweight = append_int(qweight, quantized)
            i = i + 1
        }
        g = g + 1
    }
    awq_quantized_weight{
        qweight: qweight,
        qzeros: qzeros,
        scales: scales,
        bits: bits,
        group_size: group_size,
    }
}
func quantize_with_gptq(
    []float weights,
    gptq_config config,
) gptq_quantized_weight {
    group_size := config.group_size
    bits := config.bits
    num_groups := weights.len / group_size
    if weights.len % group_size != 0 {
        num_groups = num_groups + 1
    }
    qweight := []int{}
    qzeros := []int{}
    scales := []float{}
    h := []float{}
    g := 0
    while g < num_groups {
        start := g * group_size
        end := start + group_size
        if end > weights.len {
            end = weights.len
        }
        group_min := weights[start]
        group_max := weights[start]
        i := start
        while i < end {
            if weights[i] < group_min {
                group_min = weights[i]
            }
            if weights[i] > group_max {
                group_max = weights[i]
            }
            i = i + 1
        }
        scale := (group_max - group_min) / float((1 << bits) - 1)
        if scale < 0.00001 {
            scale = 0.00001
        }
        scales = append_float(scales, scale)
        zero_point := int((group_max + group_min) / (2.0 * scale))
        qzeros = append_int(qzeros, zero_point)
        i = start
        while i < end {
            normalized := (weights[i] - group_min) / scale
            quantized := int(normalized + 0.5)
            qweight = append_int(qweight, quantized)
            i = i + 1
        }
        i = start
        while i < end {
            h = append_float(h, weights[i] * weights[i])
            i = i + 1
        }
        g = g + 1
    }
    gptq_quantized_weight{
        qweight: qweight,
        qzeros: qzeros,
        scales: scales,
        bits: bits,
        group_size: group_size,
        h: h,
    }
}
func dequantize_awq(awq_quantized_weight quant) []float {
    deq := []float{}
    group_idx := 0
    i := 0
    while i < quant.qweight.len {
        if i > 0 && i % quant.group_size == 0 {
            group_idx = group_idx + 1
        }
        scale := quant.scales[group_idx]
        zp := float(quant.qzeros[group_idx])
        dequantized := float(quant.qweight[i]) * scale + zp
        deq = append_float(deq, dequantized)
        i = i + 1
    }
    deq
}
func dequantize_gptq(gptq_quantized_weight quant) []float {
    deq := []float{}
    group_idx := 0
    i := 0
    while i < quant.qweight.len {
        if i > 0 && i % quant.group_size == 0 {
            group_idx = group_idx + 1
        }
        scale := quant.scales[group_idx]
        zp := float(quant.qzeros[group_idx])
        dequantized := float(quant.qweight[i]) * scale + zp
        deq = append_float(deq, dequantized)
        i = i + 1
    }
    deq
}
func get_awq_compression_ratio(awq_quantized_weight quant) float {
    original_bits := 32.0
    quantized_bits := float(quant.bits)
    original_bits / quantized_bits
}
func get_gptq_compression_ratio(gptq_quantized_weight quant) float {
    original_bits := 32.0
    quantized_bits := float(quant.bits)
    original_bits / quantized_bits
}
func append_float([]float slice, float elem) []float {
    new_slice := []float{}
    i := 0
    while i < slice.len {
        new_slice = append_float(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_float(new_slice, elem)
    new_slice
}
func append_int([]int slice, int elem) []int {
    new_slice := []int{}
    i := 0
    while i < slice.len {
        new_slice = append_int(new_slice, slice[i])
        i = i + 1
    }
    new_slice = append_int(new_slice, elem)
    new_slice
}
