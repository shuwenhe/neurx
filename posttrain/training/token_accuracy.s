
package neurx.posttrain.training.token_accuracy




struct TokenAccuracyStats {
    int correct_tokens
    int total_tokens
    float accuracy
    int exact_matches
    int total_sequences
    float sequence_accuracy
}





func compute_token_accuracy(
    [][][]float logits,
    [][]int targets,
    [][]bool mask
) TokenAccuracyStats {
    TokenAccuracyStats stats = TokenAccuracyStats{}
    stats.correct_tokens = 0
    stats.total_tokens = 0
    stats.exact_matches = 0
    stats.total_sequences = 0

    int batch_size = len(logits)
    if batch_size == 0 {
        return stats
    }


    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        bool sequence_correct = true
        int sequence_tokens = 0


        int t = 0
        while t < seq_len {

            if !mask[b][t] {
                t = t + 1
                continue
            }

            sequence_tokens = sequence_tokens + 1
            stats.total_tokens = stats.total_tokens + 1


            int predicted_token = argmax(logits[b][t])
            int target_token = targets[b][t]


            if predicted_token == target_token {
                stats.correct_tokens = stats.correct_tokens + 1
            } else {
                sequence_correct = false
            }

            t = t + 1
        }


        if sequence_tokens > 0 {
            stats.total_sequences = stats.total_sequences + 1
            if sequence_correct {
                stats.exact_matches = stats.exact_matches + 1
            }
        }

        b = b + 1
    }


    if stats.total_tokens > 0 {
        stats.accuracy = ((stats.correct_tokens as float)) / ((stats.total_tokens as float))
    } else {
        stats.accuracy = 0.0
    }

    if stats.total_sequences > 0 {
        stats.sequence_accuracy = ((stats.exact_matches as float)) / ((stats.total_sequences as float))
    } else {
        stats.sequence_accuracy = 0.0
    }

    return stats
}


func compute_token_accuracy_simple(
    [][][]float logits,
    [][]int targets
) float {
    int correct = 0
    int total = 0

    int batch_size = len(logits)
    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        int t = 0
        while t < seq_len {
            int predicted = argmax(logits[b][t])
            int target = targets[b][t]

            if predicted == target {
                correct = correct + 1
            }
            total = total + 1

            t = t + 1
        }
        b = b + 1
    }

    if total == 0 { return 0.0 }
    return ((correct as float)) / ((total as float))
}



func compute_topk_accuracy(
    [][][]float logits,
    [][]int targets,
    [][]bool mask,
    int k
) float {
    int correct = 0
    int total = 0

    int batch_size = len(logits)
    int b = 0
    while b < batch_size {
        int seq_len = len(logits[b])
        int t = 0
        while t < seq_len {

            if !mask[b][t] {
                t = t + 1
                continue
            }

            total = total + 1


            []int topk_indices = get_topk_indices(logits[b][t], k)
            int target = targets[b][t]


            bool in_topk = false
            int i = 0
            while i < len(topk_indices) {
                if topk_indices[i] == target {
                    in_topk = true
                    break
                }
                i = i + 1
            }

            if in_topk {
                correct = correct + 1
            }

            t = t + 1
        }
        b = b + 1
    }

    if total == 0 { return 0.0 }
    return ((correct as float)) / ((total as float))
}





func argmax([]float vector) int {
    if len(vector) == 0 { return -1 }

    int max_idx = 0
    float max_val = vector[0]

    int i = 1
    while i < len(vector) {
        if vector[i] > max_val {
            max_val = vector[i]
            max_idx = i
        }
        i = i + 1
    }

    return max_idx
}


func get_topk_indices([]float vector, int k) []int {
    int n = len(vector)
    if n == 0 { return []int{} }
    if k > n { k = n }


    []int indices = []int{}
    []float values = []float{}

    int i = 0
    while i < n {
        indices = append(indices, i)
        values = append(values, vector[i])
        i = i + 1
    }


    []int topk = []int{}
    int selected = 0
    while selected < k {

        int max_idx = 0
        float max_val = values[0]

        int j = 1
        while j < len(values) {
            if values[j] > max_val {
                max_val = values[j]
                max_idx = j
            }
            j = j + 1
        }


        topk = append(topk, indices[max_idx])


        values[max_idx] = -1e38

        selected = selected + 1
    }

    return topk
}


func print_token_accuracy_stats(TokenAccuracyStats stats) {
    println("[Token Accuracy]")
    print("  Correct Tokens:  ")
    print(int_to_str(stats.correct_tokens))
    print(" / ")
    println(int_to_str(stats.total_tokens))
    print("  Token Accuracy:  ")
    println(float_to_str_4(stats.accuracy * 100.0) + "%")
    print("  Exact Matches:   ")
    print(int_to_str(stats.exact_matches))
    print(" / ")
    println(int_to_str(stats.total_sequences))
    print("  Seq Accuracy:    ")
    println(float_to_str_4(stats.sequence_accuracy * 100.0) + "%")
}




func int_to_str(int n) string {
    if n == 0 { return "0" }
    int value = n
    bool negative = false
    if value < 0 {
        negative = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        if digit == 0 { out = "0" + out }
        else if digit == 1 { out = "1" + out }
        else if digit == 2 { out = "2" + out }
        else if digit == 3 { out = "3" + out }
        else if digit == 4 { out = "4" + out }
        else if digit == 5 { out = "5" + out }
        else if digit == 6 { out = "6" + out }
        else if digit == 7 { out = "7" + out }
        else if digit == 8 { out = "8" + out }
        else { out = "9" + out }
        value = value / 10
    }
    if negative { out = "-" + out }
    return out
}

func float_to_str_4(float value) string {
    float current = value
    bool negative = current < 0.0
    if negative { current = 0.0 - current }

    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }

    string result = int_to_str(whole) + "."

    int i = 0
    while i < 4 {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        result = result + int_to_str(digit)
        i = i + 1
    }

    if negative { result = "-" + result }
    return result
}
