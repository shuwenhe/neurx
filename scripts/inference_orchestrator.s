// neurx/scripts/inference_orchestrator.s
// Inference orchestration system - consolidates all inference-related shell scripts
// Replaces: run_inference*.sh, launch_smart_inference.sh, demo_smart_inference.sh, etc.

package scripts

import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

// ============================================================
// Inference Configuration
// ============================================================

enum InferenceBackend {
    ONNX,
    TensorRT,
    vLLM,
    DeepSpeed,
    Native,    // Pure S implementation
}

struct inference_config {
    modelPath    string
    backend      InferenceBackend
    batchSize    int
    maxTokens    int
    temperature  float32
    topK         int
    topP         float32
    repetitionPenalty float32
    useCache     bool
    useSpectral  bool    // Speculative decoding
    port         int
    logDir       string
}

// ============================================================
// Inference Orchestrator
// ============================================================

struct InferenceOrchestrator {
    logger  Logger
    config  inference_config
    sCompiler string
    neurxRoot string
}

// new_inference_orchestrator creates a new inference orchestrator
func new_inference_orchestrator(modelPath string) (*InferenceOrchestrator, error) {
    logger := new_logger("InferenceOrchestrator")
    
    neurxRoot := get_env("NEURX_ROOT", "")
    if neurxRoot == "" {
        pwd, _ := os.Getwd()
        neurxRoot = pwd
    }
    
    sCompiler := get_env("S_COMPILER", "s")
    if !command_exists(sCompiler) {
        sCompiler = filepath.Join(neurxRoot, "..", "s", ".local", "bin", "s")
    }
    
    if !file_exists(modelPath) {
        return nil, fmt.Errorf("model not found at %s", modelPath)
    }
    
    config := inference_config{
        modelPath:        modelPath,
        backend:          InferenceBackend.Native,
        batchSize:        1,
        maxTokens:        2048,
        temperature:      0.8,
        topK:             40,
        topP:             0.95,
        repetitionPenalty: 1.0,
        useCache:         true,
        useSpectral:      false,
        port:             8000,
        logDir:           filepath.Join(neurxRoot, "logs", "inference"),
    }
    
    return &InferenceOrchestrator{
        logger:    logger,
        config:    config,
        sCompiler: sCompiler,
        neurxRoot: neurxRoot,
    }, nil
}

// setup prepares inference environment
func (i *InferenceOrchestrator) setup() error {
    i.logger.log("Setting up inference environment...")
    
    if err := mkdir(i.config.logDir); err != nil {
        return err
    }
    
    // Log configuration
    i.log_config()
    
    return nil
}

// Compile compiles the inference server
func (i *InferenceOrchestrator) Compile() error {
    i.logger.log("Compiling inference server...")
    
    buildDir := filepath.Join(i.neurxRoot, ".build", "inference")
    if err := mkdir(buildDir); err != nil {
        return err
    }
    
    irFile := filepath.Join(buildDir, "inference_server.ir")
    binFile := filepath.Join(buildDir, "inference_server")
    
    // Compile inference server
    sourceFile := filepath.Join(i.neurxRoot, "infer", "inference_server.s")
    if !file_exists(sourceFile) {
        i.logger.warn("Inference server source not found at %s", sourceFile)
        return fmt.Errorf("inference source not found")
    }
    
    i.logger.log("Compiling to IR...")
    result := exec_command(i.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        i.logger.error("Compilation failed: %s", result.Stderr)
        return fmt.Errorf("compilation failed")
    }
    
    i.logger.log("Generating binary...")
    result = exec_command(i.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        i.logger.error("Binary generation failed: %s", result.Stderr)
        return fmt.Errorf("binary generation failed")
    }
    
    i.logger.success("Inference server compiled: %s", binFile)
    return nil
}

// start_server starts the inference server
func (i *InferenceOrchestrator) start_server() error {
    i.logger.log("Starting inference server...")
    
    binFile := filepath.Join(i.neurxRoot, ".build", "inference", "inference_server")
    if !file_exists(binFile) {
        if err := i.Compile(); err != nil {
            return err
        }
    }
    
    logFile := filepath.Join(i.config.logDir, "inference_server.log")
    
    // Build command
    cmd := fmt.Sprintf("cd %s && ", i.neurxRoot)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.modelPath)
    cmd += fmt.Sprintf("NEURX_BACKEND=%s ", backend_string(i.config.backend))
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", i.config.batchSize)
    cmd += fmt.Sprintf("NEURX_MAX_TOKENS=%d ", i.config.maxTokens)
    cmd += fmt.Sprintf("NEURX_PORT=%d ", i.config.port)
    cmd += fmt.Sprintf("%s 2>&1 | tee %s", binFile, logFile)
    
    i.logger.log("exec_commanduting: %s", cmd)
    
    // Start server in background
    go func() {
        result := shell(cmd)
        if result.ExitCode != 0 {
            i.logger.error("Server failed: %s", result.Stderr)
        }
    }()
    
    // Wait for server to start
    i.logger.log("Waiting for server to start (checking port %d)...", i.config.port)
    for i := 0; i < 30; i++ {
        if i.is_server_ready() {
            i.logger.success("Server is ready on port %d", i.config.port)
            return nil
        }
        sleep_seconds(1)
    }
    
    return fmt.Errorf("server failed to start within timeout")
}

// interactive starts an interactive inference session
func (i *InferenceOrchestrator) interactive() error {
    i.logger.log("Starting interactive inference session...")
    
    binFile := filepath.Join(i.neurxRoot, ".build", "inference", "inference_interactive")
    if !file_exists(binFile) {
        i.logger.log("Building interactive inference...")
        // TODO: Build interactive binary
    }
    
    // Start interactive session
    result := shell(binFile)
    if result.ExitCode != 0 {
        i.logger.error("Session failed: %s", result.Stderr)
        return fmt.Errorf("inference session failed")
    }
    
    return nil
}

// chat starts a chat interface
func (i *InferenceOrchestrator) chat() error {
    i.logger.log("Starting chat interface...")
    
    sourceFile := filepath.Join(i.neurxRoot, "tools", "chat.s")
    if !file_exists(sourceFile) {
        return fmt.Errorf("chat tool not found")
    }
    
    buildDir := filepath.Join(i.neurxRoot, ".build", "chat")
    if err := mkdir(buildDir); err != nil {
        return err
    }
    
    binFile := filepath.Join(buildDir, "chat")
    irFile := filepath.Join(buildDir, "chat.ir")
    
    // Compile chat tool
    i.logger.log("Compiling chat tool...")
    result := exec_command(i.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    
    result = exec_command(i.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
    
    // Run chat
    cmd := fmt.Sprintf("cd %s && ", i.neurxRoot)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.modelPath)
    cmd += fmt.Sprintf("NEURX_BACKEND=%s ", backend_string(i.config.backend))
    cmd += fmt.Sprintf("NEURX_MAX_TOKENS=%d ", i.config.maxTokens)
    cmd += binFile
    
    result = shell(cmd)
    if result.ExitCode != 0 {
        return fmt.Errorf("chat failed")
    }
    
    return nil
}

// benchmark runs inference benchmarks
func (i *InferenceOrchestrator) benchmark() error {
    i.logger.log("Running inference benchmarks...")
    
    sourceFile := filepath.Join(i.neurxRoot, "eval", "benchmark_eval.s")
    if !file_exists(sourceFile) {
        return fmt.Errorf("benchmark tool not found")
    }
    
    buildDir := filepath.Join(i.neurxRoot, ".build", "benchmark")
    if err := mkdir(buildDir); err != nil {
        return err
    }
    
    binFile := filepath.Join(buildDir, "benchmark")
    irFile := filepath.Join(buildDir, "benchmark.ir")
    
    // Compile benchmark
    i.logger.log("Compiling benchmark tool...")
    result := exec_command(i.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    
    result = exec_command(i.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
    
    // Run benchmarks
    logFile := filepath.Join(i.config.logDir, "benchmark.log")
    cmd := fmt.Sprintf("cd %s && ", i.neurxRoot)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.modelPath)
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", i.config.batchSize)
    cmd += fmt.Sprintf("%s 2>&1 | tee %s", binFile, logFile)
    
    result = shell(cmd)
    if result.ExitCode != 0 {
        i.logger.error("benchmark failed: %s", result.Stderr)
        return fmt.Errorf("benchmark failed")
    }
    
    i.logger.success("benchmark results saved to %s", logFile)
    return nil
}

// ============================================================
// Helper Functions
// ============================================================

func (i *InferenceOrchestrator) is_server_ready() bool {
    // Try to connect to server port
    result := exec_command("curl", "-s", fmt.Sprintf("http://localhost:%d/health", i.config.port))
    return result.ExitCode == 0
}

func (i *InferenceOrchestrator) log_config() {
    config := fmt.Sprintf(`Inference Configuration
Model: %s
Backend: %s
Batch Size: %d
Max Tokens: %d
Temperature: %.2f
Top-K: %d
Top-P: %.2f
Repetition Penalty: %.2f
KV Cache: %v
Speculative Decoding: %v
Server Port: %d
Log Directory: %s
`, i.config.modelPath, backend_string(i.config.backend), i.config.batchSize, i.config.maxTokens, 
   i.config.temperature, i.config.topK, i.config.topP, i.config.repetitionPenalty, 
   i.config.useCache, i.config.useSpectral, i.config.port, i.config.logDir)
    
    logFile := filepath.Join(i.config.logDir, "inference_config.txt")
    write_file(logFile, config)
}

func backend_string(backend InferenceBackend) string {
    switch backend {
    case InferenceBackend.ONNX:
        return "onnx"
    case InferenceBackend.TensorRT:
        return "tensorrt"
    case InferenceBackend.vLLM:
        return "vllm"
    case InferenceBackend.DeepSpeed:
        return "deepspeed"
    case InferenceBackend.Native:
        return "native"
    default:
        return "native"
    }
}

// ============================================================
// Public Inference Functions
// ============================================================

// run_inference_server starts an inference server
func run_inference_server(modelPath string) error {
    orchestrator, err := new_inference_orchestrator(modelPath)
    if err != nil {
        return err
    }
    
    if err := orchestrator.setup(); err != nil {
        return err
    }
    
    return orchestrator.start_server()
}

// run_interactive_inference starts interactive inference
func run_interactive_inference(modelPath string) error {
    orchestrator, err := new_inference_orchestrator(modelPath)
    if err != nil {
        return err
    }
    
    if err := orchestrator.setup(); err != nil {
        return err
    }
    
    return orchestrator.interactive()
}

// run_chat_interface starts the chat interface
func run_chat_interface(modelPath string) error {
    orchestrator, err := new_inference_orchestrator(modelPath)
    if err != nil {
        return err
    }
    
    if err := orchestrator.setup(); err != nil {
        return err
    }
    
    return orchestrator.chat()
}

// run_inference_benchmark runs inference benchmarks
func run_inference_benchmark(modelPath string) error {
    orchestrator, err := new_inference_orchestrator(modelPath)
    if err != nil {
        return err
    }
    
    if err := orchestrator.setup(); err != nil {
        return err
    }
    
    return orchestrator.benchmark()
}
