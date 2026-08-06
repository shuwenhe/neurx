package neurx.inference.sampling

struct sampling_config {
    string strategy
    float temperature
    int top_k
    float top_p
    int num_beams
    float length_penalty
    bool early_stopping
    float repetition_penalty
    int no_repeat_ngram_size
    float min_length_penalty
    int min_length
    int max_length
    float epsilon_cutoff
    float eta_cutoff
    bool do_sample
    uint64 seed
}

struct generation_state {
    []int input_ids
    [][]float scores
    [][]float probabilities
    []int generated_ids
    int current_step
    bool is_finished
    []beam_state beams
}

struct beam_state {
    []int token_ids
    float score
    bool is_finished
}

func default_sampling_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 1.0,
        top_k: 50,
        top_p: 0.9,
        num_beams: 5,
        length_penalty: 1.0,
        early_stopping: true,
        repetition_penalty: 1.0,
        no_repeat_ngram_size: 0,
        min_length_penalty: 0.0,
        min_length: 0,
        max_length: 512,
        epsilon_cutoff: 0.0,
        eta_cutoff: 0.0,
        do_sample: true,
        seed: 42,
    }
}

func greedy_config() sampling_config {
    sampling_config {
        strategy: "greedy",
        temperature: 1.0,
        top_k: 0,
        top_p: 0.0,
        num_beams: 1,
        do_sample: false,
        max_length: 512,
    }
}

func creative_config() sampling_config {
    sampling_config {
        strategy: "top_p",
        temperature: 0.9,
        top_k: 40,
        top_p: 0.92,
        repetition_penalty: 1.15,
        max_length: 1024,
        do_sample: true,
    }
}

