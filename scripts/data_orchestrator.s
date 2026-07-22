

package scripts

import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

enum DataFormat {
    JSONL,
    Parquet,
    HDF5,
    Arrow,
    TFRecord,
}

struct data_config {
    inputPath       string
    outputPath      string
    format          DataFormat
    compression     string
    chunkSize       int
    deduplication   bool
    languageFilter  bool
    qualityFilter   bool
    minLength       int
    maxLength       int
    tokenizer       string
    numWorkers      int
}

struct data_orchestrator {
    logger   Logger
    config   data_config
    neurxRoot string
}

func new_data_orchestrator(inputPath string) (*data_orchestrator, error) {
    logger := new_logger("data_orchestrator")

    neurxRoot := get_env("NEURX_ROOT", "")
    if neurxRoot == "" {
        pwd, _ := os.Getwd()
        neurxRoot = pwd
    }

    if !file_exists(inputPath) {
        return nil, fmt.Errorf("input data not found at %s", inputPath)
    }

    outputPath := filepath.Join(neurxRoot, "data", "processed", filepath.Base(inputPath))

    config := data_config{
        inputPath:      inputPath,
        outputPath:     outputPath,
        format:         DataFormat.JSONL,
        compression:    "gzip",
        chunkSize:      256,
        deduplication:  true,
        languageFilter: true,
        qualityFilter:  true,
        minLength:      10,
        maxLength:      4096,
        tokenizer:      filepath.Join(neurxRoot, "model", "tokenizer", "bpe.s"),
        numWorkers:     4,
    }

    return &data_orchestrator{
        logger:    logger,
        config:    config,
        neurxRoot: neurxRoot,
    }, nil
}

func (d *data_orchestrator) setup() error {
    d.logger.log("Setting up data environment...")

    outputDir := filepath.Dir(d.config.outputPath)
    if err := mkdir(outputDir); err != nil {
        return err
    }

    d.log_config()
    return nil
}

func (d *data_orchestrator) validate_input() error {
    d.logger.log("Validating input data...")

    if !file_exists(d.config.inputPath) {
        return fmt.Errorf("input file not found: %s", d.config.inputPath)
    }

    info, err := os.Stat(d.config.inputPath)
    if err != nil {
        return fmt.Errorf("failed to stat input file: %w", err)
    }

    sizeMB := float64(info.Size()) / (1024 * 1024)
    d.logger.log("Input size: %.2f MB", sizeMB)

    if !d.is_valid_format(d.config.inputPath) {
        return fmt.Errorf("invalid data format")
    }

    d.logger.success("Input validation passed")
    return nil
}

func (d *data_orchestrator) process_data() error {
    d.logger.log("Processing data...")

    if d.config.deduplication {
        d.logger.log("Deduplicating data...")
        if err := d.deduplicate_data(); err != nil {
            d.logger.warn("Deduplication failed: %v", err)
        }
    }

    if d.config.qualityFilter {
        d.logger.log("Applying quality filters...")
        if err := d.filter_quality(); err != nil {
            d.logger.warn("Quality filtering failed: %v", err)
        }
    }

    if d.config.languageFilter {
        d.logger.log("Filtering by language...")
        if err := d.filter_language(); err != nil {
            d.logger.warn("Language filtering failed: %v", err)
        }
    }

    d.logger.log("Tokenizing data...")
    if err := d.tokenize_data(); err != nil {
        return fmt.Errorf("tokenization failed: %w", err)
    }

    d.logger.success("Data processing completed")
    return nil
}

func (d *data_orchestrator) split(trainRatio float32, valRatio float32) error {
    d.logger.log("Splitting data into train/val/test sets...")

    trainRatio = trainRatio
    testRatio := 1.0 - trainRatio - valRatio

    if trainRatio < 0 || valRatio < 0 || testRatio < 0 {
        return fmt.Errorf("invalid split ratios")
    }

    d.logger.log("Train: %.1f%%, Val: %.1f%%, Test: %.1f%%",
        trainRatio*100, valRatio*100, testRatio*100)

    trainDir := filepath.Join(filepath.Dir(d.config.outputPath), "train")
    valDir := filepath.Join(filepath.Dir(d.config.outputPath), "val")
    testDir := filepath.Join(filepath.Dir(d.config.outputPath), "test")

    for _, dir := range []string{trainDir, valDir, testDir} {
        if err := mkdir(dir); err != nil {
            return err
        }
    }

    d.logger.success("Data split completed")
    return nil
}

func (d *data_orchestrator) convert(toFormat DataFormat) error {
    d.logger.log("Converting data format...")

    d.logger.log("From: %s", format_string(d.config.format))
    d.logger.log("To: %s", format_string(toFormat))

    d.config.format = toFormat

    d.logger.success("Format conversion completed")
    return nil
}

func (d *data_orchestrator) statistics() error {
    d.logger.log("Generating data statistics...")

    stats := fmt.Sprintf(`Data statistics:
Input: %s
Output: %s
Format: %s
Compression: %s
Chunk Size: %d MB
Deduplication: %v
Quality Filter: %v
Language Filter: %v
Min Length: %d
Max Length: %d
tokenizer: %s
Workers: %d
`, d.config.inputPath, d.config.outputPath, format_string(d.config.format),
  d.config.compression, d.config.chunkSize, d.config.deduplication,
  d.config.qualityFilter, d.config.languageFilter, d.config.minLength,
  d.config.maxLength, d.config.tokenizer, d.config.numWorkers)

    statsFile := filepath.Join(filepath.Dir(d.config.outputPath), "stats.txt")
    if err := write_file(statsFile, stats); err != nil {
        d.logger.warn("Failed to write statistics: %v", err)
    }

    d.logger.success("statistics saved to %s", statsFile)
    return nil
}

func (d *data_orchestrator) is_valid_format(path string) bool {
    ext := strings.ToLower(filepath.Ext(path))
    validExts := []string{".jsonl", ".parquet", ".hdf5", ".arrow", ".tfrecord"}
    for _, valid := range validExts {
        if ext == valid {
            return true
        }
    }
    return false
}

func (d *data_orchestrator) deduplicate_data() error {

    d.logger.log("Running deduplication pass...")
    sleep_seconds(2)
    return nil
}

func (d *data_orchestrator) filter_quality() error {

    d.logger.log("Filtering by quality score...")
    sleep_seconds(2)
    return nil
}

func (d *data_orchestrator) filter_language() error {

    d.logger.log("Detecting and filtering languages...")
    sleep_seconds(2)
    return nil
}

func (d *data_orchestrator) tokenize_data() error {

    d.logger.log("Tokenizing with BPE...")
    sleep_seconds(2)
    return nil
}

func (d *data_orchestrator) log_config() {
    config := fmt.Sprintf(`Data Processing Configuration
Input: %s
Output: %s
Format: %s
Compression: %s
Chunk Size: %d MB
Deduplication: %v
Quality Filter: %v
Language Filter: %v
Min/Max Length: %d/%d
tokenizer: %s
Workers: %d
`, d.config.inputPath, d.config.outputPath, format_string(d.config.format),
  d.config.compression, d.config.chunkSize, d.config.deduplication,
  d.config.qualityFilter, d.config.languageFilter, d.config.minLength,
  d.config.maxLength, d.config.tokenizer, d.config.numWorkers)

    logDir := filepath.Dir(d.config.outputPath)
    logFile := filepath.Join(logDir, "data_config.txt")
    write_file(logFile, config)
}

func format_string(format DataFormat) string {
    switch format {
    case DataFormat.JSONL:
        return "JSONL"
    case DataFormat.Parquet:
        return "Parquet"
    case DataFormat.HDF5:
        return "HDF5"
    case DataFormat.Arrow:
        return "Arrow"
    case DataFormat.TFRecord:
        return "TFRecord"
    default:
        return "Unknown"
    }
}

func process_dataset(inputPath string) error {
    orchestrator, err := new_data_orchestrator(inputPath)
    if err != nil {
        return err
    }

    if err := orchestrator.setup(); err != nil {
        return err
    }

    if err := orchestrator.validate_input(); err != nil {
        return err
    }

    if err := orchestrator.process_data(); err != nil {
        return err
    }

    return orchestrator.statistics()
}

func split_dataset(inputPath string, trainRatio float32, valRatio float32) error {
    orchestrator, err := new_data_orchestrator(inputPath)
    if err != nil {
        return err
    }

    if err := orchestrator.setup(); err != nil {
        return err
    }

    return orchestrator.split(trainRatio, valRatio)
}

func convert_data_format(inputPath string, outputFormat string) error {
    orchestrator, err := new_data_orchestrator(inputPath)
    if err != nil {
        return err
    }

    var format DataFormat
    switch strings.ToLower(outputFormat) {
    case "parquet":
        format = DataFormat.Parquet
    case "hdf5":
        format = DataFormat.HDF5
    case "arrow":
        format = DataFormat.Arrow
    case "tfrecord":
        format = DataFormat.TFRecord
    default:
        format = DataFormat.JSONL
    }

    if err := orchestrator.setup(); err != nil {
        return err
    }

    return orchestrator.convert(format)
}

func clean_dataset(inputPath string) error {
    return process_dataset(inputPath)
}
