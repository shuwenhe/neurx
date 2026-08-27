package neurx.data

struct sample {
    int[] token_ids
    string text
    int label
    float weight
    map[string]any metadata
}

struct dataset_config {
    string name
    string path
    int max_samples
    int max_length
    bool include_text
    string format
}

struct dataset_stats {
    int total_samples
    int total_tokens
    float avg_length
    int min_length
    int max_length
    int[] length_distribution
}

struct dataset {
    dataset_config config
    dataset_stats stats
    []sample samples
    bool is_loaded
}

func new_dataset(dataset_config cfg) dataset {
    dataset {
        config: cfg,
        stats: dataset_stats { total_samples: 0, total_tokens: 0, avg_length: 0 },
        samples: [],
        is_loaded: false,
    }
}

func load_dataset(dataset ds) (dataset, error) {
    switch ds.config.format {
        case "text":
            load_text_dataset(ds)
        case "json":
            load_json_dataset(ds)
        case "bin":
            load_binary_dataset(ds)
        case "memory_map":
            load_memory_mapped_dataset(ds)
        default:
            (ds, error{message: "Unknown dataset format: " + ds.config.format})
    }
}

func get_sample(dataset ds, int idx) (sample, error) {
    if !ds.is_loaded || idx < 0 || idx >= len(ds.samples) {
        return sample{}, error{message: "Invalid index or dataset not loaded"}
    }
    (ds.samples[idx], nil)
}

func len_dataset(dataset ds) int {
    if ds.is_loaded {
        return len(ds.samples)
    }
    0
}
