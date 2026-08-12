package scripts
import (
    "fmt"
    "os"
    "path/filepath"
    "strings"
)
enum inference_backend {
    ONNX,
    tensor_rt,
    v_llm,
    deep_speed,
    native,
}

struct inference_config {
    model_path    string
    backend      inference_backend
    batch_size    int
    max_tokens    int
    temperature  float32
    top_k         int
    top_p         float32
    repetition_penalty float32
    use_cache     bool
    use_spectral  bool
    port         int
    log_dir       string
}

struct inference_orchestrator {
    logger  logger_2
    config  inference_config
    s_compiler string
    neurx_root string
}

func new_inference_orchestrator(string model_path) (*inference_orchestrator, error) {
    logger := new_logger("inference_orchestrator")
    neurx_root := get_env("NEURX_ROOT", "")
    if neurx_root == "" {
        pwd, _ := os.Getwd()
        neurx_root = pwd
    }
    s_compiler := get_env("S_COMPILER", "s")
    if !command_exists(s_compiler) {
        s_compiler = filepath.Join(neurx_root, "..", "s", ".local", "bin", "s")
    }
    if !file_exists(model_path) {
        return nil, fmt.Errorf("model not found at %s", model_path)
    }
    config := inference_config{
        model_path:        model_path,
        backend:          inference_backend.native,
        batch_size:        1,
        max_tokens:        2048,
        temperature:      0.8,
        top_k:             40,
        top_p:             0.95,
        repetition_penalty: 1.0,
        use_cache:         true,
        use_spectral:      false,
        port:             8000,
        log_dir:           filepath.Join(neurx_root, "logs", "inference"),
    }
    return &inference_orchestrator{
        logger:    logger,
        config:    config,
        s_compiler: s_compiler,
        neurx_root: neurx_root,
    }, nil
}

func (i *inference_orchestrator) setup() error {
    i.logger.log("Setting up inference environment...")
    if err := mkdir(i.config.log_dir); err != nil {
        return err
    }
    i.log_config()
    return nil
}

func (i *inference_orchestrator) compile() error {
    i.logger.log("Compiling inference server...")
    build_dir := filepath.Join(i.neurx_root, ".build", "inference")
    if err := mkdir(build_dir); err != nil {
        return err
    }
    ir_file := filepath.Join(build_dir, "inference_server.ir")
    bin_file := filepath.Join(build_dir, "inference_server")
    source_file := filepath.Join(i.neurx_root, "infer", "inference_server.s")
    if !file_exists(source_file) {
        i.logger.warn("Inference server source not found at %s", source_file)
        return fmt.Errorf("inference source not found")
    }
    i.logger.log("Compiling to IR...")
    result := exec_command(i.s_compiler, source_file, ir_file)
    if result.ExitCode != 0 {
        i.logger.error("Compilation failed: %s", result.Stderr)
        return fmt.Errorf("compilation failed")
    }
    i.logger.log("Generating binary...")
    result = exec_command(i.s_compiler, "--emit-bin", ir_file, bin_file)
    if result.ExitCode != 0 {
        i.logger.error("Binary generation failed: %s", result.Stderr)
        return fmt.Errorf("binary generation failed")
    }
    i.logger.success("Inference server compiled: %s", bin_file)
    return nil
}

func (i *inference_orchestrator) start_server() error {
    i.logger.log("Starting inference server...")
    bin_file := filepath.Join(i.neurx_root, ".build", "inference", "inference_server")
    if !file_exists(bin_file) {
        if err := i.compile(); err != nil {
            return err
        }
    }
    log_file := filepath.Join(i.config.log_dir, "inference_server.log")
    cmd := fmt.Sprintf("cd %s && ", i.neurx_root)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.model_path)
    cmd += fmt.Sprintf("NEURX_BACKEND=%s ", backend_string(i.config.backend))
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", i.config.batch_size)
    cmd += fmt.Sprintf("NEURX_MAX_TOKENS=%d ", i.config.max_tokens)
    cmd += fmt.Sprintf("NEURX_PORT=%d ", i.config.port)
    cmd += fmt.Sprintf("%s 2>&1 | tee %s", bin_file, log_file)
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
    bin_file := filepath.Join(i.neurx_root, ".build", "inference", "inference_interactive")
    if !file_exists(bin_file) {
        i.logger.log("Building interactive inference...")
    }
    result := shell(bin_file)
    if result.ExitCode != 0 {
        i.logger.error("Session failed: %s", result.Stderr)
        return fmt.Errorf("inference session failed")
    }
    return nil
}

func (i *inference_orchestrator) chat() error {
    i.logger.log("Starting chat interface...")
    source_file := filepath.Join(i.neurx_root, "tools", "chat.s")
    if !file_exists(source_file) {
        return fmt.Errorf("chat tool not found")
    }
    build_dir := filepath.Join(i.neurx_root, ".build", "chat")
    if err := mkdir(build_dir); err != nil {
        return err
    }
    bin_file := filepath.Join(build_dir, "chat")
    ir_file := filepath.Join(build_dir, "chat.ir")
    i.logger.log("Compiling chat tool...")
    result := exec_command(i.s_compiler, source_file, ir_file)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    result = exec_command(i.s_compiler, "--emit-bin", ir_file, bin_file)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
    cmd := fmt.Sprintf("cd %s && ", i.neurx_root)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.model_path)
    cmd += fmt.Sprintf("NEURX_BACKEND=%s ", backend_string(i.config.backend))
    cmd += fmt.Sprintf("NEURX_MAX_TOKENS=%d ", i.config.max_tokens)
    cmd += bin_file
    result = shell(cmd)
    if result.ExitCode != 0 {
        return fmt.Errorf("chat failed")
    }
    return nil
}

func (i *inference_orchestrator) benchmark() error {
    i.logger.log("Running inference benchmarks...")
    source_file := filepath.Join(i.neurx_root, "eval", "benchmark_eval.s")
    if !file_exists(source_file) {
        return fmt.Errorf("benchmark tool not found")
    }
    build_dir := filepath.Join(i.neurx_root, ".build", "benchmark")
    if err := mkdir(build_dir); err != nil {
        return err
    }
    bin_file := filepath.Join(build_dir, "benchmark")
    ir_file := filepath.Join(build_dir, "benchmark.ir")
    i.logger.log("Compiling benchmark tool...")
    result := exec_command(i.s_compiler, source_file, ir_file)
    if result.ExitCode != 0 {
        return fmt.Errorf("compilation failed")
    }
    result = exec_command(i.s_compiler, "--emit-bin", ir_file, bin_file)
    if result.ExitCode != 0 {
        return fmt.Errorf("binary generation failed")
    }
    log_file := filepath.Join(i.config.log_dir, "benchmark.log")
    cmd := fmt.Sprintf("cd %s && ", i.neurx_root)
    cmd += fmt.Sprintf("NEURX_MODEL=%s ", i.config.model_path)
    cmd += fmt.Sprintf("NEURX_BATCH_SIZE=%d ", i.config.batch_size)
    cmd += fmt.Sprintf("%s 2>&1 | tee %s", bin_file, log_file)
    result = shell(cmd)
    if result.ExitCode != 0 {
        i.logger.error("benchmark failed: %s", result.Stderr)
        return fmt.Errorf("benchmark failed")
    }
    i.logger.success("benchmark results saved to %s", log_file)
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
`, i.config.model_path, backend_string(i.config.backend), i.config.batch_size, i.config.max_tokens,
   i.config.temperature, i.config.top_k, i.config.top_p, i.config.repetition_penalty,
   i.config.use_cache, i.config.use_spectral, i.config.port, i.config.log_dir)
    log_file := filepath.Join(i.config.log_dir, "inference_config.txt")
    write_file(log_file, config)
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

func run_inference_server(string model_path) error {
    orchestrator, err := new_inference_orchestrator(model_path)
    if err != nil {
        return err
    }
    if err := orchestrator.setup(); err != nil {
        return err
    }
    return orchestrator.start_server()
}

func run_interactive_inference(string model_path) error {
    orchestrator, err := new_inference_orchestrator(model_path)
    if err != nil {
        return err
    }
    if err := orchestrator.setup(); err != nil {
        return err
    }
    return orchestrator.interactive()
}

func run_chat_interface(string model_path) error {
    orchestrator, err := new_inference_orchestrator(model_path)
    if err != nil {
        return err
    }
    if err := orchestrator.setup(); err != nil {
        return err
    }
    return orchestrator.chat()
}

func run_inference_benchmark(string model_path) error {
    orchestrator, err := new_inference_orchestrator(model_path)
    if err != nil {
        return err
    }
    if err := orchestrator.setup(); err != nil {
        return err
    }
    return orchestrator.benchmark()
}

