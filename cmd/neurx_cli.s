package main
import (
    "fmt"
    "os"
    "strconv"
    "../scripts"
)
struct command {
    name        string
    description string
    usage       string
    handler     func([]string) error
}
func cmd_train(args []string) error {
    if len(args) == 0 {
        fmt.Println("Usage: neurx train <scale> [num_gpus]")
        fmt.Println("Scales: mini, small, medium, large, xl")
        return nil
    }
    scale := args[0]
    num_gpus := 1
    if len(args) > 1 {
        if n, err := strconv.Atoi(args[1]); err == nil {
            num_gpus = n
        }
    }
    return scripts.run_foundation_model_training(scale, num_gpus)
}
func cmd_quick_start(args []string) error {
    logger := scripts.new_logger("CLI")
    logger.log("Starting quick training (mini scale, 1 GPU)...")
    return scripts.start_quick_training()
}
func cmd_launch_70b(args []string) error {
    num_gpus := 512
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            num_gpus = n
        }
    }
    return scripts.launch_70b_training(num_gpus)
}
func cmd_launch_7b(args []string) error {
    num_gpus := 64
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            num_gpus = n
        }
    }
    return scripts.launch_7b_training(num_gpus)
}
func cmd_launch_1t(args []string) error {
    num_gpus := 1024
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            num_gpus = n
        }
    }
    return scripts.launch_1t_training(num_gpus)
}
func cmd_build(args []string) error {
    return scripts.build_everything()
}
func cmd_build_quick(args []string) error {
    return scripts.quick_build()
}
func cmd_build_clean(args []string) error {
    return scripts.clean_build()
}
func cmd_inference(args []string) error {
    if len(args) == 0 {
        fmt.Println("Usage: neurx inference <model_path>")
        return nil
    }
    return scripts.run_inference_server(args[0])
}
func cmd_chat(args []string) error {
    model_path := "model.bin"
    if len(args) > 0 {
        model_path = args[0]
    }
    return scripts.run_chat_interface(model_path)
}
func cmd_benchmark(args []string) error {
    model_path := "model.bin"
    if len(args) > 0 {
        model_path = args[0]
    }
    return scripts.run_inference_benchmark(model_path)
}
func cmd_version(args []string) error {
    fmt.Println("NeurX CLI v1.0.0")
    fmt.Println("S Language Implementation")
    return nil
}
func cmd_help(args []string) error {
    show_help()
    return nil
}
func cmd_status(args []string) error {
    logger := scripts.new_logger("status")
    if scripts.dir_exists(".build") {
        logger.success("Build artifacts found")
    } else {
        logger.warn("No build artifacts found")
    }
    if scripts.dir_exists("checkpoints") {
        logger.success("Checkpoints directory found")
    } else {
        logger.warn("No checkpoints found")
    }
    if scripts.dir_exists("logs") {
        logger.success("Logs directory found")
    } else {
        logger.warn("No logs found")
    }
    return nil
}
var commands = []command{
    {
        name:        "train",
        description: "Start foundation model training",
        usage:       "neurx train <scale> [num_gpus]",
        handler:     cmd_train,
    },
    {
        name:        "quick-start",
        description: "Quick training with mini scale",
        usage:       "neurx quick-start",
        handler:     cmd_quick_start,
    },
    {
        name:        "launch-70b",
        description: "Launch 70B model training",
        usage:       "neurx launch-70b [num_gpus]",
        handler:     cmd_launch_70b,
    },
    {
        name:        "launch-7b",
        description: "Launch 7B model training",
        usage:       "neurx launch-7b [num_gpus]",
        handler:     cmd_launch_7b,
    },
    {
        name:        "launch-1t",
        description: "Launch 1T+ model training",
        usage:       "neurx launch-1t [num_gpus]",
        handler:     cmd_launch_1t,
    },
    {
        name:        "build",
        description: "Build all components",
        usage:       "neurx build",
        handler:     cmd_build,
    },
    {
        name:        "build-quick",
        description: "Quick build of core components",
        usage:       "neurx build-quick",
        handler:     cmd_build_quick,
    },
    {
        name:        "build-clean",
        description: "Clean build (remove and rebuild)",
        usage:       "neurx build-clean",
        handler:     cmd_build_clean,
    },
    {
        name:        "inference",
        description: "Start inference server",
        usage:       "neurx inference <model_path>",
        handler:     cmd_inference,
    },
    {
        name:        "chat",
        description: "Start chat interface",
        usage:       "neurx chat [model_path]",
        handler:     cmd_chat,
    },
    {
        name:        "benchmark",
        description: "Run inference benchmarks",
        usage:       "neurx benchmark [model_path]",
        handler:     cmd_benchmark,
    },
    {
        name:        "version",
        description: "Show version information",
        usage:       "neurx version",
        handler:     cmd_version,
    },
    {
        name:        "status",
        description: "Show project status",
        usage:       "neurx status",
        handler:     cmd_status,
    },
    {
        name:        "help",
        description: "Show this help message",
        usage:       "neurx help [command]",
        handler:     cmd_help,
    },
}
func find_command(name string) *command {
    for i := 0; i < len(commands); i++ {
        if commands[i].name == name {
            return &commands[i]
        }
    }
    return nil
}
func show_help() {
    fmt.Println(`╔════════════════════════════════════════════════════════════╗
║                   neur_x CLI - main interface                ║
║                                                              ║
║  unified command-line tool replacing 159+ shell scripts    ║
║  provides: Training, building, inference, and utilities    ║
╚════════════════════════════════════════════════════════════╝
TRAINING COMMANDS:
  neurx train <scale> [num_gpus]
    start foundation model training
    scales: mini, small, medium, large, xl
    example: neurx train large 64
  neurx quick-start
    quick training with mini scale (1 GPU, great for testing)
  neurx launch-70b [num_gpus]
    launch 70B model training (default: 512 gp_us)
  neurx launch-7b [num_gpus]
    launch 7B model training (default: 64 gp_us)
  neurx launch-1t [num_gpus]
    launch 1T+ model training (default: 1024 gp_us)
BUILD COMMANDS:
  neurx build
    build all components
  neurx build-quick
    quick build of core components only
  neurx build-clean
    clean all artifacts and rebuild
INFERENCE COMMANDS:
  neurx inference <model_path>
    Start inference server
  neurx chat [model_path]
    start interactive chat interface
  neurx benchmark [model_path]
    run inference benchmarks
UTILITIES:
  neurx status
    show project status and configuration
  neurx version
    show version information
  neurx help [command]
    show help for specific command
ENVIRONMENT VARIABLES:
  NEURX_ROOT        root directory of neur_x project
  S_COMPILER        path to S language compiler
  NEURX_GPUS        number of gp_us to use
  NEURX_BATCH_SIZE  batch_2 size for training
  NEURX_LOG_DIR     directory for logs
EXAMPLES:
  $ neurx quick-start
  $ neurx launch-70b 512
  $ neurx build-clean
  $ neurx inference ./model.bin
for more information, visit: https:
`)
}
func show_detailed_help(cmd string) {
    command := find_command(cmd)
    if command == nil {
        fmt.Printf("Unknown command: %s\n", cmd)
        return
    }
    fmt.Printf("command: %s\n", command.name)
    fmt.Printf("Description: %s\n", command.description)
    fmt.Printf("Usage: %s\n", command.usage)
}
func main() {
    logger := scripts.new_logger("CLI")
    args := os.Args[1:]
    if len(args) == 0 {
        show_help()
        return
    }
    cmd_name := args[0]
    if cmd_name == "help" && len(args) > 1 {
        show_detailed_help(args[1])
        return
    }
    cmd := find_command(cmd_name)
    if cmd == nil {
        logger.error("Unknown command: %s", cmd_name)
        logger.log("Use 'neurx help' for usage information")
        os.Exit(1)
    }
    var cmd_args []string
    if len(args) > 1 {
        cmd_args = args[1:]
    }
    if err := cmd.handler(cmd_args); err != nil {
        logger.error("command failed: %v", err)
        os.Exit(1)
    }
}
