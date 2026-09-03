package main
import (
    "fmt"
    "os"
    "io/ioutil"
    "path/filepath"
    "strings"
    "bufio"
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "sort"
)

struct clean_config {
    raw_dir         string
    cleaned_dir     string
    output_file     string
    manifest_file   string
    checkpoint_file string
}

struct shard_config {
    input_file      string
    shard_dir       string
    manifest_file   string
    max_shards      int
    lines_per_shard  int
}

struct shard_metadata {
    shard_id       string `json:"shard_id"`
    file_path      string `json:"file_path"`
    num_documents  int64  `json:"num_documents"`
    size_bytes     int64  `json:"size_bytes"`
}

struct manifest {
    dataset_name         string           `json:"dataset_name"`
    version             string           `json:"version"`
    created_at           string           `json:"created_at"`
    total_shards         int64            `json:"total_shards"`
    total_documents      int64            `json:"total_documents"`
    total_size_bytes      int64            `json:"total_size_bytes"`
    average_docs_per_shard int64            `json:"average_docs_per_shard"`
    shards              []shard_metadata  `json:"shards"`
}

func main() {
    if len(os.Args) < 2 {
        print_help()
        os.Exit(0)
    }
    command := os.Args[1]
    switch command {
    case "clean":
        cmdClean()
    case "shard":
        cmdShard()
    case "pipeline":
        cmdPipeline()
    case "help":
        printHelp()
    default:
        fmt.Printf("✗ Unknown command: %s\n", command)
        fmt.Println("Use 'help' for usage information")
        os.Exit(1)
    }
}

func cmd_clean() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║     NeurX Data Cleaning (S Language)      ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    config := get_clean_config()
    if err := ensure_dir(config.CleanedDir); err != nil {
        fmt.Printf("✗ Failed to create directory: %v\n", err)
        os.Exit(1)
    }
    fmt.Printf("📂 Configuration:\n")
    fmt.Printf("  • Raw data: %s\n", config.RawDir)
    fmt.Printf("  • Output: %s\n", config.OutputFile)
    fmt.Printf("  • manifest: %s\n", config.ManifestFile)
    fmt.Println("")
    if err := clean_data(config); err != nil {
        fmt.Printf("✗ Cleaning failed: %v\n", err)
        os.Exit(1)
    }
    fmt.Println("")
    fmt.Println("✓ Data cleaning completed successfully")
}

func cmd_shard() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║    NeurX Data Sharding (S Language)       ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    config := get_shard_config()
    if err := ensure_dir(config.ShardDir); err != nil {
        fmt.Printf("✗ Failed to create directory: %v\n", err)
        os.Exit(1)
    }
    if err := generate_shards(config); err != nil {
        fmt.Printf("✗ Sharding failed: %v\n", err)
        os.Exit(1)
    }
    fmt.Println("")
    fmt.Println("✓ Data sharding completed successfully")
}

func cmd_pipeline() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║   NeurX Full Pipeline (Clean + Shard)     ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    fmt.Println("Step 1/2: Cleaning data...")
    cmd_clean()
    fmt.Println("")
    fmt.Println("Step 2/2: Generating shards...")
    cmd_shard()
}

func get_clean_config() clean_config {
    home := get_env("NEURX_HOME", ".")
    return clean_config{
        raw_dir:         getEnv("RAW_DIR", filepath.Join(home, "dataset", "pretrain", "raw")),
        cleaned_dir:     getEnv("CLEANED_DIR", filepath.Join(home, "dataset", "pretrain", "cleaned")),
        output_file:     getEnv("OUTPUT_FILE", filepath.Join(home, "dataset", "pretrain", "cleaned", "pretrain_data_cleaned.jsonl")),
        manifest_file:   getEnv("MANIFEST_FILE", filepath.Join(home, "dataset", "pretrain", "manifest.json")),
        checkpoint_file: getEnv("CHECKPOINT_FILE", filepath.Join(home, "dataset", "pretrain", "cleaned", ".cleaning_checkpoint.json")),
    }
}

func get_shard_config() shard_config {
    home := get_env("NEURX_HOME", ".")
    dataset_root := get_env("DATASET_ROOT", filepath.Join(home, "dataset", "pretrain"))
    return shard_config{
        input_file:     getEnv("INPUT_FILE", filepath.Join(dataset_root, "cleaned", "train.jsonl")),
        shard_dir:      getEnv("SHARD_DIR", filepath.Join(dataset_root, "shard")),
        manifest_file:  getEnv("MANIFEST_FILE", filepath.Join(dataset_root, "manifest.json")),
        max_shards:     getEnvInt("MAX_SHARDS", 128),
        lines_per_shard: getEnvInt("LINES_PER_SHARD", 100),
    }
}

func clean_data(config clean_config) error {
    files, err := find_source_files(config.RawDir)
    if err != nil {
        return err
    }
    if len(files) == 0 {
        fmt.Println("⚠ No raw data files found")
        return write_empty_manifest(config)
    }
    fmt.Printf("📚 Found %d source files\n", len(files))
    fmt.Println("")
    seen_hashes := make(map[string]bool)
    stats := *clean_stats{
        total_processed: 0,
        total_written:   0,
        duplicates:     0,
        errors:         0,
    }
    output_handle, err := os.Create(config.OutputFile)
    if err != nil {
        return err
    }
    defer output_handle.Close()
    writer := bufio.NewWriter(output_handle)
    for _, file := range files {
        fmt.Printf("  Processing: %s\n", filepath.Base(file))
        content, err := ioutil.ReadFile(file)
        if err != nil {
            fmt.Printf("  ⚠ Failed to read: %v\n", err)
            stats.Errors++
            continue
        }
        process_file_content(writer, string(content), seen_hashes, stats)
    }
    writer.Flush()
    fmt.Println("")
    fmt.Printf("✓ Processing completed\n")
    fmt.Printf("📊 Statistics:\n")
    fmt.Printf("  • Total processed: %d\n", stats.TotalProcessed)
    fmt.Printf("  • Successfully written: %d\n", stats.TotalWritten)
    fmt.Printf("  • Duplicates skipped: %d\n", stats.Duplicates)
    fmt.Printf("  • Errors: %d\n", stats.Errors)
    fmt.Println("")
    if err := generate_splits(config); err != nil {
        return err
    }
    return write_manifest(config, stats.TotalWritten)
}

struct clean_stats {
    total_processed int64
    total_written   int64
    duplicates     int64
    errors         int64
}

func process_file_content(writer *bufio.Writer, string content, seen map[string]bool, stats *clean_stats) {
    lines := strings.Split(content, "\n")
    for _, line := range lines {
        line = strings.TrimSpace(line)
        if line == "" {
            continue
        }
        stats.TotalProcessed++
        text := extract_text(line)
        if text == "" {
            continue
        }
        hash := hash_key(normalize_text(text))
        if seen[hash] {
            stats.Duplicates++
            continue
        }
        seen[hash] = true
        record := create_record(text)
        writer.WriteString(record + "\n")
        stats.TotalWritten++
    }
}

func generate_splits(config clean_config) error {
    content, err := ioutil.ReadFile(config.OutputFile)
    if err != nil {
        return err
    }
    lines := strings.Split(string(content), "\n")
    total := int64(len(lines))
    train_size := total * 8 / 10
    val_size := total / 10
    test_size := total - train_size - val_size
    train_file := filepath.Join(config.CleanedDir, "train.jsonl")
    val_file := filepath.Join(config.CleanedDir, "val.jsonl")
    test_file := filepath.Join(config.CleanedDir, "test.jsonl")
    train_handle, _ := os.Create(train_file)
    val_handle, _ := os.Create(val_file)
    test_handle, _ := os.Create(test_file)
    defer train_handle.Close()
    defer val_handle.Close()
    defer test_handle.Close()
    for i, line := range lines {
        if line == "" {
            continue
        }
        idx := int64(i)
        if idx < train_size {
            train_handle.WriteString(line + "\n")
        } else if idx < train_size+val_size {
            val_handle.WriteString(line + "\n")
        } else {
            test_handle.WriteString(line + "\n")
        }
    }
    fmt.Printf("✓ Dataset splits created (train: %.1f%%, val: %.1f%%, test: %.1f%%)\n",
        float64(train_size)*100/float64(total),
        float64(val_size)*100/float64(total),
        float64(test_size)*100/float64(total))
    return nil
}

func generate_shards(config shard_config) error {
    info, err := os.Stat(config.InputFile)
    if err != nil {
        return fmt.Errorf("input file not found: %s", config.InputFile)
    }
    fmt.Printf("📋 Input file analysis:\n")
    fmt.Printf("  • Path: %s\n", config.InputFile)
    fmt.Printf("  • Size: %.2f MB\n", float64(info.Size())/1e6)
    content, err := ioutil.ReadFile(config.InputFile)
    if err != nil {
        return err
    }
    lines := strings.Split(string(content), "\n")
    total_lines := int64(0)
    for _, line := range lines {
        if strings.TrimSpace(line) != "" {
            total_lines++
        }
    }
    fmt.Printf("  • Total lines: %d\n", total_lines)
    fmt.Println("")
    if total_lines == 0 {
        fmt.Println("⚠ No documents found in input file")
        return write_empty_manifest(clean_config{manifest_file: config.ManifestFile})
    }
    ideal_shards := (total_lines + int64(config.LinesPerShard) - 1) / int64(config.LinesPerShard)
    actual_shards := ideal_shards
    if actual_shards > int64(config.MaxShards) {
        actual_shards = int64(config.MaxShards)
    }
    lines_per_shard := (total_lines + actual_shards - 1) / actualShards
    fmt.Printf("📊 Shard calculation:\n")
    fmt.Printf("  • Ideal shards: %d\n", ideal_shards)
    fmt.Printf("  • Actual shards: %d\n", actual_shards)
    fmt.Printf("  • Lines per shard: %d\n", lines_per_shard)
    fmt.Println("")
    fmt.Println("✂️ Generating shards...")
    var shards []shard_metadata
    current_shard := 0
    current_data := ""
    current_count := int64(0)
    for _, line := range lines {
        line = strings.TrimSpace(line)
        if line == "" {
            continue
        }
        current_data += line + "\n"
        current_count++
        if current_count >= lines_per_shard {
            shard_file := format_shard_filename(config.ShardDir, current_shard)
            size, err := write_shard_file(shard_file, current_data)
            if err != nil {
                return err
            }
            shards = append(shards, shard_metadata{
                shard_id:       formatShardID(current_shard),
                file_path:      shardFile,
                num_documents:  currentCount,
                size_bytes:     size,
            })
            current_data = ""
            current_count = 0
            current_shard++
        }
    }
    if current_count > 0 {
        shard_file := format_shard_filename(config.ShardDir, current_shard)
        size, err := write_shard_file(shard_file, current_data)
        if err != nil {
            return err
        }
        shards = append(shards, shard_metadata{
            shard_id:       formatShardID(current_shard),
            file_path:      shardFile,
            num_documents:  currentCount,
            size_bytes:     size,
        })
    }
    fmt.Printf("✓ Generated %d shards\n", len(shards))
    fmt.Println("")
    return write_shard_manifest(config.ManifestFile, shards)
}

func write_shard_file(string path, string content) (int64, error) {
    err := ioutil.WriteFile(path, []byte(content), 0644)
    if err != nil {
        return 0, err
    }
    info, err := os.Stat(path)
    if err != nil {
        return 0, err
    }
    return info.Size(), nil
}

func find_source_files(string dir) ([]string, error) {
    var files []string
    entries, err := ioutil.ReadDir(dir)
    if err != nil {
        return files, err
    }
    for _, entry := range entries {
        if entry.IsDir() {
            continue
        }
        name := strings.ToLower(entry.Name())
        if strings.HasSuffix(name, ".jsonl") ||
           strings.HasSuffix(name, ".txt") ||
           strings.HasSuffix(name, ".xml") ||
           strings.HasSuffix(name, ".xml.bz2") {
            files = append(files, filepath.Join(dir, entry.Name()))
        }
    }
    sort.Strings(files)
    return files, nil
}

func extract_text(string line) string {
    if !strings.Contains(line, "\"text\"") {
        return ""
    }
    idx := strings.Index(line, "\"text\"")
    if idx < 0 {
        return ""
    }
    rest := line[idx+6:]
    idx = strings.Index(rest, "\"")
    if idx < 0 {
        return ""
    }
    rest = rest[idx+1:]
    end_idx := strings.Index(rest, "\"")
    if end_idx < 0 {
        return ""
    }
    return rest[:endIdx]
}

func normalize_text(string text) string {
    text = strings.TrimSpace(text)
    text = strings.ToLower(text)
    parts := strings.Fields(text)
    return strings.Join(parts, " ")
}

func hash_key(string text) string {
    h := sha256.New()
    h.Write([]byte(text))
    return hex.EncodeToString(h.Sum(nil))
}

func create_record(string text) string {
    tokens := len(text) / 4
    if tokens < 1 {
        tokens = 1
    }
    record := map[string]interface{}{
        "text":   text,
        "tokens": tokens,
    }
    data, _ := json.Marshal(record)
    return string(data)
}

func format_shard_id(int index) string {
    return fmt.Sprintf("shard_%05d", index)
}

func format_shard_filename(string dir, int index) string {
    return filepath.Join(dir, format_shard_id(index)+".jsonl")
}

func write_shard_manifest(string path, shards []shard_metadata) error {
    total_docs := int64()
    total_size := int64()
    for _, shard := range shards {
        total_docs += shard.NumDocuments
        total_size += shard.SizeBytes
    }
    avg_docs := int64(0)
    if len(shards) > 0 {
        avg_docs = total_docs / int64(len(shards))
    }
    manifest := manifest{
        dataset_name:         "neurx-pretrain-dataset",
        version:             "1.0",
        created_at:           "2026-07-07T00:00:00Z",
        total_shards:         int64(len(shards)),
        total_documents:      totalDocs,
        total_size_bytes:      totalSize,
        average_docs_per_shard: avgDocs,
        shards:              shards,
    }
    data, err := json.MarshalIndent(manifest, "", "  ")
    if err != nil {
        return err
    }
    return ioutil.WriteFile(path, data, 0644)
}

func write_manifest(config clean_config, total_docs int64) error {
    manifest := map[string]interface{}{
        "dataset_name": "neurx-pretrain-dataset",
        "version":      "1.0",
        "status":       "cleaned",
        "total_documents": totalDocs,
        "cleaned_splits": map[string]string{
            "train": "cleaned/train.jsonl",
            "val":   "cleaned/val.jsonl",
            "test":  "cleaned/test.jsonl",
        },
    }
    data, err := json.MarshalIndent(manifest, "", "  ")
    if err != nil {
        return err
    }
    return ioutil.WriteFile(config.ManifestFile, data, 0644)
}

func write_empty_manifest(config clean_config) error {
    manifest := map[string]interface{}{
        "dataset_name": "neurx-pretrain-dataset",
        "version":      "1.0",
        "status":       "empty",
        "total_documents": 0,
    }
    data, _ := json.MarshalIndent(manifest, "", "  ")
    return ioutil.WriteFile(config.ManifestFile, data, 0644)
}

func ensure_dir(string dir) error {
    return os.MkdirAll(dir, 0755)
}

func get_env(key, string default_val) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return default_val
}

func get_env_int(string key, int default_val) int {
    if val := os.Getenv(key); val != "" {
        num := int()
        fmt.Sscanf(val, "%d", *num)
        return num
    }
    return default_val
}

func print_help() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║  NeurX Data Processing Pipeline (S Lang)  ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    fmt.Println("Usage: neurx_data_pipeline <command>")
    fmt.Println("")
    fmt.Println("Commands:")
    fmt.Println("  clean      - Clean raw data files")
    fmt.Println("  shard      - Generate data shards")
    fmt.Println("  pipeline   - Run full pipeline (clean + shard)")
    fmt.Println("  help       - Show this help message")
    fmt.Println("")
    fmt.Println("Environment variables:")
    fmt.Println("  NEURX_HOME         - NeurX home directory")
    fmt.Println("  RAW_DIR            - Raw data directory")
    fmt.Println("  CLEANED_DIR        - Cleaned data directory")
    fmt.Println("  OUTPUT_FILE        - Cleaned output file path")
    fmt.Println("  SHARD_DIR          - Shards output directory")
    fmt.Println("  MAX_SHARDS         - Maximum number of shards (default: 128)")
    fmt.Println("")
}
