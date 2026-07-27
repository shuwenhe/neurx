package scripts
import (
    "fmt"
    "os"
    "path/filepath"
    "runtime"
)
enum BuildTarget {
    CPU,
    CUDA,
    HIP,
    Metal,
    OneAPI,
    CANN,
}
enum BuildArch {
    X86_64,
    ARM64,
}

struct build_config {
    target        BuildTarget
    arch          BuildArch
    optimization  bool
    debug         bool
    tests         bool
    documentation bool
    clean         bool
    parallel      int
}

struct build_orchestrator {
    logger      Logger
    config      build_config
    neurxRoot   string
    sRoot       string
    buildDir    string
}

func new_build_orchestrator() (*build_orchestrator, error) {
    logger := new_logger("build_orchestrator")
    neurxRoot := get_env("NEURX_ROOT", "")
    if neurxRoot == "" {
        pwd, _ := os.Getwd()
        neurxRoot = pwd
    }
    sRoot := filepath.Join(neurxRoot, "..", "s")
    buildDir := filepath.Join(neurxRoot, ".build")
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
        neurxRoot: neurxRoot,
        sRoot:     sRoot,
        buildDir:  buildDir,
    }, nil
}

func (b *build_orchestrator) setup() error {
    b.logger.log("Setting up build environment...")
    if err := mkdir(b.buildDir); err != nil {
        return err
    }
    b.log_config()
    return nil
}

func (b *build_orchestrator) Clean() error {
    b.logger.log("Cleaning build artifacts...")
    if err := remove_dir(b.buildDir); err != nil {
        b.logger.warn("Failed to clean build directory: %v", err)
    }
    components := []string{"core", "training", "inference", "distributed"}
    for _, comp := range components {
        compDir := filepath.Join(b.neurxRoot, comp)
        if dir_exists(compDir) {
            files, _ := find_build_artifacts(compDir)
            for _, file := range files {
                remove_file(file)
            }
        }
    }
    b.logger.success("Build artifacts cleaned")
    return nil
}

func (b *build_orchestrator) build_compiler() error {
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

func (b *build_orchestrator) build_core() error {
    b.logger.log("Building core NeurX components...")
    components := []string{
        "core/tensor.s",
        "core/autograd.s",
        "tokenizer/model_bpe.s",
        "optimizer/adamw.s",
    }
    sCompiler := b.get_s_compiler()
    for _, comp := range components {
        compPath := filepath.Join(b.neurxRoot, comp)
        if !file_exists(compPath) {
            b.logger.warn("Component not found: %s", compPath)
            continue
        }
        outFile := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(sCompiler, compPath, outFile)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (b *build_orchestrator) build_training() error {
    b.logger.log("Building training components...")
    components := []string{
        "training/train_loop.s",
        "training/checkpoint.s",
        "training/validator.s",
        "distributed/training_coordinator.s",
    }
    sCompiler := b.get_s_compiler()
    for _, comp := range components {
        compPath := filepath.Join(b.neurxRoot, comp)
        if !file_exists(compPath) {
            b.logger.warn("Component not found: %s", compPath)
            continue
        }
        outFile := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(sCompiler, compPath, outFile)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (b *build_orchestrator) build_inference() error {
    b.logger.log("Building inference components...")
    components := []string{
        "infer/inference_server.s",
        "infer/kv_cache_manager.s",
        "serving/speculative_decoding.s",
    }
    sCompiler := b.get_s_compiler()
    for _, comp := range components {
        compPath := filepath.Join(b.neurxRoot, comp)
        if !file_exists(compPath) {
            b.logger.warn("Component not found: %s", compPath)
            continue
        }
        outFile := filepath.Join(b.buildDir, filepath.Base(comp) + ".ir")
        b.logger.log("Building %s...", filepath.Base(comp))
        result := exec_command(sCompiler, compPath, outFile)
        if result.ExitCode != 0 {
            b.logger.error("Failed to build %s: %s", filepath.Base(comp), result.Stderr)
            return fmt.Errorf("build failed for %s", comp)
        }
        b.logger.success("Built %s", filepath.Base(comp))
    }
    return nil
}

func (b *build_orchestrator) BuildAll() error {
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

func (b *build_orchestrator) run_tests() error {
    if !b.config.tests {
        b.logger.log("Tests disabled")
        return nil
    }
    b.logger.log("Running build tests...")
    testDir := filepath.Join(b.neurxRoot, "tests")
    if !dir_exists(testDir) {
        b.logger.warn("Tests directory not found")
        return nil
    }
    result := exec_in_dir(testDir, "make", "test")
    if result.ExitCode != 0 {
        b.logger.error("Tests failed: %s", result.Stderr)
        return fmt.Errorf("tests failed")
    }
    b.logger.success("Tests passed")
    return nil
}

func (b *build_orchestrator) get_s_compiler() string {
    if command_exists("s") {
        return "s"
    }
    return filepath.Join(b.sRoot, ".local", "bin", "s")
}

func (b *build_orchestrator) log_config() {
    config := fmt.Sprintf(`NeurX Build Configuration
Target: %s
Architecture: %s
Optimization: %v
Debug: %v
Tests: %v
Documentation: %v
Parallel Jobs: %d
Build Directory: %s
`, target_string(b.config.target), arch_string(b.config.arch), b.config.optimization, b.config.debug, b.config.tests, b.config.documentation, b.config.parallel, b.buildDir)
    logFile := filepath.Join(b.buildDir, "build_config.txt")
    write_file(logFile, config)
}

func target_string(t BuildTarget) string {
    switch t {
    case BuildTarget.CPU:
        return "CPU"
    case BuildTarget.CUDA:
        return "CUDA"
    case BuildTarget.HIP:
        return "HIP (AMD)"
    case BuildTarget.Metal:
        return "Metal (Apple)"
    case BuildTarget.OneAPI:
        return "OneAPI (Intel)"
    case BuildTarget.CANN:
        return "CANN (Huawei)"
    default:
        return "Unknown"
    }
}

func arch_string(a BuildArch) string {
    switch a {
    case BuildArch.X86_64:
        return "x86_64"
    case BuildArch.ARM64:
        return "ARM64"
    default:
        return "Unknown"
    }
}

func detect_build_target() BuildTarget {
    if command_exists("nvidia-smi") {
        return BuildTarget.CUDA
    }
    if command_exists("rocm-smi") {
        return BuildTarget.HIP
    }
    if runtime.GOOS == "darwin" {
        return BuildTarget.Metal
    }
    if command_exists("xpumanager") {
        return BuildTarget.OneAPI
    }
    return BuildTarget.CPU
}

func detect_build_arch() BuildArch {
    switch runtime.GOARCH {
    case "amd64":
        return BuildArch.X86_64
    case "arm64":
        return BuildArch.ARM64
    default:
        return BuildArch.X86_64
    }
}

func find_build_artifacts(dir string) ([]string, error) {
    var artifacts []string
    files, _ := list_dir(dir)
    for _, file := range files {
        fullPath := filepath.Join(dir, file)
        if strings.HasSuffix(file, ".o") || strings.HasSuffix(file, ".ir") || strings.HasSuffix(file, ".o.d") {
            artifacts = append(artifacts, fullPath)
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
