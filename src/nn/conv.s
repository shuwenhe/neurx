package neurx.nn.conv

use neurx.tensor.tensor



func copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
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
    while i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    while i < out_channels {
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
    while b < batch {
        int oc = 0
        while oc < out_ch {
            int ol = 0
            while ol < out_len {
                float acc = 0.0
                if layer.use_bias {
                    acc = layer.bias[oc]
                }
                int ic = 0
                while ic < in_ch {
                    int k = 0
                    while k < ks {
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
    while i < w_size {
        weight[i] = 0.0
        i = i + 1
    }
    []float bias = []float{cap: out_channels}
    i = 0
    while i < out_channels {
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
    while b < batch {
        int oc = 0
        while oc < out_ch {
            int oh = 0
            while oh < out_h {
                int ow = 0
                while ow < out_w {
                    float acc = 0.0
                    if layer.use_bias {
                        acc = layer.bias[oc]
                    }
                    int ic = 0
                    while ic < in_ch {
                        int khi = 0
                        while khi < kh {
                            int kwi = 0
                            while kwi < kw {
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
