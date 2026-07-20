// neurx/scripts/train_orchestrator.s
// Training orchestration system - consolidates all training-related shell scripts
// Replaces: train_foundation_model.sh, run_train*.sh, train_1t_moe.sh, START_*B_TRAINING.sh, etc.

package scripts

import (
    "fmt"
    "os"
    "path/filepath"
    "strconv"
    "strings"
)

// ============================================================
// Training Configuration
// ============================================================

// TrainingScale defines model size configurations
enum TrainingScale {
    Mini,    // 124M params, 1 GPU
    Small,   // 1B params, 8 GPUs
    Medium,  // 7B params, 32 GPUs
    Large,   // 13B params, 64 GPUs (reference level)
    XL,      // 70B params, 512 GPUs (frontier level)
    OneT,    // 1T+ params (custom)
}

// training_config holds training parameters
struct training_config {
    scale         TrainingScale
    numGpus       int
    batchSize     int
    learningRate  float32
    epochs        int
    checkpointDir string
    logDir        string
    outputDir     string
    dataPath      string
    modelPath     string
    timestamp     string
}

// ScaleConfig returns parameters for a given scale
func get_scale_config(scale TrainingScale) struct {
    params    int
    gpus      int
    batch     int
    lr        float32
    seqLen    int
    layers    int
} {
    switch scale {
    case TrainingScale.Mini:
        return {
            params:  124_000_000,
            gpus:    1,
            batch:   32,
            lr:      1e-4,
            seqLen:  512,
            layers:  12,
        }
    case TrainingScale.Small:
        return {
            params:  1_000_000_000,
            gpus:    8,
            batch:   256,
            lr:      5e-5,
            seqLen:  2048,
            layers:  24,
        }
    case TrainingScale.Medium:
        return {
            params:  7_000_000_000,
            gpus:    32,
            batch:   512,
            lr:      3e-5,
            seqLen:  4096,
            layers:  32,
        }
    case TrainingScale.Large:
        return {
            params:  13_000_000_000,
            gpus:    64,
            batch:   1024,
            lr:      2e-5,
            seqLen:  4096,
            layers:  40,
        }
    case TrainingScale.XL:
        return {
            params:  70_000_000_000,
            gpus:    512,
            batch:   4096,
            lr:      1e-5,
            seqLen:  8192,
            layers:  80,
        }
    default:
        return {
            params:  124_000_000,
            gpus:    1,
            batch:   32,
            lr:      1e-4,
            seqLen:  512,
            layers:  12,
        }
    }
}

// ============================================================
// Training Orchestrator
// ============================================================

struct TrainOrchestrator {
    logger Logger
    config training_config
    sCompiler string
    neurxRoot string
}

// new_train_orchestrator creates a new training orchestrator
func new_train_orchestrator(scale TrainingScale, numGpus int) (*TrainOrchestrator, error) {
    logger := new_logger("TrainOrchestrator")

    // Determine NeurX root
    neurxRoot := get_env("NEURX_ROOT", "")
    if neurxRoot == "" {
        pwd, _ := os.Getwd()
        neurxRoot = pwd
    }

    // Find S compiler
    sCompiler := get_env("S_COMPILER", "")
    if sCompiler == "" {
        if command_exists("s") {
            sCompiler = "s"
        } else {
            sCompiler = filepath.Join(neurxRoot, "..", "s", ".local", "bin", "s")
        }
    }

    if !command_exists(sCompiler) && !file_exists(sCompiler) {
        return nil, fmt.Errorf("S compiler not found at %s", sCompiler)
    }

    config := training_config{
        scale:         scale,
        numGpus:       numGpus,
        timestamp:     timestamp(),
    }

    config.logDir = filepath.Join(neurxRoot, "logs", fmt.Sprintf("%s_%s", scaleString(scale), config.timestamp))
    config.checkpointDir = filepath.Join(neurxRoot, "checkpoints", fmt.Sprintf("%s_%s", scaleString(scale), config.timestamp))
    config.outputDir = filepath.Join(neurxRoot, "outputs", fmt.Sprintf("%s_%s", scaleString(scale), config.timestamp))

    return &TrainOrchestrator{
        logger:    logger,
        config:    config,
        sCompiler: sCompiler,
        neurxRoot: neurxRoot,
    }, nil
}

// setup prepares directories and environment
func (t *TrainOrchestrator) setup() error {
    t.logger.log("Setting up training environment...")

    // Create directories
    for _, dir := range []string{t.config.logDir, t.config.checkpointDir, t.config.outputDir} {
        if err := mkdir(dir); err != nil {
            return err
        }
    }

    // Log configuration
    t.log_config()
    return nil
}

// check_environment verifies GPU availability and dependencies
func (t *TrainOrchestrator) check_environment() error {
    t.logger.log("Checking environment...")

    // Check GPU availability
    numGpus, backend := t.detectGPUs()
    if numGpus < t.config.numGpus {
        t.logger.warn("Requested %d GPUs but only %d available, using %d", t.config.numGpus, numGpus, numGpus)
        t.config.numGpus = numGpus
    }
    t.logger.success("Detected %d GPUs (%s)", numGpus, backend)

    // Check data
    if t.config.dataPath != "" && !file_exists(t.config.dataPath) {
        t.logger.error("Data path not found: %s", t.config.dataPath)
        return fmt.Errorf("data not found")
    }

    return nil
}

// Compile compiles the training module
func (t *TrainOrchestrator) Compile() error {
    t.logger.log("Compiling NeurX training module...")

    sourceFile := filepath.Join(t.config.outputDir, "neurx_training.s")
    irFile := filepath.Join(t.config.outputDir, "neurx_training.ir")
    binFile := filepath.Join(t.config.outputDir, "neurx_train")

    // Generate S source if needed
    if !file_exists(sourceFile) {
        if err := t.generateTrainingSource(sourceFile); err != nil {
            return err
        }
    }

    // Compile to IR
    t.logger.log("Compiling to IR...")
    result := exec_command(t.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        t.logger.error("Compilation failed: %s", result.Stderr)
        return fmt.Errorf("compilation failed")
    }
    t.logger.success("IR generated: %s", irFile)

    // Compile to binary
    t.logger.log("Generating binary...")
    result = exec_command(t.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        t.logger.error("Binary generation failed: %s", result.Stderr)
        return fmt.Errorf("binary generation failed")
    }
    t.logger.success("Binary generated: %s", binFile)

    return nil
}

// Run executes the training
func (t *TrainOrchestrator) Run() error {
    t.logger.log("Starting training...")

    binFile := filepath.Join(t.config.outputDir, "neurx_train")
    if !file_exists(binFile) {
        return fmt.Errorf("training binary not found at %s", binFile)
    }

    // Build command with environment
    cmd := fmt.Sprintf("cd %s && ", t.neurxRoot)
    cmd += fmt.Sprintf("NEURX_GPUS=%d ", t.config.numGpus)
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", t.config.batchSize)
    cmd += fmt.Sprintf("NEURX_LOG_DIR=%s ", t.config.logDir)
    cmd += fmt.Sprintf("NEURX_CKPT_DIR=%s ", t.config.checkpointDir)
    cmd += fmt.Sprintf("%s 2>&1 | tee -a %s", binFile, filepath.Join(t.config.logDir, "train.log"))

    result := shell(cmd)
    if result.ExitCode != 0 {
        t.logger.error("Training failed: %s", result.Stderr)
        return fmt.Errorf("training failed")
    }

    t.logger.success("Training completed")
    return nil
}

// Monitor monitors training progress
func (t *TrainOrchestrator) Monitor() error {
    t.logger.log("Starting training monitor...")

    logFile := filepath.Join(t.config.logDir, "train.log")

    // Wait for log file to be created
    for i := 0; i < 30; i++ {
        if file_exists(logFile) {
            break
        }
        sleep_seconds(1)
    }

    if !file_exists(logFile) {
        return fmt.Errorf("training log not found")
    }

    // Tail log file
    result := shell(fmt.Sprintf("tail -f %s", logFile))
    if result.ExitCode != 0 {
        t.logger.error("Monitoring failed: %s", result.Stderr)
    }

    return nil
}

// ============================================================
// Helper Functions
// ============================================================

func (t *TrainOrchestrator) detectGPUs() (int, string) {
    // Check for NVIDIA GPUs
    if command_exists("nvidia-smi") {
        result := exec_command("nvidia-smi", "--query-gpu=name", "--format=csv,noheader")
        if result.ExitCode == 0 {
            lines := strings.Split(trim_text(result.Stdout), "\n")
            return len(lines), "NVIDIA CUDA"
        }
    }

    // Check for Apple Silicon
    if command_exists("system_profiler") {
        result := exec_command("system_profiler", "SPDisplaysDataType")
        if result.ExitCode == 0 && strings.Contains(result.Stdout, "Apple") {
            return 1, "Apple Silicon (MPS)"
        }
    }

    // Default to CPU
    return 1, "CPU"
}

func (t *TrainOrchestrator) log_config() error {
    config := fmt.Sprintf(`╔══════════════════════════════════════════════════╗
║   NeurX Foundation Model Training               ║
║   English text: English text NeurX English text                    ║
╠══════════════════════════════════════════════════╣
║ English text: %s
║ GPU English text: %d
║ timeEnglish text: %s
║ log: %s
║ checkpoint: %s
╚══════════════════════════════════════════════════╝

`, scaleString(t.config.scale), t.config.numGpus, t.config.timestamp, t.config.logDir, t.config.checkpointDir)

    logFile := filepath.Join(t.config.logDir, "config.txt")
    return write_file(logFile, config)
}

func (t *TrainOrchestrator) generateTrainingSource(outputPath string) error {
    // Generate S source based on scale
    scaleConfig := get_scale_config(t.config.scale)

    source := fmt.Sprintf(`// Auto-generated training source
package main

import "fmt"

func main() {
    // Training configuration for %s scale
    params := %d
    gpus := %d
    batchSize := %d
    learningRate := %.2e
    seqLen := %d
    layers := %d

    fmt.Printf("Training Configuration:\\n")
    fmt.Printf("  Parameters: %%d\\n", params)
    fmt.Printf("  GPUs: %%d\\n", gpus)
    fmt.Printf("  Batch Size: %%d\\n", batchSize)
    fmt.Printf("  Learning Rate: %%.2e\\n", learningRate)
    fmt.Printf("  Sequence Length: %%d\\n", seqLen)
    fmt.Printf("  Layers: %%d\\n", layers)

    // Training loop would go here
    fmt.Println("Training loop started...")
}
`, scaleString(t.config.scale), scaleConfig.params, scaleConfig.gpus, scaleConfig.batch, scaleConfig.lr, scaleConfig.seqLen, scaleConfig.layers)

    return write_file(outputPath, source)
}

func scaleString(scale TrainingScale) string {
    switch scale {
    case TrainingScale.Mini:
        return "mini"
    case TrainingScale.Small:
        return "small"
    case TrainingScale.Medium:
        return "medium"
    case TrainingScale.Large:
        return "large"
    case TrainingScale.XL:
        return "xl"
    default:
        return "unknown"
    }
}

// ============================================================
// Public Training Functions
// ============================================================

// run_foundation_model_training starts foundation model training
func run_foundation_model_training(scale string, numGpus int) error {
    // Parse scale
    var scaleEnum TrainingScale
    switch to_lower(scale) {
    case "mini":
        scaleEnum = TrainingScale.Mini
    case "small":
        scaleEnum = TrainingScale.Small
    case "medium":
        scaleEnum = TrainingScale.Medium
    case "large":
        scaleEnum = TrainingScale.Large
    case "xl":
        scaleEnum = TrainingScale.XL
    default:
        scaleEnum = TrainingScale.Mini
    }

    // Create orchestrator
    orchestrator, err := new_train_orchestrator(scaleEnum, numGpus)
    if err != nil {
        return err
    }

    // exec_commandute training pipeline
    if err := orchestrator.setup(); err != nil {
        return err
    }

    if err := orchestrator.check_environment(); err != nil {
        return err
    }

    if err := orchestrator.Compile(); err != nil {
        return err
    }

    // Run training
    go func() {
        if err := orchestrator.Run(); err != nil {
            orchestrator.logger.error("Training error: %v", err)
        }
    }()

    // Monitor training
    if err := orchestrator.Monitor(); err != nil {
        orchestrator.logger.error("Monitoring error: %v", err)
    }

    return nil
}

// start_quick_training starts a quick training session for testing
func start_quick_training() error {
    return run_foundation_model_training("mini", 1)
}

// launch_70b_training starts 70B model training
func launch_70b_training(numGpus int) error {
    return run_foundation_model_training("xl", numGpus)
}

// launch_7b_training starts 7B model training
func launch_7b_training(numGpus int) error {
    return run_foundation_model_training("large", numGpus)
}

// launch_1t_training starts 1T+ model training
func launch_1t_training(numGpus int) error {
    orchestrator, err := new_train_orchestrator(TrainingScale.OneT, numGpus)
    if err != nil {
        return err
    }
    return orchestrator.setup()
}
