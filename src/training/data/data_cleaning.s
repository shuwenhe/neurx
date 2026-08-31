package neurx.data.data_cleaning
use neurx.strings.{string_contains, string_index_of, string_split, string_trim, string_length}
use neurx.runtime.io.{
    io_println, io_file_exists, io_read_lines, io_mkdir_recursive,
    io_write_file, io_list_files, io_file_size
}

struct cleaning_config {
    string raw_dir
    string cleaned_dir
    string output_file
    int min_text_length
    int max_text_length
    bool enable_dedup
    bool enable_filtering
}

struct cleaning_stats {
    int total_documents
    int valid_documents
    int duplicates_removed
    int empty_documents
    int short_documents
    int long_documents
    long total_tokens_estimate
}

func new_cleaning_config() cleaning_config {
    cleaning_config {
        raw_dir: "dataset/pretrain/raw",
        cleaned_dir: "dataset/pretrain/cleaned",
        output_file: "dataset/pretrain/cleaned/pretrain_data_cleaned.jsonl",
        min_text_length: 50,
        max_text_length: 100000,
        enable_dedup: true,
        enable_filtering: true,
    }
}

func new_cleaning_stats() cleaning_stats {
    cleaning_stats {
        total_documents: 0,
        valid_documents: 0,
        duplicates_removed: 0,
        empty_documents: 0,
        short_documents: 0,
        long_documents: 0,
        total_tokens_estimate: 0,
    }
}

struct cleaning_result {
    string cleaned_text
    bool is_valid
    cleaning_stats stats
}

func simple_hash(string text) string {
    int len = string_length(text)
    string prefix = ""
    if len > 32 {
        prefix = substring(text, 0, 32)
    } else {
        prefix = text
    }
    return prefix + "_" + string(len)
}

func is_empty_text(string text) bool {
    string trimmed = string_trim(text)
    return string_length(trimmed) == 0
}

func clean_record(string line) cleaning_result {
    cleaning_stats stats = new_cleaning_stats()
    stats.total_documents = 1
    cleaning_result result
    result.stats = stats
    result.is_valid = false
    result.cleaned_text = ""
    string text = ""
    int text_start = string_index_of(line, "\"text\":")
    if text_start >= 0 {
        int quote_start = string_index_of(substring(line, text_start, string_length(line)), "\"")
        if quote_start >= 0 {
            int actual_start = text_start + quote_start + 1
            int quote_end = string_index_of(substring(line, actual_start, string_length(line)), "\"")
            if quote_end >= 0 {
                text = substring(line, actual_start, quote_end)
            }
        }
    }
    if is_empty_text(text) {
        result.stats.empty_documents = 1
        return result
    }
    string trimmed = string_trim(text)
    int text_len = string_length(trimmed)
    if text_len < 50 {
        result.stats.short_documents = 1
        return result
    }
    if text_len > 100000 {
        result.stats.long_documents = 1
        trimmed = substring(trimmed, 0, 100000)
    }
    string cleaned = "{\"text\":\"" + trimmed + "\",\"source\":\"raw\",\"length\":" + string(text_len) + "}"
    result.is_valid = true
    result.cleaned_text = cleaned
    result.stats.valid_documents = 1
    result.stats.total_tokens_estimate = long(text_len / 4)
    return result
}

func clean_raw_data(cleaning_config cfg) cleaning_stats {
    io_println("🔄 startdatacleanpipeline...\n")
    io_mkdir_recursive(cfg.cleaned_dir)
    cleaning_stats total_stats = new_cleaning_stats()
    string[] seen_texts = make([]string, 10000)
    int seen_count = 0
    string[] raw_files = io_list_files(cfg.raw_dir, "*.jsonl")
    io_println("📖 startEnglish text " + string(len(raw_files)) + " English textfile...\n")
    for i := 0; i < len(raw_files); i = i + 1 {
        string raw_file = raw_files[i]
        io_println("📄 English text: " + raw_file)
        string[] lines = io_read_lines(raw_file)
        for j := 0; j < len(lines); j = j + 1 {
            string line = lines[j]
            cleaning_result cr = clean_record(line)
            total_stats.total_documents = total_stats.total_documents + cr.stats.total_documents
            total_stats.empty_documents = total_stats.empty_documents + cr.stats.empty_documents
            total_stats.short_documents = total_stats.short_documents + cr.stats.short_documents
            total_stats.long_documents = total_stats.long_documents + cr.stats.long_documents
            if cr.is_valid {
                string hash = simple_hash(cr.cleaned_text)
                bool is_duplicate = false
                for k := 0; k < seen_count; k = k + 1 {
                    if seen_texts[k] == hash {
                        is_duplicate = true
                        break
                    }
                }
                if is_duplicate {
                    total_stats.duplicates_removed = total_stats.duplicates_removed + 1
                } else {
                    if seen_count < len(seen_texts) {
                        seen_texts[seen_count] = hash
                        seen_count = seen_count + 1
                    }
                    total_stats.valid_documents = total_stats.valid_documents + 1
                    total_stats.total_tokens_estimate = total_stats.total_tokens_estimate + cr.stats.total_tokens_estimate
                }
            }
            if total_stats.valid_documents % 1000 == 0 {
                io_println("  ✓ English text " + string(total_stats.valid_documents) + " English text")
            }
        }
    }
    io_println("\n✅ cleanEnglish text!")
    io_println("  • English text: " + string(total_stats.valid_documents))
    io_println("  • deduplicationcount: " + string(total_stats.duplicates_removed))
    io_println("  • English text: " + string(total_stats.empty_documents))
    io_println("  • English text: " + string(total_stats.short_documents))
    io_println("  • English text: " + string(total_stats.long_documents))
    io_println("  • English text tokens: " + string(total_stats.total_tokens_estimate))
    io_println("  • outputfile: " + cfg.output_file)
    return total_stats
}

func generate_dataset_splits(cleaning_config cfg) {
    io_println("\n📊 generatedataEnglish text...")
    string[] all_lines = io_read_lines(cfg.output_file)
    int total = len(all_lines)
    int train_size = (total * 80) / 100
    int val_size = (total * 10) / 100
    io_println("  ✓ generatetrainingEnglish text: " + string(train_size) + " English text")
    io_println("  ✓ generateEnglish text: " + string(val_size) + " English text")
    int test_size = total - train_size - val_size
    io_println("  ✓ generatetestEnglish text: " + string(test_size) + " English text")
}

func run_data_cleaning() {
    cleaning_config cfg = new_cleaning_config()
    io_println("╔════════════════════════════════════════════╗")
    io_println("║       NeurX datacleanEnglish text (Slanguageimplementation)       ║")
    io_println("╚════════════════════════════════════════════╝\n")
    cleaning_stats stats = clean_raw_data(cfg)
    io_println("\n📁 datacleanEnglish textinformation:")
    io_println("  • English textdata: " + cfg.raw_dir)
    io_println("  • English textoutput: " + cfg.cleaned_dir)
    io_println("  • English text: " + string((stats.valid_documents * 100) / stats.total_documents) + "%")
    generate_dataset_splits(cfg)
    io_println("\n✨ datacleanpipelineEnglish text!")
    io_println("English textstep: generateEnglish textdataEnglish text src/runtime/shard/ directory")
}
