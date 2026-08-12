package neurx.posttrain.data.medical_data_loader
use neurx.posttrain.model.model_loader.{fill_model_tensor}

struct medical_sample {
    string question
    string answer
    []string options
    int correct_option
    string subject
    string explanation
}

struct medical_dataset {
    []medical_sample train_samples
    []medical_sample eval_samples
    int vocab_size
    int max_seq_len
    int total_samples
}

struct tokenized_sample {
    []int input_ids
    []int target_ids
    int seq_len
}

func parse_medical_sample_json(string json_line) medical_sample {
    medical_sample sample
    sample.question = ""
    sample.answer = ""
    sample.options = []string{}
    sample.correct_option = 0
    sample.subject = ""
    sample.explanation = ""
    return sample
}

func load_medical_dataset_from_json(string file_path, int max_samples) medical_dataset {
    medical_dataset dataset
    dataset.vocab_size = 151936
    dataset.max_seq_len = 512
    dataset.train_samples = []medical_sample{}
    dataset.eval_samples = []medical_sample{}
    dataset.total_samples = 0
    return dataset
}

func tokenize_text(string text, int vocab_size) []int {
    []int token_ids = []int{}
    int i = 0
    while i < len(text) && len(token_ids) < 512 {
        string ch = substring(text, i, i + 1)
        int token_id = 1000 + ((i as int) % vocab_size)
        token_ids.push(token_id)
        i = i + 1
    }
    return token_ids
}

func create_batch_from_samples([]medical_sample samples, int batch_size, int seq_len, int vocab_size) [][]int {
    [][]int batches = [][]int{}
    int batch_count = 0
    []int current_batch = []int{}
    int sample_idx = 0
    while sample_idx < len(samples) {
        []int input_ids = tokenize_text(samples[sample_idx].question + " " + samples[sample_idx].answer, vocab_size)
        int pos = 0
        while pos < len(input_ids) && len(current_batch) < batch_size * seq_len {
            current_batch.push(input_ids[pos])
            pos = pos + 1
        }
        if len(current_batch) >= batch_size * seq_len {
            batches.push(current_batch)
            current_batch = []int{}
            batch_count = batch_count + 1
        }
        sample_idx = sample_idx + 1
    }
    if len(current_batch) > 0 {
        batches.push(current_batch)
    }
    return batches
}

