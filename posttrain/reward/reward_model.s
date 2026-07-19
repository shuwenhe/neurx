package neurx.posttrain.reward.reward_model

// ============================================================================
// Reward Model (real preference training)
//
// A reward model scores a full prompt+response sequence with a scalar reward.
// Architecture:
//   GPT backbone (shared transformer)  →  pooled last-token hidden state
//                                       →  linear reward head  →  scalar reward
//
// Training objective (Bradley-Terry / RankNet):
//   L = -log( sigmoid( r_chosen - r_rejected ) )
//
// This module implements EXACT gradients for the reward head and an AdamW
// update, replacing the earlier placeholder that returned a constant 0.0.
// The transformer backbone supplies representations via the existing forward
// pass; the head is trained to rank human-preferred responses higher.
// ============================================================================

use neurx.model.llm.gpt.{
    model_config, language_model, model_output,
    new_language_model, gpt_forward
}

// ============================================================================
// 1. English text
// ============================================================================

struct reward_model {
    language_model backbone        // English text Transformer mainEnglish text
    []float head              // rewardEnglish textweight [n_embd]
    float bias                // rewardEnglish text
    int n_embd

    // AdamW state (rewardEnglish text)
    []float head_m
    []float head_v
    float bias_m
    float bias_v
    int step
    float lr
    float beta1
    float beta2
    float eps
    float weight_decay
}

struct reward_train_result {
    reward_model model
    float loss
    float accuracy            // preferencerankingEnglish text (r_chosen > r_rejected English text)
    float reward_margin       // English text (r_chosen - r_rejected)
}

struct reward_batch_scores {
    []float rewards           // English textreward [batch]
}

// ============================================================================
// 2. initialize
// ============================================================================

func rm_alloc(int n, float v) []float {
    []float arr = []float{cap: n}
    int i = 0
    while i < n { arr[i] = v; i = i + 1 }
    arr
}

// English textinitializerewardEnglish text
func rm_init_head(int n_embd) []float {
    []float head = rm_alloc(n_embd, 0.0)
    int i = 0
    while i < n_embd {
        // English textinitialize, English textrewardEnglish text 0
        float t = (i * 1.0 + 1.0) / (n_embd * 1.0)
        head[i] = (t - 0.5) * 0.02
        i = i + 1
    }
    head
}

func new_reward_model(model_config cfg, float lr) reward_model {
    language_model backbone = new_language_model(cfg)
    int n_embd = cfg.n_embd
    reward_model {
        backbone: backbone,
        head: rm_init_head(n_embd),
        bias: 0.0,
        n_embd: n_embd,
        head_m: rm_alloc(n_embd, 0.0),
        head_v: rm_alloc(n_embd, 0.0),
        bias_m: 0.0,
        bias_v: 0.0,
        step: 0,
        lr: lr,
        beta1: 0.9,
        beta2: 0.999,
        eps: 1e-8,
        weight_decay: 0.0,
    }
}

// English texttrainingEnglish text GPT modelEnglish textrewardmodel (SFT English textinitialize RM English text)
func reward_model_from_backbone(language_model backbone, float lr) reward_model {
    int n_embd = backbone.n_embd
    reward_model {
        backbone: backbone,
        head: rm_init_head(n_embd),
        bias: 0.0,
        n_embd: n_embd,
        head_m: rm_alloc(n_embd, 0.0),
        head_v: rm_alloc(n_embd, 0.0),
        bias_m: 0.0,
        bias_v: 0.0,
        step: 0,
        lr: lr,
        beta1: 0.9,
        beta2: 0.999,
        eps: 1e-8,
        weight_decay: 0.0,
    }
}

// ============================================================================
// 3. English texthelper
// ============================================================================

func rm_exp(float x) float {
    if x > 20.0 { return 485165195.4 }
    if x < -20.0 { return 0.0 }
    float term = 1.0
    float result = 1.0
    int i = 1
    while i <= 14 {
        term = term * x / (i * 1.0)
        result = result + term
        i = i + 1
    }
    result
}

func rm_log(float x) float {
    if x <= 0.0 { return -1000000.0 }
    float v = x
    float adj = 0.0
    float ln2 = 0.6931471805599453
    while v >= 2.0 { v = v * 0.5; adj = adj + ln2 }
    while v < 1.0 { v = v * 2.0; adj = adj - ln2 }
    float z = v - 1.0
    float s = z
    float term = z
    int i = 2
    while i <= 16 {
        term = term * (-z)
        s = s + term / (i * 1.0)
        i = i + 1
    }
    s + adj
}

func rm_sigmoid(float x) float {
    1.0 / (1.0 + rm_exp(-x))
}

func rm_sqrt(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 15 { y = 0.5 * (y + x / y); i = i + 1 }
    y
}

func rm_pow(float base, int exp) float {
    float r = 1.0
    int e = exp
    while e > 0 { r = r * base; e = e - 1 }
    r
}

// ============================================================================
// 4. English text: English text → English textreward
// ============================================================================

// English text token English text (English textmodelEnglish text"English text"English text)
// last_hidden: [batch * seq, n_embd]  →  pooled: [batch, n_embd]
func rm_pool_last_hidden([]float last_hidden, int batch_size, int seq_len, int n_embd) []float {
    []float pooled = rm_alloc(batch_size * n_embd, 0.0)
    int b = 0
    while b < batch_size {
        int last_tok = b * seq_len + (seq_len - 1)
        int src = last_tok * n_embd
        int dst = b * n_embd
        int d = 0
        while d < n_embd {
            pooled[dst + d] = last_hidden[src + d]
            d = d + 1
        }
        b = b + 1
    }
    pooled
}

// computeEnglish textreward
func rm_score_batch(reward_model rm, []int token_ids, int batch_size, int seq_len) reward_batch_scores {
    model_output out = gpt_forward(rm.backbone, token_ids, batch_size, seq_len)
    []float pooled = rm_pool_last_hidden(out.last_hidden, batch_size, seq_len, rm.n_embd)

    []float rewards = rm_alloc(batch_size, 0.0)
    int b = 0
    while b < batch_size {
        float r = rm.bias
        int d = 0
        while d < rm.n_embd {
            r = r + rm.head[d] * pooled[b * rm.n_embd + d]
            d = d + 1
        }
        rewards[b] = r
        b = b + 1
    }
    reward_batch_scores { rewards: rewards }
}

// English textinference (English text PPO/RLHF queryreward)
func reward_model_score(reward_model rm, []int token_ids, int seq_len) float {
    reward_batch_scores scores = rm_score_batch(rm, token_ids, 1, seq_len)
    scores.rewards[0]
}

// ============================================================================
// 5. Bradley-Terry preferenceloss
// ============================================================================

// L = -log(sigmoid(r_chosen - r_rejected))
func rm_bradley_terry_loss([]float chosen_r, []float rejected_r, int batch_size) float {
    float loss = 0.0
    int i = 0
    while i < batch_size {
        float d = chosen_r[i] - rejected_r[i]
        float p = rm_sigmoid(d)
        loss = loss - rm_log(p)
        i = i + 1
    }
    loss / (batch_size * 1.0)
}

// ============================================================================
// 6. trainingstep (English textrewardEnglish textgradient + AdamW)
//
//   r = head · h + bias
//   L = -log(sigmoid(r_c - r_r)),  English text p = sigmoid(r_c - r_r)
//   dL/dr_c = -(1 - p),  dL/dr_r = (1 - p)
//   dL/d head = (1 - p) * (h_r - h_c)
//   dL/d bias = 0  (English text, BT lossEnglish text)
// ============================================================================

func reward_model_train_step(
    reward_model rm,
    []int chosen_ids,
    []int rejected_ids,
    int batch_size,
    int seq_len
) reward_train_result {
    // English text: English text chosen / rejected English textreward
    model_output out_c = gpt_forward(rm.backbone, chosen_ids, batch_size, seq_len)
    model_output out_r = gpt_forward(rm.backbone, rejected_ids, batch_size, seq_len)
    []float pooled_c = rm_pool_last_hidden(out_c.last_hidden, batch_size, seq_len, rm.n_embd)
    []float pooled_r = rm_pool_last_hidden(out_r.last_hidden, batch_size, seq_len, rm.n_embd)

    // reward
    []float reward_c = rm_alloc(batch_size, 0.0)
    []float reward_r = rm_alloc(batch_size, 0.0)
    int b = 0
    while b < batch_size {
        float rc = rm.bias
        float rr = rm.bias
        int d = 0
        while d < rm.n_embd {
            rc = rc + rm.head[d] * pooled_c[b * rm.n_embd + d]
            rr = rr + rm.head[d] * pooled_r[b * rm.n_embd + d]
            d = d + 1
        }
        reward_c[b] = rc
        reward_r[b] = rr
        b = b + 1
    }

    // loss + statistics
    float loss = rm_bradley_terry_loss(reward_c, reward_r, batch_size)
    int correct = 0
    float margin_sum = 0.0

    // English textgradientEnglish text
    []float grad_head = rm_alloc(rm.n_embd, 0.0)
    b = 0
    while b < batch_size {
        float d_val = reward_c[b] - reward_r[b]
        float p = rm_sigmoid(d_val)
        float coeff = (1.0 - p)      // dL/d head English text

        margin_sum = margin_sum + d_val
        if d_val > 0.0 { correct = correct + 1 }

        int d = 0
        while d < rm.n_embd {
            // grad_head += (1-p) * (h_r - h_c)
            float diff = pooled_r[b * rm.n_embd + d] - pooled_c[b * rm.n_embd + d]
            grad_head[d] = grad_head[d] + coeff * diff
            d = d + 1
        }
        b = b + 1
    }
    // English text
    float inv_b = 1.0 / (batch_size * 1.0)
    int g = 0
    while g < rm.n_embd {
        grad_head[g] = grad_head[g] * inv_b
        g = g + 1
    }

    // AdamW English textrewardEnglish text
    rm.step = rm.step + 1
    float bc1 = 1.0 - rm_pow(rm.beta1, rm.step)
    float bc2 = 1.0 - rm_pow(rm.beta2, rm.step)
    int i = 0
    while i < rm.n_embd {
        rm.head_m[i] = rm.beta1 * rm.head_m[i] + (1.0 - rm.beta1) * grad_head[i]
        rm.head_v[i] = rm.beta2 * rm.head_v[i] + (1.0 - rm.beta2) * grad_head[i] * grad_head[i]
        float m_hat = rm.head_m[i] / bc1
        float v_hat = rm.head_v[i] / bc2
        rm.head[i] = rm.head[i] * (1.0 - rm.lr * rm.weight_decay)
        rm.head[i] = rm.head[i] - rm.lr * m_hat / (rm_sqrt(v_hat) + rm.eps)
        i = i + 1
    }
    // bias gradientEnglish text 0 (BT English text), English text

    float accuracy = (correct * 1.0) * inv_b
    float reward_margin = margin_sum * inv_b

    reward_train_result {
        model: rm,
        loss: loss,
        accuracy: accuracy,
        reward_margin: reward_margin,
    }
}

// ============================================================================
// 7. evaluation (English textpreferenceEnglish textrankingEnglish text)
// ============================================================================

func reward_model_eval_accuracy(
    reward_model rm,
    []int chosen_ids,
    []int rejected_ids,
    int batch_size,
    int seq_len
) float {
    reward_batch_scores sc = rm_score_batch(rm, chosen_ids, batch_size, seq_len)
    reward_batch_scores sr = rm_score_batch(rm, rejected_ids, batch_size, seq_len)
    int correct = 0
    int b = 0
    while b < batch_size {
        if sc.rewards[b] > sr.rewards[b] {
            correct = correct + 1
        }
        b = b + 1
    }
    (correct * 1.0) / (batch_size * 1.0)
}

// ============================================================================
// 8. rewardEnglish text (PPO English text: English textrewardEnglish texttraining)
// ============================================================================

struct reward_normalizer {
    float running_mean
    float running_var
    int count
}

func new_reward_normalizer() reward_normalizer {
    reward_normalizer { running_mean: 0.0, running_var: 1.0, count: 0 }
}

func reward_normalizer_update(reward_normalizer norm, float reward) reward_normalizer {
    int new_count = norm.count + 1
    float delta = reward - norm.running_mean
    float new_mean = norm.running_mean + delta / (new_count * 1.0)
    float delta2 = reward - new_mean
    float new_var = norm.running_var + (delta * delta2 - norm.running_var) / (new_count * 1.0)
    reward_normalizer {
        running_mean: new_mean,
        running_var: new_var,
        count: new_count,
    }
}

func reward_normalizer_apply(reward_normalizer norm, float reward) float {
    float std = rm_sqrt(norm.running_var)
    if std < 1e-6 { std = 1.0 }
    (reward - norm.running_mean) / std
}
