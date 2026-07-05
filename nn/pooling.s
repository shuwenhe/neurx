package neurx.nn.pooling

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

func out_size(int in_size, int kernel, int stride, int padding) int {
    (in_size + 2 * padding - kernel) / stride + 1
}





func max_pool1d(tensor input, int kernel_size, int stride, int padding) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int length = input.shape[2]
    int out_len = out_size(length, kernel_size, stride, padding)
    []float out = []float{cap: batch * channels * out_len}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int ol = 0
            while ol < out_len {
                int start = ol * stride - padding
                float max_v = -999999999999999999999999999999.0
                int k = 0
                while k < kernel_size {
                    int pos = start + k
                    if pos >= 0 && pos < length {
                        float v = input.data[(b * channels + ch) * length + pos]
                        if v > max_v {
                            max_v = v
                        }
                    }
                    k = k + 1
                }
                out[(b * channels + ch) * out_len + ol] = max_v
                ol = ol + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape3(batch, channels, out_len), input.requires_grad)
}





func avg_pool1d(tensor input, int kernel_size, int stride, int padding) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int length = input.shape[2]
    int out_len = out_size(length, kernel_size, stride, padding)
    []float out = []float{cap: batch * channels * out_len}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int ol = 0
            while ol < out_len {
                int start = ol * stride - padding
                float sum_v = 0.0
                int count = 0
                int k = 0
                while k < kernel_size {
                    int pos = start + k
                    if pos >= 0 && pos < length {
                        sum_v = sum_v + input.data[(b * channels + ch) * length + pos]
                        count = count + 1
                    }
                    k = k + 1
                }
                if count == 0 {
                    out[(b * channels + ch) * out_len + ol] = 0.0
                } else {
                    out[(b * channels + ch) * out_len + ol] = sum_v / count
                }
                ol = ol + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape3(batch, channels, out_len), input.requires_grad)
}





func max_pool2d(tensor input, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    int out_h = out_size(in_h, kernel_h, stride_h, pad_h)
    int out_w = out_size(in_w, kernel_w, stride_w, pad_w)
    []float out = []float{cap: batch * channels * out_h * out_w}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int oh = 0
            while oh < out_h {
                int ow = 0
                while ow < out_w {
                    int h_start = oh * stride_h - pad_h
                    int w_start = ow * stride_w - pad_w
                    float max_v = -999999999999999999999999999999.0
                    int khi = 0
                    while khi < kernel_h {
                        int kwi = 0
                        while kwi < kernel_w {
                            int ih = h_start + khi
                            int iw = w_start + kwi
                            if ih >= 0 && ih < in_h && iw >= 0 && iw < in_w {
                                float v = input.data[((b * channels + ch) * in_h + ih) * in_w + iw]
                                if v > max_v {
                                    max_v = v
                                }
                            }
                            kwi = kwi + 1
                        }
                        khi = khi + 1
                    }
                    out[((b * channels + ch) * out_h + oh) * out_w + ow] = max_v
                    ow = ow + 1
                }
                oh = oh + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, channels, out_h, out_w), input.requires_grad)
}





func avg_pool2d(tensor input, int kernel_h, int kernel_w, int stride_h, int stride_w, int pad_h, int pad_w) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    int out_h = out_size(in_h, kernel_h, stride_h, pad_h)
    int out_w = out_size(in_w, kernel_w, stride_w, pad_w)
    []float out = []float{cap: batch * channels * out_h * out_w}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int oh = 0
            while oh < out_h {
                int ow = 0
                while ow < out_w {
                    int h_start = oh * stride_h - pad_h
                    int w_start = ow * stride_w - pad_w
                    float sum_v = 0.0
                    int count = 0
                    int khi = 0
                    while khi < kernel_h {
                        int kwi = 0
                        while kwi < kernel_w {
                            int ih = h_start + khi
                            int iw = w_start + kwi
                            if ih >= 0 && ih < in_h && iw >= 0 && iw < in_w {
                                sum_v = sum_v + input.data[((b * channels + ch) * in_h + ih) * in_w + iw]
                                count = count + 1
                            }
                            kwi = kwi + 1
                        }
                        khi = khi + 1
                    }
                    if count == 0 {
                        out[((b * channels + ch) * out_h + oh) * out_w + ow] = 0.0
                    } else {
                        out[((b * channels + ch) * out_h + oh) * out_w + ow] = sum_v / count
                    }
                    ow = ow + 1
                }
                oh = oh + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, channels, out_h, out_w), input.requires_grad)
}





func adaptive_avg_pool2d(tensor input, int out_h, int out_w) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    []float out = []float{cap: batch * channels * out_h * out_w}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int oh = 0
            while oh < out_h {
                int ow = 0
                while ow < out_w {

                    int h_start = oh * in_h / out_h
                    int h_end = (oh + 1) * in_h / out_h
                    int w_start = ow * in_w / out_w
                    int w_end = (ow + 1) * in_w / out_w
                    if h_end <= h_start {
                        h_end = h_start + 1
                    }
                    if w_end <= w_start {
                        w_end = w_start + 1
                    }
                    float sum_v = 0.0
                    int count = 0
                    int ih = h_start
                    while ih < h_end {
                        int iw = w_start
                        while iw < w_end {
                            sum_v = sum_v + input.data[((b * channels + ch) * in_h + ih) * in_w + iw]
                            count = count + 1
                            iw = iw + 1
                        }
                        ih = ih + 1
                    }
                    if count == 0 {
                        out[((b * channels + ch) * out_h + oh) * out_w + ow] = 0.0
                    } else {
                        out[((b * channels + ch) * out_h + oh) * out_w + ow] = sum_v / count
                    }
                    ow = ow + 1
                }
                oh = oh + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, channels, out_h, out_w), input.requires_grad)
}

func adaptive_max_pool2d(tensor input, int out_h, int out_w) tensor {
    int batch = input.shape[0]
    int channels = input.shape[1]
    int in_h = input.shape[2]
    int in_w = input.shape[3]
    []float out = []float{cap: batch * channels * out_h * out_w}
    int b = 0
    while b < batch {
        int ch = 0
        while ch < channels {
            int oh = 0
            while oh < out_h {
                int ow = 0
                while ow < out_w {
                    int h_start = oh * in_h / out_h
                    int h_end = (oh + 1) * in_h / out_h
                    int w_start = ow * in_w / out_w
                    int w_end = (ow + 1) * in_w / out_w
                    if h_end <= h_start {
                        h_end = h_start + 1
                    }
                    if w_end <= w_start {
                        w_end = w_start + 1
                    }
                    float max_v = -999999999999999999999999999999.0
                    int ih = h_start
                    while ih < h_end {
                        int iw = w_start
                        while iw < w_end {
                            float v = input.data[((b * channels + ch) * in_h + ih) * in_w + iw]
                            if v > max_v {
                                max_v = v
                            }
                            iw = iw + 1
                        }
                        ih = ih + 1
                    }
                    out[((b * channels + ch) * out_h + oh) * out_w + ow] = max_v
                    ow = ow + 1
                }
                oh = oh + 1
            }
            ch = ch + 1
        }
        b = b + 1
    }
    neurx.tensor.new(out, shape4(batch, channels, out_h, out_w), input.requires_grad)
}
