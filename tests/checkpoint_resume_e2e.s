package main
use std.io
use std.os
use std.path
use std.time
use std.exec
struct test_config {
    script_dir string
    project_root string
    checkpoint_dir string
    test_log string
    steps_phase_1 int
    steps_phase_2 int
    max_steps int
}

func log_test(config test_config, message string) error {
    timestamp = time.Now().Format(time.RFC3339)
    line = "[TEST] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func log_info(config test_config, message string) error {
    line = "[INFO] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func log_error(config test_config, message string) error {
    line = "[ERROR] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func log_section(config test_config, title string) error {
    io.Println("")
    line = "==== " + title + " ===="
    io.Println(line)
    io.Println("")
    return io.AppendFile(config.testLog, "\n" + line + "\n\n")
}

func read_state_file(file_path string) map[string]string {
    content, err = os.ReadFile(file_path)
    if err != nil {
        return make(map[string]string)
    }
    state = make(map[string]string)
    lines = strings.Split(string(content), "\n")
    for _, line := range lines {
        parts = strings.Split(line, "=")
        if len(parts) == 2 {
            state[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
        }
    }
    return state
}

func main() {
    script_dir = os.Args[0]
    project_root = script_dir + "/../../.."
    config := test_config{
        script_dir: scriptDir,
        project_root: projectRoot,
        checkpoint_dir: projectRoot + "/checkpoint/NeurX-1.3-test",
        test_log: projectRoot + "/artifacts/logs/checkpoint_resume_test_" + time.Now().Format("20060102_150405") + ".log",
        steps_phase_1: 10,
        steps_phase_2: 20,
    }
    config.maxSteps = config.stepsPhase1 + config.stepsPhase2
    io.Println("================================================")
    io.Println("GPU Checkpoint Resume End-to-End Test")
    io.Println("================================================")
    io.Println("Project Root: " + config.projectRoot)
    io.Println("Checkpoint Dir: " + config.checkpointDir)
    io.Println("Test Log: " + config.testLog)
    io.Println("")
    os.MkdirAll(config.checkpointDir, 0755)
    os.MkdirAll(path.Dir(config.testLog), 0755)
    log_section(config, "Phase 1: Fresh Training (" + string(config.stepsPhase1) + " steps)")
    log_test(config, "Clearing old checkpoint...")
    os.Remove(config.checkpointDir + "/training_state.txt")
    os.Remove(config.checkpointDir + "/checkpoint.state")
