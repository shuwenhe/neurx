package scripts
import (
    "fmt"
    "os"
    "path/filepath"
    "runtime"
)
enum build_target {
    CPU,
    CUDA,
    HIP,
    metal,
    one_api,
    CANN,
}

enum build_arch {
    X86_64,
    ARM64,
}

struct build_config {
    target        build_target
    arch          build_arch
    optimization  bool
    debug         bool
    tests         bool
    documentation bool
    clean         bool
    parallel      int
}

struct build_orchestrator {
    logger      logger_2
    config      build_config
    neurx_root   string
    s_root       string
    build_dir    string
}

func new_build_orchestrator() (*build_orchestrator, error) {
    logger := new_logger("build_orchestrator")
    neurx_root := get_env("NEURX_ROOT", "")
    if neurx_root == "" {
        pwd, _ := os.Getwd()
        neurx_root = pwd
    }
    s_root := filepath.Join(neurx_root, "..", "s")
    build_dir := filepath.Join(neurx_root, ".build")
    target := detect_build_target()
    arch := detect_build_arch()
    config := build_config{
        target:        target,
        arch:          arch,
        optimization:  true,
        debug:         false,
        tests:         true,
        documentation: false,
        clean:         false,
        parallel:      4,
    }
    return &build_orchestrator{
        logger:    logger,
        config:    config,
        neurx_root: neurxRoot,
        s_root:     sRoot,
        build_dir:  buildDir,
    }, nil
}

func (build_orchestrator* b) setup() error {
    b.logger.log("Setting up build environment...")
    if err := mkdir(b.buildDir); err != nil {
        return err
    }
    b.log_config()
    return nil
}

func (build_orchestrator* b) clean() error {
    b.logger.log("Cleaning build artifacts...")
    if err := remove_dir(b.buildDir); err != nil {
        b.logger.warn("Failed to clean build directory: %v", err)
    }
    components := []string{"core", "training", "inference", "distributed"}
    for _, comp := range components {
        comp_dir := filepath.Join(b.neurxRoot, comp)
        if dir_exists(comp_dir) {
            files, _ := find_build_artifacts(comp_dir)
            for _, file := range files {
                remove_file(file)
            }
        }
    }
    b.logger.success("Build artifacts cleaned")
    return nil
}

func (build_orchestrator* b) build_compiler() error {
    b.logger.log("Checking S compiler...")
    if !command_exists("s") && !file_exists(filepath.Join(b.sRoot, ".local", "bin", "s")) {
        b.logger.log("Building S compiler...")
        result := exec_in_dir(b.sRoot, "make", "-j", fmt.Sprintf("%d", b.config.parallel))
        if result.ExitCode != 0 {
            b.logger.error("Compiler build failed: %s", result.Stderr)
            return fmt.Errorf("compiler build failed")
        }
        b.logger.success("S compiler built successfully")
    } else {
        b.logger.success("S compiler already available")
    }
    return nil
}

func (build_orchestrator* b) build_core() error {
    b.logger.log("Building core NeurX components...")
    components := []string{
        "core/tensor.s",
        "core/autograd.s",
        "src/inference/extensions/tokenizer/model_bpe.s",
        "src/training/optimizer/adamw.s",
    }
    s_compiler := b.get_s_compiler()
    for _, comp := range components {
        comp_path := filepath.Join(b.neurxRoot, comp)
        if !file_exists(comp_path) {
            b.logger.warn("Component not found: %s", comp_path)
            continue
        }
        out_file := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(s_compiler, comp_path, out_file)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (build_orchestrator* b) build_training() error {
    b.logger.log("Building training components...")
    components := []string{
        "src/training/common/train_loop.s",
        "src/training/common/checkpoint.s",
        "src/training/common/validator.s",
        "src/runtime/distributed/training_coordinator.s",
    }
    s_compiler := b.get_s_compiler()
    for _, comp := range components {
        comp_path := filepath.Join(b.neurxRoot, comp)
        if !file_exists(comp_path) {
            b.logger.warn("Component not found: %s", comp_path)
            continue
        }
        out_file := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(s_compiler, comp_path, out_file)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (build_orchestrator* b) build_inference() error {
    b.logger.log("Building inference components...")
    components := []string{
        "infer/inference_server.s",
        "infer/kv_cache_manager.s",
        "src/serving/speculative_decoding.s",
    }
    s_compiler := b.get_s_compiler()
    for _, comp := range components {
        comp_path := filepath.Join(b.neurxRoot, comp)
        if !file_exists(comp_path) {
            b.logger.warn("Component not found: %s", comp_path)
            continue
        }
        out_file := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(s_compiler, comp_path, out_file)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (build_orchestrator* b) build_all() error {
    b.logger.log("Building all NeurX components...")
    if err := b.setup(); err != nil {
        return err
    }
    if err := b.build_compiler(); err != nil {
        return err
    }
    if err := b.build_core(); err != nil {
        return err
    }
    if err := b.build_training(); err != nil {
        return err
    }
    if err := b.build_inference(); err != nil {
        return err
    }
    b.logger.success("All components built successfully")
    return nil
}

func (build_orchestrator* b) run_tests() error {
    if !b.config.tests {
        b.logger.log("Tests disabled")
        return nil
    }
    b.logger.log("Running build tests...")
    test_dir := filepath.Join(b.neurxRoot, "tests")
    if !dir_exists(test_dir) {
        b.logger.warn("Tests directory not found")
        return nil
    }
    result := exec_in_dir(test_dir, "make", "test")
    if result.ExitCode != 0 {
        b.logger.error("Tests failed: %s", result.Stderr)
        return fmt.Errorf("tests failed")
    }
    b.logger.success("Tests passed")
    return nil
}

func (build_orchestrator* b) get_s_compiler() string {
    if command_exists("s") {
        return "s"
    }
    return filepath.Join(b.sRoot, ".local", "bin", "s")
}

func (build_orchestrator* b) log_config() {
    config := fmt.Sprintf(`neur_x build configuration
target: %s
architecture: %s
optimization: %v
debug: %v
tests: %v
documentation: %v
parallel jobs: %d
build directory: %s
`, target_string(b.config.target), arch_string(b.config.arch), b.config.optimization, b.config.debug, b.config.tests, b.config.documentation, b.config.parallel, b.buildDir)
    log_file := filepath.Join(b.buildDir, "build_config.txt")
    write_file(log_file, config)
}

func target_string(t build_target) string {
    switch t {
    case build_target.CPU:
        return "CPU"
    case build_target.CUDA:
        return "CUDA"
    case build_target.HIP:
        return "HIP (AMD)"
    case build_target.Metal:
        return "Metal (Apple)"
    case build_target.OneAPI:
        return "OneAPI (Intel)"
    case build_target.CANN:
        return "CANN (Huawei)"
    default:
        return "Unknown"
    }
}

func arch_string(a build_arch) string {
    switch a {
    case build_arch.X86_64:
        return "x86_64"
    case build_arch.ARM64:
        return "ARM64"
    default:
        return "Unknown"
    }
}

func detect_build_target() build_target {
    if command_exists("nvidia-smi") {
        return build_target.CUDA
    }
    if command_exists("rocm-smi") {
        return build_target.HIP
    }
    if runtime.GOOS == "darwin" {
        return build_target.Metal
    }
    if command_exists("xpumanager") {
        return build_target.OneAPI
    }
    return build_target.CPU
}

func detect_build_arch() build_arch {
    switch runtime.GOARCH {
    case "amd64":
        return build_arch.X86_64
    case "arm64":
        return build_arch.ARM64
    default:
        return build_arch.X86_64
    }
}

func find_build_artifacts(string dir) ([]string, error) {
    var artifacts []string
    files, _ := list_dir(dir)
    for _, file := range files {
        full_path := filepath.Join(dir, file)
        if strings.HasSuffix(file, ".o") || strings.HasSuffix(file, ".ir") || strings.HasSuffix(file, ".o.d") {
            artifacts = append(artifacts, full_path)
        }
    }
    return artifacts, nil
}

func build_everything() error {
    builder, err := new_build_orchestrator()
    if err != nil {
        return err
    }
    if builder.config.clean {
        if err := builder.Clean(); err != nil {
            return err
        }
    }
    return builder.BuildAll()
}

func quick_build() error {
    builder, err := new_build_orchestrator()
    if err != nil {
        return err
    }
    if err := builder.setup(); err != nil {
        return err
    }
    return builder.build_core()
}

func clean_build() error {
    builder, err := new_build_orchestrator()
    if err != nil {
        return err
    }
    builder.config.clean = true
    return builder.BuildAll()
}
