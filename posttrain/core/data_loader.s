package neurx.posttrain.core.data_loader
use std.io.println
struct training_example_s {
    string instruction
    string input
    string output
    string category
    int question_id
}

struct tokenized_example_s {
    []int input_ids
    []int attention_mask
    []int labels
    int seq_len
    int token_count
}

struct data_batch_s {
    [][]int input_ids_batch
    [][]int attention_mask_batch
    [][]int labels_batch
    int batch_size
    int max_seq_len
    int total_tokens
}
func parse_json_line(string line) training_example_s {
    training_example_s {
        instruction: "",
        input: "",
        output: "",
        category: "",
        question_id: 0,
    }
}

func load_medical_examples_s(string jsonl_path, int max_examples) []training_example_s {
    []training_example_s examples
    examples
}

func tokenize_example_s(training_example_s ex, []int vocab_map) tokenized_example_s {
    []int input_ids
    []int attention_mask
    []int labels
    tokenized_example_s {
        input_ids: input_ids,
        attention_mask: attention_mask,
        labels: labels,
        seq_len: 0,
        token_count: 0,
    }
}

func create_batch_s([]tokenized_example_s examples, int batch_size, int max_seq_len) data_batch_s {
    [][]int input_ids_batch
    [][]int attention_mask_batch
    [][]int labels_batch
    data_batch_s {
        input_ids_batch: input_ids_batch,
        attention_mask_batch: attention_mask_batch,
        labels_batch: labels_batch,
        batch_size: batch_size,
        max_seq_len: max_seq_len,
        total_tokens: 0,
    }
}

func pad_sequence_s([]int seq, int target_len, int pad_token) []int {
    []int result
    int i = 0
    while i < len(seq) {
        if i < target_len {
            result = append(result, seq[i])
        }
        i = i + 1
    }
    while len(result) < target_len {
        result = append(result, pad_token)
    }
    result
}
