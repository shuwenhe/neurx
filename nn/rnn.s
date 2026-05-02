package neurx.nn.rnn

use neurx.tensor.tensor

// ---- math helpers ----

func _exp_approx(float x) float {
    if x > 20.0 {
        return 485165195.0
    }
    if x < -20.0 {
        return 0.0
    }
    float result = 1.0
    float term = 1.0
    int i = 1
    while i <= 10 {
        term = term * x / i
        result = result + term
        i = i + 1
    }
    result
}

func _tanh_approx(float x) float {
    float ep = _exp_approx(x)
    float en = _exp_approx(-x)
    float denom = ep + en
    if denom == 0.0 {
        return 0.0
    }
    (ep - en) / denom
}

func _sigmoid(float x) float {
    1.0 / (1.0 + _exp_approx(-x))
}

func _copy_float([]float data) []float {
    int n = len(data)
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _copy_int([]int data) []int {
    int n = len(data)
    []int out = []int{cap: n}
    int i = 0
    while i < n {
        out[i] = data[i]
        i = i + 1
    }
    out
}

func _shape2(int a, int b) []int {
    []int s = []int{cap: 2}
    s[0] = a
    s[1] = b
    s
}

func _shape3(int a, int b, int c) []int {
    []int s = []int{cap: 3}
    s[0] = a
    s[1] = b
    s[2] = c
    s
}

// ---- matmul helpers ----

// mat_vec: (rows x cols) @ (cols,) -> (rows,)
func _mat_vec([]float weight, int rows, int cols, []float vec) []float {
    []float out = []float{cap: rows}
    int r = 0
    while r < rows {
        float acc = 0.0
        int c = 0
        while c < cols {
            acc = acc + weight[r * cols + c] * vec[c]
            c = c + 1
        }
        out[r] = acc
        r = r + 1
    }
    out
}

// add two equal-length float arrays
func _vec_add([]float a, []float b, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = a[i] + b[i]
        i = i + 1
    }
    out
}

func _vec_mul([]float a, []float b, int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = a[i] * b[i]
        i = i + 1
    }
    out
}

func _zeros(int n) []float {
    []float out = []float{cap: n}
    int i = 0
    while i < n {
        out[i] = 0.0
        i = i + 1
    }
    out
}

// ---- RNNCell ----
// h_t = tanh(W_ih * x_t + b_ih + W_hh * h_{t-1} + b_hh)

struct rnn_cell_state {
    int input_size
    int hidden_size
    []float weight_ih   // (hidden_size, input_size)
    []float weight_hh   // (hidden_size, hidden_size)
    []float bias_ih     // (hidden_size,)
    []float bias_hh     // (hidden_size,)
}

func new_rnn_cell(int input_size, int hidden_size) rnn_cell_state {
    rnn_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih: _zeros(hidden_size * input_size),
        weight_hh: _zeros(hidden_size * hidden_size),
        bias_ih: _zeros(hidden_size),
        bias_hh: _zeros(hidden_size),
    }
}

// x: (input_size,), h_prev: (hidden_size,) -> h_next: (hidden_size,)
func rnn_cell_forward(rnn_cell_state cell, []float x, []float h_prev) []float {
    int hs = cell.hidden_size
    []float gi = _mat_vec(cell.weight_ih, hs, cell.input_size, x)
    []float gh = _mat_vec(cell.weight_hh, hs, hs, h_prev)
    []float pre = _vec_add(_vec_add(gi, cell.bias_ih, hs), _vec_add(gh, cell.bias_hh, hs), hs)
    []float out = []float{cap: hs}
    int i = 0
    while i < hs {
        out[i] = _tanh_approx(pre[i])
        i = i + 1
    }
    out
}

// RNN over a sequence: input (seq_len, input_size), initial h (hidden_size,)
// Returns last hidden state (hidden_size,) and all hidden states (seq_len, hidden_size)

struct rnn_output {
    []float last_hidden   // (hidden_size,)
    []float all_hidden    // (seq_len * hidden_size,)
    int seq_len
    int hidden_size
}

func rnn_forward(rnn_cell_state cell, []float input, int seq_len, []float h0) rnn_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = _copy_float(h0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    while t < seq_len {
        // slice x = input[t * is_ .. (t+1) * is_]
        []float x = []float{cap: is_}
        int j = 0
        while j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        h = rnn_cell_forward(cell, x, h)
        j = 0
        while j < hs {
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

// ---- LSTMCell ----
// Input gate:  i = sigmoid(W_ii * x + b_ii + W_hi * h + b_hi)
// Forget gate: f = sigmoid(W_if * x + b_if + W_hf * h + b_hf)
// Cell gate:   g = tanh(W_ig * x + b_ig + W_hg * h + b_hg)
// Output gate: o = sigmoid(W_io * x + b_io + W_ho * h + b_ho)
// c_next = f * c + i * g
// h_next = o * tanh(c_next)

struct lstm_cell_state {
    int input_size
    int hidden_size
    // Combined gates weight: (4*hidden_size, input_size) stored as flat
    []float weight_ih   // (4*hs, is)
    []float weight_hh   // (4*hs, hs)
    []float bias_ih     // (4*hs,)
    []float bias_hh     // (4*hs,)
}

func new_lstm_cell(int input_size, int hidden_size) lstm_cell_state {
    int g = 4 * hidden_size
    lstm_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih: _zeros(g * input_size),
        weight_hh: _zeros(g * hidden_size),
        bias_ih: _zeros(g),
        bias_hh: _zeros(g),
    }
}

struct lstm_cell_output {
    []float h_next  // (hidden_size,)
    []float c_next  // (hidden_size,)
}

func lstm_cell_forward(lstm_cell_state cell, []float x, []float h_prev, []float c_prev) lstm_cell_output {
    int hs = cell.hidden_size
    int g = 4 * hs
    []float gi = _mat_vec(cell.weight_ih, g, cell.input_size, x)
    []float gh = _mat_vec(cell.weight_hh, g, hs, h_prev)
    []float pre = _vec_add(_vec_add(gi, cell.bias_ih, g), _vec_add(gh, cell.bias_hh, g), g)
    // Split into 4 gates
    []float i_gate = []float{cap: hs}
    []float f_gate = []float{cap: hs}
    []float g_gate = []float{cap: hs}
    []float o_gate = []float{cap: hs}
    int j = 0
    while j < hs {
        i_gate[j] = _sigmoid(pre[j])
        f_gate[j] = _sigmoid(pre[hs + j])
        g_gate[j] = _tanh_approx(pre[2 * hs + j])
        o_gate[j] = _sigmoid(pre[3 * hs + j])
        j = j + 1
    }
    []float c_next = []float{cap: hs}
    []float h_next = []float{cap: hs}
    j = 0
    while j < hs {
        c_next[j] = f_gate[j] * c_prev[j] + i_gate[j] * g_gate[j]
        h_next[j] = o_gate[j] * _tanh_approx(c_next[j])
        j = j + 1
    }
    lstm_cell_output {
        h_next: h_next,
        c_next: c_next,
    }
}

// LSTM over sequence: input (seq_len, input_size), initial h (hidden_size,), initial c (hidden_size,)

struct lstm_output {
    []float last_hidden   // (hidden_size,)
    []float last_cell     // (hidden_size,)
    []float all_hidden    // (seq_len * hidden_size,)
    int seq_len
    int hidden_size
}

func lstm_forward(lstm_cell_state cell, []float input, int seq_len, []float h0, []float c0) lstm_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = _copy_float(h0)
    []float c = _copy_float(c0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    while t < seq_len {
        []float x = []float{cap: is_}
        int j = 0
        while j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        lstm_cell_output step = lstm_cell_forward(cell, x, h, c)
        h = step.h_next
        c = step.c_next
        j = 0
        while j < hs {
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

// ---- GRUCell ----
// Reset gate:  r = sigmoid(W_ir * x + b_ir + W_hr * h + b_hr)
// Update gate: z = sigmoid(W_iz * x + b_iz + W_hz * h + b_hz)
// New gate:    n = tanh(W_in * x + b_in + r * (W_hn * h + b_hn))
// h_next = (1 - z) * n + z * h

struct gru_cell_state {
    int input_size
    int hidden_size
    // Weights for r+z gates combined: (2*hs, is) and (2*hs, hs)
    []float weight_ih_rz   // (2*hs, is)
    []float weight_hh_rz   // (2*hs, hs)
    []float bias_ih_rz     // (2*hs,)
    []float bias_hh_rz     // (2*hs,)
    // Weights for n gate
    []float weight_ih_n    // (hs, is)
    []float weight_hh_n    // (hs, hs)
    []float bias_ih_n      // (hs,)
    []float bias_hh_n      // (hs,)
}

func new_gru_cell(int input_size, int hidden_size) gru_cell_state {
    int rz = 2 * hidden_size
    gru_cell_state {
        input_size: input_size,
        hidden_size: hidden_size,
        weight_ih_rz: _zeros(rz * input_size),
        weight_hh_rz: _zeros(rz * hidden_size),
        bias_ih_rz: _zeros(rz),
        bias_hh_rz: _zeros(rz),
        weight_ih_n: _zeros(hidden_size * input_size),
        weight_hh_n: _zeros(hidden_size * hidden_size),
        bias_ih_n: _zeros(hidden_size),
        bias_hh_n: _zeros(hidden_size),
    }
}

func gru_cell_forward(gru_cell_state cell, []float x, []float h_prev) []float {
    int hs = cell.hidden_size
    int rz = 2 * hs
    // Compute r and z gates
    []float gi_rz = _mat_vec(cell.weight_ih_rz, rz, cell.input_size, x)
    []float gh_rz = _mat_vec(cell.weight_hh_rz, rz, hs, h_prev)
    []float pre_rz = _vec_add(_vec_add(gi_rz, cell.bias_ih_rz, rz), _vec_add(gh_rz, cell.bias_hh_rz, rz), rz)
    []float r = []float{cap: hs}
    []float z = []float{cap: hs}
    int j = 0
    while j < hs {
        r[j] = _sigmoid(pre_rz[j])
        z[j] = _sigmoid(pre_rz[hs + j])
        j = j + 1
    }
    // Compute new gate: n = tanh(W_in*x + b_in + r*(W_hn*h + b_hn))
    []float gi_n = _mat_vec(cell.weight_ih_n, hs, cell.input_size, x)
    []float gh_n = _mat_vec(cell.weight_hh_n, hs, hs, h_prev)
    []float n = []float{cap: hs}
    j = 0
    while j < hs {
        float pre_n = gi_n[j] + cell.bias_ih_n[j] + r[j] * (gh_n[j] + cell.bias_hh_n[j])
        n[j] = _tanh_approx(pre_n)
        j = j + 1
    }
    // h_next = (1 - z) * n + z * h_prev
    []float h_next = []float{cap: hs}
    j = 0
    while j < hs {
        h_next[j] = (1.0 - z[j]) * n[j] + z[j] * h_prev[j]
        j = j + 1
    }
    h_next
}

// GRU over sequence

struct gru_output {
    []float last_hidden   // (hidden_size,)
    []float all_hidden    // (seq_len * hidden_size,)
    int seq_len
    int hidden_size
}

func gru_forward(gru_cell_state cell, []float input, int seq_len, []float h0) gru_output {
    int hs = cell.hidden_size
    int is_ = cell.input_size
    []float h = _copy_float(h0)
    []float all_h = []float{cap: seq_len * hs}
    int t = 0
    while t < seq_len {
        []float x = []float{cap: is_}
        int j = 0
        while j < is_ {
            x[j] = input[t * is_ + j]
            j = j + 1
        }
        h = gru_cell_forward(cell, x, h)
        j = 0
        while j < hs {
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
