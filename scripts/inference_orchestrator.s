package scripts
import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)
enum InferenceBackend {
    ONNX,
    TensorRT,
    vLLM,
    DeepSpeed,
    Native,
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
    useSpectral  bool
    port         int
    logDir       string
}

struct inference_orchestrator {
    logger  logger_2
    config  inference_config
    sCompiler string
    neurxRoot string
}

func new_inference_orchestrator(modelPath string) (*inference_orchestrator, error) {
    logger := new_logger("inference_orchestrator")
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
    return &inference_orchestrator{
        logger:    logger,
        config:    config,
        sCompiler: sCompiler,
        neurxRoot: neurxRoot,
    }, nil
}
func (i *inference_orchestrator) setup() error {
    i.logger.log("Setting up inference environment...")
    if err := mkdir(i.config.logDir); err != nil {
        return err
    }
    i.log_config()
    return nil
}
func (i *inference_orchestrator) Compile() error {
    i.logger.log("Compiling inference server...")
    buildDir := filepath.Join(i.neurxRoot, ".build", "inference")
    if err := mkdir(buildDir); err != nil {
        return err
    }
    irFile := filepath.Join(buildDir, "inference_server.ir")
    binFile := filepath.Join(buildDir, "inference_server")
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
func (i *inference_orchestrator) start_server() error {
    i.logger.log("Starting inference server...")
    binFile := filepath.Join(i.neurxRoot, ".build", "inference", "inference_server")
    if !file_exists(binFile) {
        if err := i.Compile(); err != nil {
            return err
        }
    }
    logFile := filepath.Join(i.config.logDir, "inference_server.log")
    cmd := fmt.Sprintf("cd %s && ", i.neurxRoot)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.modelPath)
    cmd += fmt.Sprintf("NEURX_BACKEND=%s ", backend_string(i.config.backend))
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", i.config.batchSize)
    cmd += fmt.Sprintf("NEURX_MAX_TOKENS=%d ", i.config.maxTokens)
    cmd += fmt.Sprintf("NEURX_PORT=%d ", i.config.port)
    cmd += fmt.Sprintf("%s 2>&1 | tee %s", binFile, logFile)
    i.logger.log("exec_commanduting: %s", cmd)
    go func() {
        result := shell(cmd)
        if result.ExitCode != 0 {
            i.logger.error("Server failed: %s", result.Stderr)
        }
    }()
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
func (i *inference_orchestrator) interactive() error {
    i.logger.log("Starting interactive inference session...")
    binFile := filepath.Join(i.neurxRoot, ".build", "inference", "inference_interactive")
    if !file_exists(binFile) {
        i.logger.log("Building interactive inference...")
    }
    result := shell(binFile)
    if result.ExitCode != 0 {
        i.logger.error("Session failed: %s", result.Stderr)
        return fmt.Errorf("inference session failed")
    }
    return nil
}
func (i *inference_orchestrator) chat() error {
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
    i.logger.log("Compiling chat tool...")
    result := exec_command(i.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    result = exec_command(i.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
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
func (i *inference_orchestrator) benchmark() error {
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
    i.logger.log("Compiling benchmark tool...")
    result := exec_command(i.sCompiler, sourceFile, irFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    result = exec_command(i.sCompiler, "--emit-bin", irFile, binFile)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
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
func (i *inference_orchestrator) is_server_ready() bool {
    result := exec_command("curl", "-s", fmt.Sprintf("http:
    return result.ExitCode == 0
}
func (i *inference_orchestrator) log_config() {
    config := fmt.Sprintf(`Inference Configuration
model: %s
Backend: %s
batch_2 Size: %d
Max Tokens: %d
Temperature: %.2f
Top-K: %d
Top-P: %.2f
Repetition Penalty: %.2f
KV cache: %v
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
