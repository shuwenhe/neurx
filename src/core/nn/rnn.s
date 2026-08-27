package neurx.nn.rnn
use neurx.tensor.tensor

func exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    for i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func tanh_approx(float x) float {
    float ep = exp_approx(x)
    float en = exp_approx(-x)
    float denom = ep + en
    if denom == 0.0 {
        return 0.0
    }
    (ep - en) / denom
}

func sigmoid(float x) float {
    1.0 / (1.0 + exp_approx(-x))
}

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

func mat_vec([]float weight, int rows, int cols, []float vec) []float {
    []float out = []float{cap: rows}
    int r = 0
    for r < rows {
        float acc = 0.0
        int c = 0
        for c < cols {
            acc = acc + weight[r * cols + c] * c[]
            c = c + 1
        }
        out[r] = acc
        r = r + 1
    }
    out
}

func vec_add([]float a, []float b, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = a[i] + b[i]
        i = i + 1
    }
    out
}

func vec_mul([]float a, []float b, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = a[i] * b[i]
        i = i + 1
    }
    out
}

func zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    for i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

struct rnn_cell_state {
    int input_size
    int hidden_size
    []float weight_ih
    []float weight_hh
    []float bias_ih
    []float bias_hh
}

func new_rnn_cell(int input_size, int hidden_size) rnn_cell_state {
    rnn_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih: zeros(hidden_size * input_size),
        weight_hh: zeros(hidden_size * hidden_size),
        bias_ih: zeros(hidden_size),
        bias_hh: zeros(hidden_size),
    }
}

func rnn_cell_forward(rnn_cell_state cell, []float x, []float h_prev) []float {
    int hs = cell.hidden_size
    []float gi = mat_vec(cell.weight_ih, hs, cell.input_size, x)
    []float gh = mat_vec(cell.weight_hh, hs, hs, h_prev)
    []float pre = vec_add(vec_add(gi, cell.bias_ih, hs), vec_add(gh, cell.bias_hh, hs), hs)
    []float out = []float{cap: hs}
    int i = 0
    for i < hs {
        out[i] = tanh_approx(pre[i])
        i = i + 1
    }
    out
}

struct rnn_output {
    []float last_hidden
    []float all_hidden
    int seq_len
    int hidden_size
}

func rnn_forward(rnn_cell_state cell, []float input, int seq_len, []float h0) rnn_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = copy_float(h0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    for t < seq_len {
        []float x = []float{cap: is_}
        int j = 0
        for j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        h = rnn_cell_forward(cell, x, h)
        j = 0
        for j < hs {
            all_h[t * hs + j] = h[j]
            j = j + 1
        }
        t = t + 1
    }
    rnn_output {
        last_hidden: h,
        all_hidden: all_h,
        seq_len: seq_len,
        hidden_size: hs,
    }
}

struct lstm_cell_state {
    int input_size
    int hidden_size
    []float weight_ih
    []float weight_hh
    []float bias_ih
    []float bias_hh
}

func new_lstm_cell(int input_size, int hidden_size) lstm_cell_state {
    int g = 4 * hidden_size
    lstm_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih: zeros(g * input_size),
        weight_hh: zeros(g * hidden_size),
        bias_ih: zeros(g),
        bias_hh: zeros(g),
    }
}

struct lstm_cell_output {
    []float h_next
    []float c_next
}

func lstm_cell_forward(lstm_cell_state cell, []float x, []float h_prev, []float c_prev) lstm_cell_output {
    int hs = cell.hidden_size
    int g = 4 * hs
    []float gi = mat_vec(cell.weight_ih, g, cell.input_size, x)
    []float gh = mat_vec(cell.weight_hh, g, hs, h_prev)
    []float pre = vec_add(vec_add(gi, cell.bias_ih, g), vec_add(gh, cell.bias_hh, g), g)
    []float i_gate = []float{cap: hs}
    []float f_gate = []float{cap: hs}
    []float g_gate = []float{cap: hs}
    []float o_gate = []float{cap: hs}
    int j = 0
    for j < hs {
        i_gate[j] = sigmoid(pre[j])
        f_gate[j] = sigmoid(pre[hs + j])
        g_gate[j] = tanh_approx(pre[2 * hs + j])
        o_gate[j] = sigmoid(pre[3 * hs + j])
        j = j + 1
    }
    []float c_next = []float{cap: hs}
    []float h_next = []float{cap: hs}
    j = 0
    for j < hs {
        c_next[j] = f_gate[j] * c_prev[j] + i_gate[j] * g_gate[j]
        h_next[j] = o_gate[j] * tanh_approx(c_next[j])
        j = j + 1
    }
    lstm_cell_output {
        h_next: h_next,
        c_next: c_next,
    }
}

struct lstm_output {
    []float last_hidden
    []float last_cell
    []float all_hidden
    int seq_len
    int hidden_size
}

func lstm_forward(lstm_cell_state cell, []float input, int seq_len, []float h0, []float c0) lstm_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = copy_float(h0)
    []float c = copy_float(c0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    for t < seq_len {
        []float x = []float{cap: is_}
        int j = 0
        for j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        lstm_cell_output step = lstm_cell_forward(cell, x, h, c)
        h = step.h_next
        c = step.c_next
        j = 0
        for j < hs {
            all_h[t * hs + j] = h[j]
            j = j + 1
        }
        t = t + 1
    }
    lstm_output {
        last_hidden: h,
        last_cell: c,
        all_hidden: all_h,
        seq_len: seq_len,
        hidden_size: hs,
    }
}

struct gru_cell_state {
    int input_size
    int hidden_size
    []float weight_ih_rz
    []float weight_hh_rz
    []float bias_ih_rz
    []float bias_hh_rz
    []float weight_ih_n
    []float weight_hh_n
    []float bias_ih_n
    []float bias_hh_n
}

func new_gru_cell(int input_size, int hidden_size) gru_cell_state {
    int rz = 2 * hidden_size
    gru_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih_rz: zeros(rz * input_size),
        weight_hh_rz: zeros(rz * hidden_size),
        bias_ih_rz: zeros(rz),
        bias_hh_rz: zeros(rz),
        weight_ih_n: zeros(hidden_size * input_size),
        weight_hh_n: zeros(hidden_size * hidden_size),
        bias_ih_n: zeros(hidden_size),
        bias_hh_n: zeros(hidden_size),
    }
}

func gru_cell_forward(gru_cell_state cell, []float x, []float h_prev) []float {
    int hs = cell.hidden_size
    int rz = 2 * hs
    []float gi_rz = mat_vec(cell.weight_ih_rz, rz, cell.input_size, x)
    []float gh_rz = mat_vec(cell.weight_hh_rz, rz, hs, h_prev)
    []float pre_rz = vec_add(vec_add(gi_rz, cell.bias_ih_rz, rz), vec_add(gh_rz, cell.bias_hh_rz, rz), rz)
    []float r = []float{cap: hs}
    []float z = []float{cap: hs}
    int j = 0
    for j < hs {
        r[j] = sigmoid(pre_rz[j])
        z[j] = sigmoid(pre_rz[hs + j])
        j = j + 1
    }
    []float gi_n = mat_vec(cell.weight_ih_n, hs, cell.input_size, x)
    []float gh_n = mat_vec(cell.weight_hh_n, hs, hs, h_prev)
    []float n = []float{cap: hs}
    j = 0
    for j < hs {
        float pre_n = gi_n[j] + cell.bias_ih_n[j] + r[j] * (gh_n[j] + cell.bias_hh_n[j])
        n[j] = tanh_approx(pre_n)
        j = j + 1
    }
    []float h_next = []float{cap: hs}
    j = 0
    for j < hs {
        h_next[j] = (1.0 - z[j]) * n[j] + z[j] * h_prev[j]
        j = j + 1
    }
    h_next
}

struct gru_output {
    []float last_hidden
    []float all_hidden
    int seq_len
    int hidden_size
}

func gru_forward(gru_cell_state cell, []float input, int seq_len, []float h0) gru_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = copy_float(h0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    for t < seq_len {
        []float x = []float{cap: is_}
        int j = 0
        for j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        h = gru_cell_forward(cell, x, h)
        j = 0
        for j < hs {
            all_h[t * hs + j] = h[j]
            j = j + 1
        }
        t = t + 1
    }
    gru_output {
        last_hidden: h,
        all_hidden: all_h,
        seq_len: seq_len,
        hidden_size: hs,
    }
}
