package neurx.nn.conv
use neurx.tensor.tensor

func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    for i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func shape2(int a, int b) []int {
    []int s = []int{cap: 2}
    s[0] = a
    s[1] = b
    s
}

func shape3(int a, int b, int c) []int {
    []int s = []int{cap: 3}
    s[0] = a
    s[1] = b
    s[2] = c
    s
}

func shape4(int a, int b, int c, int d) []int {
    []int s = []int{cap: 4}
    s[0] = a
    s[1] = b
    s[2] = c
    s[3] = d
    s
}

func out_size(int in_size, int kernel, int stride, int padding, int dilation) int {
    (in_size + 2 * padding - dilation * (kernel - 1) - 1) / stride + 1
}

struct conv1d_state {
    int in_channels
    int out_channels
    int kernel_size
    int stride
    int padding
    int dilation
    []float weight
    []float bias
    bool use_bias
}

func new_conv1d(int in_channels, int out_channels, int kernel_size, int stride, int padding, int dilation, bool use_bias) conv1d_state {
    int w_size = out_channels * in_channels * kernel_size
    []float weight = []float{cap: w_size}
    int i = 0
    for i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    for i < out_channels {
        bias[i] = 0.0
        i = i + 1
    }
    conv1d_state {
        in_channels: in_channels,
        out_channels: out_channels,
        kernel_size: kernel_size,
        stride: stride,
        padding: padding,
        dilation: dilation,
        weight: weight,
        bias: bias,
        use_bias: use_bias,
    }
}

func conv1d_forward(conv1d_state layer, tensor input) tensor {
    int batch = input.shape[0]
    int in_ch = input.shape[1]
    int length = input.shape[2]
    int out_ch = layer.out_channels
    int ks = layer.kernel_size
    int stride = layer.stride
    int pad = layer.padding
    int dil = layer.dilation
    int out_len = out_size(length, ks, stride, pad, dil)
    []float out = []float{cap: batch * out_ch * out_len}
    int b = 0
    for b < batch {
        int oc = 0
        for oc < out_ch {
            int ol = 0
            for ol < out_len {
                float acc = 0.0
                if layer.use_bias {
                    acc = layer.bias[oc]
                }
                int ic = 0
                for ic < in_ch {
                    int k = 0
                    for k < ks {
                        int pos = ol * stride - pad + k * dil
                        if pos >= 0 && pos < length {
                            float x = input.data[(b * in_ch + ic) * length + pos]
                            float w = layer.weight[(oc * in_ch + ic) * ks + k]
                            acc = acc + x * w
                        }
                        k = k + 1
                    }
                    ic = ic + 1
                }
                out[(b * out_ch + oc) * out_len + ol] = acc
                ol = ol + 1
            }
            oc = oc + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape3(batch, out_ch, out_len), input.requires_grad)
}

struct conv2d_state {
    int in_channels
    int out_channels
    int kernel_h
    int kernel_w
    int stride_h
    int stride_w
    int pad_h
    int pad_w
    int dil_h
    int dil_w
    []float weight
    []float bias
    bool use_bias
}

func new_conv2d(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int dil_h, int dil_w, bool use_bias) conv2d_state {
    int w_size = out_channels * in_channels * kernel_h * kernel_w
    []float weight = []float{cap: w_size}
    int i = 0
    for i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    for i < out_channels {
        bias[i] = 0.0
        i = i + 1
    }
    conv2d_state {
        in_channels: in_channels,
        out_channels: out_channels,
        kernel_h: kernel_h,
        kernel_w: kernel_w,
        stride_h: stride_h,
        stride_w: stride_w,
        pad_h: pad_h,
        pad_w: pad_w,
        dil_h: dil_h,
        dil_w: dil_w,
        weight: weight,
        bias: bias,
        use_bias: use_bias,
    }
}

func conv2d_forward(conv2d_state layer, tensor input) tensor {
    int batch = input.shape[0]
    int in_ch = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    int out_ch = layer.out_channels
    int kh = layer.kernel_h
    int kw = layer.kernel_w
    int out_h = out_size(in_h, kh, layer.stride_h, layer.pad_h, layer.dil_h)
    int out_w = out_size(in_w, kw, layer.stride_w, layer.pad_w, layer.dil_w)
    []float out = []float{cap: batch * out_ch * out_h * out_w}
    int b = 0
    for b < batch {
        int oc = 0
        for oc < out_ch {
            int oh = 0
            for oh < out_h {
                int ow = 0
                for ow < out_w {
                    float acc = 0.0
                    if layer.use_bias {
                        acc = layer.bias[oc]
                    }
                    int ic = 0
                    for ic < in_ch {
                        int khi = 0
                        for khi < kh {
                            int kwi = 0
                            for kwi < kw {
                                int ih = oh * layer.stride_h - layer.pad_h + khi * layer.dil_h
                                int iw = ow * layer.stride_w - layer.pad_w + kwi * layer.dil_w
                                if ih >= 0 && ih < in_h && iw >= 0 && iw < in_w {
                                    float x = input.data[((b * in_ch + ic) * in_h + ih) * in_w + iw]
                                    float w = layer.weight[((oc * in_ch + ic) * kh + khi) * kw + kwi]
                                    acc = acc + x * w
                                }
                                kwi = kwi + 1
                            }
                            khi = khi + 1
                        }
                        ic = ic + 1
                    }
                    out[((b * out_ch + oc) * out_h + oh) * out_w + ow] = acc
                    ow = ow + 1
                }
                oh = oh + 1
            }
            oc = oc + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, out_ch, out_h, out_w), input.requires_grad)
}

struct convtranspose1d_state {
    int in_channels
    int out_channels
    int kernel_size
    int stride
    int padding
    int output_padding
    int dilation
    []float weight
    []float bias
    bool use_bias
}

func new_convtranspose1d(int in_channels, int out_channels, int kernel_size, int stride, int padding, int output_padding, int dilation, bool use_bias) convtranspose1d_state {
    int w_size = in_channels * out_channels * kernel_size
    []float weight = []float{cap: w_size}
    int i = 0
    for i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    for i < out_channels {
        bias[i] = 0.0
        i = i + 1
    }
    return convtranspose1d_state {
        in_channels: in_channels,
        out_channels: out_channels,
        kernel_size: kernel_size,
        stride: stride,
        padding: padding,
        output_padding: output_padding,
        dilation: dilation,
        weight: weight,
        bias: bias,
        use_bias: use_bias,
    }
}

func convtranspose1d_forward(convtranspose1d_state layer, tensor input) tensor {
    int batch = input.shape[0]
    int in_ch = input.shape[1]
    int in_len = input.shape[2]
    int out_ch = layer.out_channels
    int ks = layer.kernel_size
    int out_len = (in_len - 1) * layer.stride - 2 * layer.padding + layer.dilation * (ks - 1) + layer.output_padding + 1
    if out_len <= 0 {
        out_len = 1
    }
    []float out = []float{cap: batch * out_ch * out_len}
    int b = 0
    for b < batch {
        int ic = 0
        for ic < in_ch {
            int il = 0
            for il < in_len {
                float x = input.data[(b * in_ch + ic) * in_len + il]
                int oc = 0
                for oc < out_ch {
                    int k = 0
                    for k < ks {
                        int ol = il * layer.stride - layer.padding + k * layer.dilation
                        if ol >= 0 && ol < out_len {
                            int widx = ((ic * out_ch + oc) * ks) + k
                            out[(b * out_ch + oc) * out_len + ol] = out[(b * out_ch + oc) * out_len + ol] + x * layer.weight[widx]
                        }
                        k = k + 1
                    }
                    oc = oc + 1
                }
                il = il + 1
            }
            ic = ic + 1
        }
        if layer.use_bias {
            int oc2 = 0
            for oc2 < out_ch {
                int ol2 = 0
                for ol2 < out_len {
                    out[(b * out_ch + oc2) * out_len + ol2] = out[(b * out_ch + oc2) * out_len + ol2] + layer.bias[oc2]
                    ol2 = ol2 + 1
                }
                oc2 = oc2 + 1
            }
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape3(batch, out_ch, out_len), input.requires_grad)
}

struct convtranspose2d_state {
    int in_channels
    int out_channels
    int kernel_h
    int kernel_w
    int stride_h
    int stride_w
    int pad_h
    int pad_w
    int output_pad_h
    int output_pad_w
    int dil_h
    int dil_w
    []float weight
    []float bias
    bool use_bias
}

func new_convtranspose2d(int in_channels, int out_channels, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w, int output_pad_h, int output_pad_w, int dil_h, int dil_w, bool use_bias) convtranspose2d_state {
    int w_size = in_channels * out_channels * kernel_h * kernel_w
    []float weight = []float{cap: w_size}
    int i = 0
    for i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    for i < out_channels {
        bias[i] = 0.0
        i = i + 1
    }
    return convtranspose2d_state {
        in_channels: in_channels,
        out_channels: out_channels,
        kernel_h: kernel_h,
        kernel_w: kernel_w,
        stride_h: stride_h,
        stride_w: stride_w,
        pad_h: pad_h,
        pad_w: pad_w,
        output_pad_h: output_pad_h,
        output_pad_w: output_pad_w,
        dil_h: dil_h,
        dil_w: dil_w,
        weight: weight,
        bias: bias,
        use_bias: use_bias,
    }
}

func convtranspose2d_forward(convtranspose2d_state layer, tensor input) tensor {
    int batch = input.shape[0]
    int in_ch = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    int out_ch = layer.out_channels
    int kh = layer.kernel_h
    int kw = layer.kernel_w
    int out_h = (in_h - 1) * layer.stride_h - 2 * layer.pad_h + layer.dil_h * (kh - 1) + layer.output_pad_h + 1
    int out_w = (in_w - 1) * layer.stride_w - 2 * layer.pad_w + layer.dil_w * (kw - 1) + layer.output_pad_w + 1
    if out_h <= 0 {
        out_h = 1
    }
    if out_w <= 0 {
        out_w = 1
    }
    []float out = []float{cap: batch * out_ch * out_h * out_w}
    int b = 0
    for b < batch {
        int ic = 0
        for ic < in_ch {
            int ih = 0
            for ih < in_h {
                int iw = 0
                for iw < in_w {
                    float x = input.data[((b * in_ch + ic) * in_h + ih) * in_w + iw]
                    int oc = 0
                    for oc < out_ch {
                        int khi = 0
                        for khi < kh {
                            int kwi = 0
                            for kwi < kw {
                                int oh = ih * layer.stride_h - layer.pad_h + khi * layer.dil_h
                                int ow = iw * layer.stride_w - layer.pad_w + kwi * layer.dil_w
                                if oh >= 0 && oh < out_h && ow >= 0 && ow < out_w {
                                    int widx = (((ic * out_ch + oc) * kh + khi) * kw) + kwi
                                    out[((b * out_ch + oc) * out_h + oh) * out_w + ow] = out[((b * out_ch + oc) * out_h + oh) * out_w + ow] + x * layer.weight[widx]
                                }
                                kwi = kwi + 1
                            }
                            khi = khi + 1
                        }
                        oc = oc + 1
                    }
                    iw = iw + 1
                }
                ih = ih + 1
            }
            ic = ic + 1
        }
        if layer.use_bias {
            int oc2 = 0
            for oc2 < out_ch {
                int oh2 = 0
                for oh2 < out_h {
                    int ow2 = 0
                    for ow2 < out_w {
                        out[((b * out_ch + oc2) * out_h + oh2) * out_w + ow2] = out[((b * out_ch + oc2) * out_h + oh2) * out_w + ow2] + layer.bias[oc2]
                        ow2 = ow2 + 1
                    }
                    oh2 = oh2 + 1
                }
                oc2 = oc2 + 1
            }
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, out_ch, out_h, out_w), input.requires_grad)
}
