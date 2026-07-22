

package main

import (
    "fmt"
    "os"
    "strconv"
    "../scripts"
)

struct Command {
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
    numGpus := 1
    if len(args) > 1 {
        if n, err := strconv.Atoi(args[1]); err == nil {
            numGpus = n
        }
    }

    return scripts.run_foundation_model_training(scale, numGpus)
}

func cmd_quick_start(args []string) error {
    logger := scripts.new_logger("CLI")
    logger.log("Starting quick training (mini scale, 1 GPU)...")
    return scripts.start_quick_training()
}

func cmd_launch_70b(args []string) error {
    numGpus := 512
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            numGpus = n
        }
    }
    return scripts.launch_70b_training(numGpus)
}

func cmd_launch_7b(args []string) error {
    numGpus := 64
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            numGpus = n
        }
    }
    return scripts.launch_7b_training(numGpus)
}

func cmd_launch_1t(args []string) error {
    numGpus := 1024
    if len(args) > 0 {
        if n, err := strconv.Atoi(args[0]); err == nil {
            numGpus = n
        }
    }
    return scripts.launch_1t_training(numGpus)
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
    modelPath := "model.bin"
    if len(args) > 0 {
        modelPath = args[0]
    }
    return scripts.run_chat_interface(modelPath)
}

func cmd_benchmark(args []string) error {
    modelPath := "model.bin"
    if len(args) > 0 {
        modelPath = args[0]
    }
    return scripts.run_inference_benchmark(modelPath)
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
    logger := scripts.new_logger("Status")

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

var commands = []Command{

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

func find_command(name string) *Command {
    for i := 0; i < len(commands); i++ {
        if commands[i].name == name {
            return &commands[i]
        }
    }
    return nil
}

func show_help() {
    fmt.Println(`╔════════════════════════════════════════════════════════════╗
║                   NeurX CLI - Main Interface                ║
║                                                              ║
║  Unified command-line tool replacing 159+ shell scripts    ║
║  Provides: Training, Building, Inference, and Utilities    ║
╚════════════════════════════════════════════════════════════╝

TRAINING COMMANDS:
  neurx train <scale> [num_gpus]
    Start foundation model training
    Scales: mini, small, medium, large, xl
    Example: neurx train large 64

  neurx quick-start
    Quick training with mini scale (1 GPU, great for testing)

  neurx launch-70b [num_gpus]
    Launch 70B model training (default: 512 GPUs)

  neurx launch-7b [num_gpus]
    Launch 7B model training (default: 64 GPUs)

  neurx launch-1t [num_gpus]
    Launch 1T+ model training (default: 1024 GPUs)

BUILD COMMANDS:
  neurx build
    Build all components

  neurx build-quick
    Quick build of core components only

  neurx build-clean
    Clean all artifacts and rebuild

INFERENCE COMMANDS:
  neurx inference <model_path>
    Start inference server

  neurx chat [model_path]
    Start interactive chat interface

  neurx benchmark [model_path]
    Run inference benchmarks

UTILITIES:
  neurx status
    Show project status and configuration

  neurx version
    Show version information

  neurx help [command]
    Show help for specific command

ENVIRONMENT VARIABLES:
  NEURX_ROOT        Root directory of NeurX project
  S_COMPILER        Path to S language compiler
  NEURX_GPUS        Number of GPUs to use
  NEURX_BATCH_SIZE  Batch size for training
  NEURX_LOG_DIR     Directory for logs

EXAMPLES:
  # Quick test on single GPU
  $ neurx quick-start

  # Full 70B training on 512 GPUs
  $ neurx launch-70b 512

  # Build everything from scratch
  $ neurx build-clean

  # Start inference server
  $ neurx inference ./model.bin

For more information, visit: https://github.com/neurx/neurx
`)
}

func show_detailed_help(cmd string) {
    command := find_command(cmd)
    if command == nil {
        fmt.Printf("Unknown command: %s\n", cmd)
        return
    }

    fmt.Printf("Command: %s\n", command.name)
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

    cmdName := args[0]

    if cmdName == "help" && len(args) > 1 {
        show_detailed_help(args[1])
        return
    }

    cmd := find_command(cmdName)
    if cmd == nil {
        logger.error("Unknown command: %s", cmdName)
        logger.log("Use 'neurx help' for usage information")
        os.Exit(1)
    }

    var cmdArgs []string
    if len(args) > 1 {
        cmdArgs = args[1:]
    }

    if err := cmd.handler(cmdArgs); err != nil {
        logger.error("Command failed: %v", err)
        os.Exit(1)
    }
}
