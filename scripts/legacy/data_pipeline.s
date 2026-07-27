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
type clean_config struct {
    RawDir         string
    CleanedDir     string
    OutputFile     string
    ManifestFile   string
    CheckpointFile string
}

type shard_config struct {
    InputFile      string
    ShardDir       string
    ManifestFile   string
    MaxShards      int
    LinesPerShard  int
}

type shard_metadata struct {
    ShardID       string `json:"shard_id"`
    FilePath      string `json:"file_path"`
    NumDocuments  int64  `json:"num_documents"`
    SizeBytes     int64  `json:"size_bytes"`
}

type manifest struct {
    DatasetName         string           `json:"dataset_name"`
    Version             string           `json:"version"`
    CreatedAt           string           `json:"created_at"`
    TotalShards         int64            `json:"total_shards"`
    TotalDocuments      int64            `json:"total_documents"`
    TotalSizeBytes      int64            `json:"total_size_bytes"`
    AverageDocsPerShard int64            `json:"average_docs_per_shard"`
    Shards              []shard_metadata  `json:"shards"`
}

func main() {
    if len(os.Args) < 2 {
        printHelp()
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

func cmdClean() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║     NeurX Data Cleaning (S Language)      ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    config := getCleanConfig()
    if err := ensureDir(config.CleanedDir); err != nil {
        fmt.Printf("✗ Failed to create directory: %v\n", err)
        os.Exit(1)
    }
    fmt.Printf("📂 Configuration:\n")
    fmt.Printf("  • Raw data: %s\n", config.RawDir)
    fmt.Printf("  • Output: %s\n", config.OutputFile)
    fmt.Printf("  • manifest: %s\n", config.ManifestFile)
    fmt.Println("")
    if err := cleanData(config); err != nil {
        fmt.Printf("✗ Cleaning failed: %v\n", err)
        os.Exit(1)
    }
    fmt.Println("")
    fmt.Println("✓ Data cleaning completed successfully")
}

func cmdShard() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║    NeurX Data Sharding (S Language)       ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    config := getShardConfig()
    if err := ensureDir(config.ShardDir); err != nil {
        fmt.Printf("✗ Failed to create directory: %v\n", err)
        os.Exit(1)
    }
    if err := generateShards(config); err != nil {
        fmt.Printf("✗ Sharding failed: %v\n", err)
        os.Exit(1)
    }
    fmt.Println("")
    fmt.Println("✓ Data sharding completed successfully")
}

func cmdPipeline() {
    fmt.Println("")
    fmt.Println("╔════════════════════════════════════════════╗")
    fmt.Println("║   NeurX Full Pipeline (Clean + Shard)     ║")
    fmt.Println("╚════════════════════════════════════════════╝")
    fmt.Println("")
    fmt.Println("Step 1/2: Cleaning data...")
    cmdClean()
    fmt.Println("")
    fmt.Println("Step 2/2: Generating shards...")
    cmdShard()
}

func getCleanConfig() CleanConfig {
    home := getEnv("NEURX_HOME", ".")
    return CleanConfig{
        RawDir:         getEnv("RAW_DIR", filepath.Join(home, "dataset", "pretrain", "raw")),
        CleanedDir:     getEnv("CLEANED_DIR", filepath.Join(home, "dataset", "pretrain", "cleaned")),
        OutputFile:     getEnv("OUTPUT_FILE", filepath.Join(home, "dataset", "pretrain", "cleaned", "pretrain_data_cleaned.jsonl")),
        ManifestFile:   getEnv("MANIFEST_FILE", filepath.Join(home, "dataset", "pretrain", "manifest.json")),
        CheckpointFile: getEnv("CHECKPOINT_FILE", filepath.Join(home, "dataset", "pretrain", "cleaned", ".cleaning_checkpoint.json")),
    }
}

func getShardConfig() ShardConfig {
    home := getEnv("NEURX_HOME", ".")
    datasetRoot := getEnv("DATASET_ROOT", filepath.Join(home, "dataset", "pretrain"))
    return ShardConfig{
        InputFile:     getEnv("INPUT_FILE", filepath.Join(datasetRoot, "cleaned", "train.jsonl")),
        ShardDir:      getEnv("SHARD_DIR", filepath.Join(datasetRoot, "shard")),
        ManifestFile:  getEnv("MANIFEST_FILE", filepath.Join(datasetRoot, "manifest.json")),
        MaxShards:     getEnvInt("MAX_SHARDS", 128),
        LinesPerShard: getEnvInt("LINES_PER_SHARD", 100),
    }
}

func cleanData(config CleanConfig) error {
    files, err := findSourceFiles(config.RawDir)
    if err != nil {
        return err
    }
    if len(files) == 0 {
        fmt.Println("⚠ No raw data files found")
        return writeEmptyManifest(config)
    }
    fmt.Printf("📚 Found %d source files\n", len(files))
    fmt.Println("")
    seenHashes := make(map[string]bool)
    stats := &clean_stats{
        TotalProcessed: 0,
        TotalWritten:   0,
        Duplicates:     0,
        Errors:         0,
    }
    outputHandle, err := os.Create(config.OutputFile)
    if err != nil {
        return err
    }
    defer outputHandle.Close()
    writer := bufio.NewWriter(outputHandle)
    for _, file := range files {
        fmt.Printf("  Processing: %s\n", filepath.Base(file))
        content, err := ioutil.ReadFile(file)
        if err != nil {
            fmt.Printf("  ⚠ Failed to read: %v\n", err)
            stats.Errors++
            continue
        }
        processFileContent(writer, string(content), seenHashes, stats)
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
    if err := generateSplits(config); err != nil {
        return err
    }
    return writeManifest(config, stats.TotalWritten)
}

type clean_stats struct {
    TotalProcessed int64
    TotalWritten   int64
    Duplicates     int64
    Errors         int64
}

func processFileContent(writer *bufio.Writer, content string, seen map[string]bool, stats *clean_stats) {
    lines := strings.Split(content, "\n")
    for _, line := range lines {
        line = strings.TrimSpace(line)
        if line == "" {
            continue
        }
        stats.TotalProcessed++
        text := extractText(line)
        if text == "" {
            continue
        }
        hash := hashKey(normalizeText(text))
        if seen[hash] {
            stats.Duplicates++
            continue
        }
        seen[hash] = true
        record := createRecord(text)
        writer.WriteString(record + "\n")
        stats.TotalWritten++
    }
}

func generateSplits(config CleanConfig) error {
    content, err := ioutil.ReadFile(config.OutputFile)
    if err != nil {
        return err
    }
    lines := strings.Split(string(content), "\n")
    total := int64(len(lines))
    trainSize := total * 8 / 10
    valSize := total / 10
    testSize := total - trainSize - valSize
    trainFile := filepath.Join(config.CleanedDir, "train.jsonl")
    valFile := filepath.Join(config.CleanedDir, "val.jsonl")
    testFile := filepath.Join(config.CleanedDir, "test.jsonl")
    trainHandle, _ := os.Create(trainFile)
    valHandle, _ := os.Create(valFile)
    testHandle, _ := os.Create(testFile)
    defer trainHandle.Close()
    defer valHandle.Close()
    defer testHandle.Close()
    for i, line := range lines {
        if line == "" {
            continue
        }
        idx := int64(i)
        if idx < trainSize {
            trainHandle.WriteString(line + "\n")
        } else if idx < trainSize+valSize {
            valHandle.WriteString(line + "\n")
        } else {
            testHandle.WriteString(line + "\n")
        }
    }
    fmt.Printf("✓ Dataset splits created (train: %.1f%%, val: %.1f%%, test: %.1f%%)\n",
        float64(trainSize)*100/float64(total),
        float64(valSize)*100/float64(total),
        float64(testSize)*100/float64(total))
    return nil
}

func generateShards(config ShardConfig) error {
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
    totalLines := int64(0)
    for _, line := range lines {
        if strings.TrimSpace(line) != "" {
            totalLines++
        }
    }
    fmt.Printf("  • Total lines: %d\n", totalLines)
    fmt.Println("")
    if totalLines == 0 {
        fmt.Println("⚠ No documents found in input file")
        return writeEmptyManifest(CleanConfig{ManifestFile: config.ManifestFile})
    }
    idealShards := (totalLines + int64(config.LinesPerShard) - 1) / int64(config.LinesPerShard)
    actualShards := idealShards
    if actualShards > int64(config.MaxShards) {
        actualShards = int64(config.MaxShards)
    }
    linesPerShard := (totalLines + actualShards - 1) / actualShards
    fmt.Printf("📊 Shard calculation:\n")
    fmt.Printf("  • Ideal shards: %d\n", idealShards)
    fmt.Printf("  • Actual shards: %d\n", actualShards)
    fmt.Printf("  • Lines per shard: %d\n", linesPerShard)
    fmt.Println("")
    fmt.Println("✂️ Generating shards...")
    var shards []shard_metadata
    currentShard := 0
    currentData := ""
    currentCount := int64(0)
    for _, line := range lines {
        line = strings.TrimSpace(line)
        if line == "" {
            continue
        }
        currentData += line + "\n"
        currentCount++
        if currentCount >= linesPerShard {
            shardFile := formatShardFilename(config.ShardDir, currentShard)
            size, err := writeShardFile(shardFile, currentData)
            if err != nil {
                return err
            }
            shards = append(shards, shard_metadata{
                ShardID:       formatShardID(currentShard),
                FilePath:      shardFile,
                NumDocuments:  currentCount,
                SizeBytes:     size,
            })
            currentData = ""
            currentCount = 0
            currentShard++
        }
    }
    if currentCount > 0 {
        shardFile := formatShardFilename(config.ShardDir, currentShard)
        size, err := writeShardFile(shardFile, currentData)
        if err != nil {
            return err
        }
        shards = append(shards, shard_metadata{
            ShardID:       formatShardID(currentShard),
            FilePath:      shardFile,
            NumDocuments:  currentCount,
            SizeBytes:     size,
        })
    }
    fmt.Printf("✓ Generated %d shards\n", len(shards))
    fmt.Println("")
    return writeShardManifest(config.ManifestFile, shards)
}

func writeShardFile(path string, content string) (int64, error) {
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

func findSourceFiles(dir string) ([]string, error) {
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

func extractText(line string) string {
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
    endIdx := strings.Index(rest, "\"")
    if endIdx < 0 {
        return ""
    }
    return rest[:endIdx]
}

func normalizeText(text string) string {
    text = strings.TrimSpace(text)
    text = strings.ToLower(text)
    parts := strings.Fields(text)
    return strings.Join(parts, " ")
}

func hashKey(text string) string {
    h := sha256.New()
    h.Write([]byte(text))
    return hex.EncodeToString(h.Sum(nil))
}

func createRecord(text string) string {
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

func formatShardID(index int) string {
    return fmt.Sprintf("shard_%05d", index)
}

func formatShardFilename(dir string, index int) string {
    return filepath.Join(dir, formatShardID(index)+".jsonl")
}

func writeShardManifest(path string, shards []shard_metadata) error {
    var totalDocs int64
    var totalSize int64
    for _, shard := range shards {
        totalDocs += shard.NumDocuments
        totalSize += shard.SizeBytes
    }
    avgDocs := int64(0)
    if len(shards) > 0 {
        avgDocs = totalDocs / int64(len(shards))
    }
    manifest := manifest{
        DatasetName:         "neurx-pretrain-dataset",
        Version:             "1.0",
        CreatedAt:           "2026-07-07T00:00:00Z",
        TotalShards:         int64(len(shards)),
        TotalDocuments:      totalDocs,
        TotalSizeBytes:      totalSize,
        AverageDocsPerShard: avgDocs,
        Shards:              shards,
    }
    data, err := json.MarshalIndent(manifest, "", "  ")
    if err != nil {
        return err
    }
    return ioutil.WriteFile(path, data, 0644)
}

func writeManifest(config CleanConfig, totalDocs int64) error {
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

func writeEmptyManifest(config CleanConfig) error {
    manifest := map[string]interface{}{
        "dataset_name": "neurx-pretrain-dataset",
        "version":      "1.0",
        "status":       "empty",
        "total_documents": 0,
    }
    data, _ := json.MarshalIndent(manifest, "", "  ")
    return ioutil.WriteFile(config.ManifestFile, data, 0644)
}

func ensureDir(dir string) error {
    return os.MkdirAll(dir, 0755)
}

func getEnv(key, defaultVal string) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return defaultVal
}

func getEnvInt(key string, defaultVal int) int {
    if val := os.Getenv(key); val != "" {
        var num int
        fmt.Sscanf(val, "%d", &num)
        return num
    }
    return defaultVal
}

func printHelp() {
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
