package neurx.data

// ============================================================================
// Dataset Abstraction - Base class for all data sources
// Supports: text files, tokenized data, custom datasets
// ============================================================================

// ---- Data Sample ----
struct sample {
    []int token_ids      // Token IDs (the main data)
    string text          // Original text (optional)
    int label            // Label for classification tasks (-1 if N/A)
    float weight         // Sample weight (1.0 default)
    map[string]any metadata  // Additional metadata
}

// ---- Dataset Interface ----
struct dataset_config {
    string name
    string path              // File or directory path
    int max_samples          // Max samples to load (-1 for all)
    int max_length           // Max sequence length for truncation
    bool include_text        // Whether to store original text
    string format            // "text", "json", "bin", "memory_map", "custom"
}

struct dataset_stats {
    int total_samples
    int total_tokens
    float avg_length
    int min_length
    int max_length
    []int length_distribution  // Histogram of sequence lengths
}

// Abstract dataset base
struct dataset {
    dataset_config config
    dataset_stats stats
    []sample samples
    bool is_loaded
}

// Create new empty dataset
func new_dataset(dataset_config cfg) dataset {
    dataset {
        config: cfg,
        stats: dataset_stats { total_samples: 0, total_tokens: 0, avg_length: 0 },
        samples: [],
        is_loaded: false,
    }
}

// Load dataset from configured source
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

// Get sample by index (with bounds checking)
func get_sample(dataset ds, int idx) (sample, error) {
    if !ds.is_loaded || idx < 0 || idx >= len(ds.samples) {
        return sample{}, error{message: "Invalid index or dataset not loaded"}
    }
    
    (ds.samples[idx], nil)
}

// Get number of samples
func len_dataset(dataset ds) int {
    if ds.is_loaded {
        return len(ds.samples)
    }
    0
}
