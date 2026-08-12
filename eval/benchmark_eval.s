package neurx.eval.benchmark_eval
use neurx.model.llm.gpt.{
    model_config, language_model, model_output,
    gpt_forward, gpt_generate_greedy
}


func be_exp(float x) float {
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


func be_log(float x) float {
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


struct logprob_result {
    float total_logprob
    int num_tokens
    float avg_logprob
}


func gpt_sequence_logprob(
    language_model model,
    []int full_tokens,
    int prompt_len
) logprob_result {
    int seq_len = len(full_tokens)
    if seq_len <= prompt_len {
        return logprob_result { total_logprob: 0.0, num_tokens: 0, avg_logprob: 0.0 }
    }
    model_output out = gpt_forward(model, full_tokens, 1, seq_len)
    int vocab = model.vocab_size
    float total_logprob = 0.0
    int num_tokens = 0
    int t = prompt_len
    while t < seq_len {
        int logit_base = (t - 1) * vocab
        int target = full_tokens[t]
        if target < 0 { target = 0 }
        if target >= vocab { target = vocab - 1 }
        float max_l = out.logits[logit_base]
        int j = 1
        while j < vocab {
            if out.logits[logit_base + j] > max_l {
                max_l = out.logits[logit_base + j]
            }
            j = j + 1
        }
        float sum_exp = 0.0
        j = 0
        while j < vocab {
            sum_exp = sum_exp + be_exp(out.logits[logit_base + j] - max_l)
            j = j + 1
        }
        float log_sum_exp = be_log(sum_exp) + max_l
        float token_logprob = out.logits[logit_base + target] - log_sum_exp
        total_logprob = total_logprob + token_logprob
        num_tokens = num_tokens + 1
        t = t + 1
    }
    float avg = 0.0
    if num_tokens > 0 {
        avg = total_logprob / (num_tokens * 1.0)
    }
    logprob_result {
        total_logprob: total_logprob,
        num_tokens: num_tokens,
        avg_logprob: avg,
    }
}


struct mc_choice {
    []int continuation_tokens
}


struct mc_question {
    []int prompt_tokens
    []mc_choice choices
    int num_choices
    int correct_index
}


struct mc_eval_result {
    int total
    int correct
    float accuracy
    float avg_confidence
}


func mc_predict(language_model model, mc_question q) int {
    int best_idx = 0
    float best_score = -1000000000.0
    int c = 0
    while c < q.num_choices {
        []int full = mc_concat(q.prompt_tokens, q.choices[c].continuation_tokens)
        logprob_result lp = gpt_sequence_logprob(model, full, len(q.prompt_tokens))
        float score = lp.avg_logprob
        if score > best_score {
            best_score = score
            best_idx = c
        }
        c = c + 1
    }
    best_idx
}


func mc_concat([]int a, []int b) []int {
    int n = len(a) + len(b)
    []int out = []int{cap: n}
    int i = 0
    while i < len(a) { out[i] = a[i]; i = i + 1 }
    int j = 0
    while j < len(b) { out[len(a) + j] = b[j]; j = j + 1 }
    out
}


func evaluate_multiple_choice(language_model model, []mc_question questions) mc_eval_result {
    int total = len(questions)
    int correct = 0
    float conf_sum = 0.0
    int i = 0
    while i < total {
        mc_question q = questions[i]
        float best = -1000000000.0
        float second = -1000000000.0
        int best_idx = 0
        int c = 0
        while c < q.num_choices {
            []int full = mc_concat(q.prompt_tokens, q.choices[c].continuation_tokens)
            logprob_result lp = gpt_sequence_logprob(model, full, len(q.prompt_tokens))
            float score = lp.avg_logprob
            if score > best {
                second = best
                best = score
                best_idx = c
            } else if score > second {
                second = score
            }
            c = c + 1
        }
        if best_idx == q.correct_index {
            correct = correct + 1
        }
        conf_sum = conf_sum + (best - second)
        i = i + 1
    }
    float accuracy = 0.0
    float avg_conf = 0.0
    if total > 0 {
        accuracy = (correct * 1.0) / (total * 1.0)
        avg_conf = conf_sum / (total * 1.0)
    }
    mc_eval_result {
        total: total,
        correct: correct,
        accuracy: accuracy,
        avg_confidence: avg_conf,
    }
}


struct ppl_result {
    float perplexity
    float avg_loss
    int total_tokens
}


func evaluate_perplexity(language_model model, [][]int sequences) ppl_result {
    float total_loss = 0.0
    int total_tokens = 0
    int s = 0
    while s < len(sequences) {
        []int seq = sequences[s]
        int seq_len = len(seq)
        if seq_len < 2 {
            s = s + 1
            continue
        }
        logprob_result lp = gpt_sequence_logprob(model, seq, 1)
        total_loss = total_loss - lp.total_logprob
        total_tokens = total_tokens + lp.num_tokens
        s = s + 1
    }
    float avg_loss = 0.0
    if total_tokens > 0 {
        avg_loss = total_loss / (total_tokens * 1.0)
    }
    ppl_result {
        perplexity: be_exp(avg_loss),
        avg_loss: avg_loss,
        total_tokens: total_tokens,
    }
}


struct gen_question {
    []int prompt_tokens
    []int answer_tokens
    int max_new_tokens
}


struct gen_eval_result {
    int total
    int correct
    float exact_match
}


func gen_contains_answer([]int generated, []int answer) bool {
    int g = len(generated)
    int a = len(answer)
    if a == 0 { return true }
    if a > g { return false }
    int i = 0
    while i <= g - a {
        bool match = true
        int j = 0
        while j < a {
            if generated[i + j] != answer[j] {
                match = false
                break
            }
            j = j + 1
        }
        if match { return true }
        i = i + 1
    }
    false
}


func evaluate_generative(language_model model, []gen_question questions) gen_eval_result {
    int total = len(questions)
    int correct = 0
    int i = 0
    while i < total {
        gen_question q = questions[i]
        []int generated = gpt_generate_greedy(model, q.prompt_tokens, q.max_new_tokens)
        if gen_contains_answer(generated, q.answer_tokens) {
            correct = correct + 1
        }
        i = i + 1
    }
    float em = 0.0
    if total > 0 {
        em = (correct * 1.0) / (total * 1.0)
    }
    gen_eval_result {
        total: total,
        correct: correct,
        exact_match: em,
    }
}


struct benchmark_report {
    float mmlu_acc
    float hellaswag_acc
    float arc_acc
    float winogrande_acc
    float wikitext_ppl
    float gsm8k_em
    float humaneval_em
    float average_score
}


struct benchmark_suite {
    []mc_question mmlu
    []mc_question hellaswag
    []mc_question arc
    []mc_question winogrande
    [][]int wikitext
    []gen_question gsm8k
    []gen_question humaneval
}


func run_benchmark_suite(language_model model, benchmark_suite suite) benchmark_report {
    mc_eval_result mmlu = evaluate_multiple_choice(model, suite.mmlu)
    mc_eval_result hella = evaluate_multiple_choice(model, suite.hellaswag)
    mc_eval_result arc = evaluate_multiple_choice(model, suite.arc)
    mc_eval_result wino = evaluate_multiple_choice(model, suite.winogrande)
    ppl_result wiki = evaluate_perplexity(model, suite.wikitext)
    gen_eval_result gsm = evaluate_generative(model, suite.gsm8k)
    gen_eval_result he = evaluate_generative(model, suite.humaneval)
    float avg = (mmlu.accuracy + hella.accuracy + arc.accuracy + wino.accuracy) / 4.0
    benchmark_report {
        mmlu_acc: mmlu.accuracy,
        hellaswag_acc: hella.accuracy,
        arc_acc: arc.accuracy,
        winogrande_acc: wino.accuracy,
        wikitext_ppl: wiki.perplexity,
        gsm8k_em: gsm.exact_match,
        humaneval_em: he.exact_match,
        average_score: avg,
    }
}


func be_int_str(int n) string {
    if n == 0 { return "0" }
    bool neg = n < 0
    int v = n
    if neg { v = -v }
    string s = ""
    while v > 0 {
        int d = v - (v / 10) * 10
        s = string(d + 48) + s
        v = v / 10
    }
    if neg { s = "-" + s }
    s
}


func be_pct(float acc) string {
    int pct = 0
    float v = acc * 100.0
    while v >= 1.0 {
        v = v - 1.0
        pct = pct + 1
    }
    be_int_str(pct) + "%"
}


func format_benchmark_report(benchmark_report r) string {
    string s = ""
    s = s + "╔════════════════════════════════════════╗\n"
    s = s + "║   NeurX Benchmark Report               ║\n"
    s = s + "╠════════════════════════════════════════╣\n"
    s = s + "║ MMLU:        " + be_pct(r.mmlu_acc) + "\n"
    s = s + "║ HellaSwag:   " + be_pct(r.hellaswag_acc) + "\n"
    s = s + "║ ARC:         " + be_pct(r.arc_acc) + "\n"
    s = s + "║ WinoGrande:  " + be_pct(r.winogrande_acc) + "\n"
    s = s + "║ GSM8K (EM):  " + be_pct(r.gsm8k_em) + "\n"
    s = s + "║ HumanEval:   " + be_pct(r.humaneval_em) + "\n"
    s = s + "║ English text(English text):  " + be_pct(r.average_score) + "\n"
    s = s + "╚════════════════════════════════════════╝\n"
    s
}

