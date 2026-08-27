package neurx.eval.mmlu_evaluator
use neurx.eval.mmlu_data
use neurx.eval.benchmark_eval
use neurx.model.llm.gpt
use std.io.println

struct mmlu_fewshot_prompt {
    []mmlu_data.mmlu_question examples
    mmlu_data.mmlu_question test_q
}

struct mmlu_eval_config {
    int num_shots
    bool normalize_by_length
    int max_seq_len
    string data_root
    string model_type
}

func default_mmlu_eval_config() mmlu_eval_config {
    mmlu_eval_config {
        num_shots: 5,
        normalize_by_length: true,
        max_seq_len: 4096,
        data_root: "./data/mmlu",
        model_type: "base-model",
    }
}

func format_mmlu_question(mmlu_data.mmlu_question q, bool include_answer) string {
    string prompt = "Question: " + q.question + "\n"
    prompt = prompt + "A) " + q.choice_a + "\n"
    prompt = prompt + "B) " + q.choice_b + "\n"
    prompt = prompt + "C) " + q.choice_c + "\n"
    prompt = prompt + "D) " + q.choice_d + "\n"
    if include_answer {
        prompt = prompt + "Answer: " + q.correct_answer + "\n"
    }
    prompt
}

func build_mmlu_fewshot_prompt(
    []mmlu_data.mmlu_question examples,
    mmlu_data.mmlu_question test_q
) string {
    string prompt = ""
    int i = 0
    for i < len(examples) {
        prompt = prompt + format_mmlu_question(examples[i], true)
        prompt = prompt + "\n"
        i = i + 1
    }
    prompt = prompt + format_mmlu_question(test_q, false)
    prompt = prompt + "Answer: "
    prompt
}

func mmlu_get_choice_tokens(string choice, bool for_answer) int[] {
    int[] tokens = int[]{}
    if choice == "A" {
        tokens = append(tokens, 362)
    } else if choice == "B" {
        tokens = append(tokens, 350)
    } else if choice == "C" {
        tokens = append(tokens, 315)
    } else if choice == "D" {
        tokens = append(tokens, 360)
    }
    if for_answer {
    }
    tokens
}

struct mmlu_task_result {
    string task_name
    int total
    int correct
    float accuracy
}

struct mmlu_eval_result {
    float overall_accuracy
    []mmlu_task_result task_results
    int total_questions
    int total_correct
    string timestamp
}

func evaluate_mmlu_task(
    gpt.language_model model,
    string task_name,
    []mmlu_data.mmlu_question test_questions,
    []mmlu_data.mmlu_question dev_examples,
    mmlu_eval_config cfg
) mmlu_task_result {
    int total = 0
    int correct = 0
    int q_idx = 0
    for q_idx < len(test_questions) {
        mmlu_data.mmlu_question test_q = test_questions[q_idx]
        string prompt = build_mmlu_fewshot_prompt(dev_examples, test_q)
        int[] prompt_tokens = tokenize_prompt(prompt)
        float best_score = -1000000000.0
        string best_choice = "A"
        string choice = "A"
        int choice_idx = 0
        for choice_idx < 4 {
            int[] choice_tokens = mmlu_get_choice_tokens(choice, true)
            int[] full_seq = concat_token_sequences(prompt_tokens, choice_tokens)
            benchmark_eval.logprob_result lp = benchmark_eval.gpt_sequence_logprob(
                model,
                full_seq,
                len(prompt_tokens)
            )
            float score = lp.avg_logprob
            if score > best_score {
                best_score = score
                best_choice = choice
            }
            if choice == "A" {
                choice = "B"
            } else if choice == "B" {
                choice = "C"
            } else if choice == "C" {
                choice = "D"
            }
            choice_idx = choice_idx + 1
        }
        if best_choice == test_q.correct_answer {
            correct = correct + 1
        }
        total = total + 1
        q_idx = q_idx + 1
    }
    float accuracy = 0.0
    if total > 0 {
        accuracy = (correct * 1.0) / (total * 1.0)
    }
    mmlu_task_result {
        task_name: task_name,
        total: total,
        correct: correct,
        accuracy: accuracy,
    }
}

func evaluate_mmlu_benchmark(
    gpt.language_model model,
    mmlu_data.mmlu_dataset_state dataset,
    mmlu_eval_config cfg
) mmlu_eval_result {
    println("========================================")
    println("MMLU 5-Shot Benchmark Evaluation")
    println("========================================")
    println("model: " + cfg.model_type)
    println("Shots: " + int_to_str(cfg.num_shots))
    println("Seq length: " + int_to_str(cfg.max_seq_len))
    println("")
    []mmlu_task_result results = []mmlu_task_result{}
    int total_questions = 0
    int total_correct = 0
    []mmlu_data.mmlu_task tasks = mmlu_data.mmlu_task_list()
    int task_idx = 0
    for task_idx < len(tasks) {
        mmlu_data.mmlu_task t = tasks[task_idx]
        if t.is_included {
            []mmlu_data.mmlu_question dev = dataset.dev_by_task[t.name]
            []mmlu_data.mmlu_question test = dataset.questions_by_task[t.name]
            if len(test) > 0 {
                println("[Eval] " + t.name + " (" + t.category + ")...")
                mmlu_task_result tr = evaluate_mmlu_task(
                    model,
                    t.name,
                    test,
                    dev,
                    cfg
                )
                results = append(results, tr)
                total_questions = total_questions + tr.total
                total_correct = total_correct + tr.correct
                float acc_pct = tr.accuracy * 100.0
                println("  ✓ " + t.name + ": " + fmt_float(acc_pct, 1) + "% (" + int_to_str(tr.correct) + "/" + int_to_str(tr.total) + ")")
            }
        }
        task_idx = task_idx + 1
    }
    float overall_acc = 0.0
    if total_questions > 0 {
        overall_acc = (total_correct * 1.0) / (total_questions * 1.0)
    }
    println("")
    println("========================================")
    println("MMLU Results")
    println("========================================")
    println("Overall Accuracy: " + fmt_float(overall_acc * 100.0, 2) + "%")
    println("Total: " + int_to_str(total_correct) + "/" + int_to_str(total_questions) + " correct")
    println("")
    float stem_acc = 0.0; int stem_total = 0; int stem_correct = 0
    float social_acc = 0.0; int social_total = 0; int social_correct = 0
    float humanities_acc = 0.0; int humanities_total = 0; int humanities_correct = 0
    float other_acc = 0.0; int other_total = 0; int other_correct = 0
    int r_idx = 0
    for r_idx < len(results) {
        mmlu_task_result r = results[r_idx]
        int t_idx = 0
        string category = "Other"
        for t_idx < len(tasks) {
            if tasks[t_idx].name == r.task_name {
                category = tasks[t_idx].category
                break
            }
            t_idx = t_idx + 1
        }
        if category == "STEM" {
            stem_total = stem_total + r.total
            stem_correct = stem_correct + r.correct
        } else if category == "Social Science" {
            social_total = social_total + r.total
            social_correct = social_correct + r.correct
        } else if category == "Humanities" {
            humanities_total = humanities_total + r.total
            humanities_correct = humanities_correct + r.correct
        } else {
            other_total = other_total + r.total
            other_correct = other_correct + r.correct
        }
        r_idx = r_idx + 1
    }
    if stem_total > 0 {
        stem_acc = (stem_correct * 1.0) / (stem_total * 1.0)
        println("STEM:          " + fmt_float(stem_acc * 100.0, 2) + "% (" + int_to_str(stem_correct) + "/" + int_to_str(stem_total) + ")")
    }
    if social_total > 0 {
        social_acc = (social_correct * 1.0) / (social_total * 1.0)
        println("Social Science: " + fmt_float(social_acc * 100.0, 2) + "% (" + int_to_str(social_correct) + "/" + int_to_str(social_total) + ")")
    }
    if humanities_total > 0 {
        humanities_acc = (humanities_correct * 1.0) / (humanities_total * 1.0)
        println("Humanities:    " + fmt_float(humanities_acc * 100.0, 2) + "% (" + int_to_str(humanities_correct) + "/" + int_to_str(humanities_total) + ")")
    }
    if other_total > 0 {
        other_acc = (other_correct * 1.0) / (other_total * 1.0)
        println("Other:         " + fmt_float(other_acc * 100.0, 2) + "% (" + int_to_str(other_correct) + "/" + int_to_str(other_total) + ")")
    }
    println("")
    mmlu_eval_result {
        overall_accuracy: overall_acc,
        task_results: results,
        total_questions: total_questions,
        total_correct: total_correct,
        timestamp: "2026-07-20",
    }
}

func tokenize_prompt(string prompt) int[] {
    int[] tokens = int[]{}
    int i = 0
    for i < len(prompt) && i < 4096 {
        tokens = append(tokens, i)
        i = i + 1
    }
    tokens
}

func concat_token_sequences(int[] a, int[] b) int[] {
    int[] result = int[]{}
    int i = 0
    for i < len(a) {
        result = append(result, a[i])
        i = i + 1
    }
    i = 0
    for i < len(b) {
        result = append(result, b[i])
        i = i + 1
    }
    result
}

func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    for value > 0 {
        int digit = value % 10
        out = digit_to_str(digit) + out
        value = value / 10
    }
    if neg { out = "-" + out }
    out
}

func digit_to_str(int digit) string {
    if digit == 0 { return "0" }
    if digit == 1 { return "1" }
    if digit == 2 { return "2" }
    if digit == 3 { return "3" }
    if digit == 4 { return "4" }
    if digit == 5 { return "5" }
    if digit == 6 { return "6" }
    if digit == 7 { return "7" }
    if digit == 8 { return "8" }
    "9"
}

func fmt_float(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg { current = 0.0 - current }
    int whole = 0
    for current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg { out = "-" }
    out = out + int_to_str(whole) + "."
    int i = 0
    for i < decimals {
        current = current * 10.0
        int digit = 0
        for current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        out = out + digit_to_str(digit)
        i = i + 1
    }
    out
}
