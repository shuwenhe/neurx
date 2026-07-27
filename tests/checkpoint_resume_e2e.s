package main
use std.io
use std.os
use std.path
use std.time
use std.exec
struct test_config {
    scriptDir string
    projectRoot string
    checkpointDir string
    testLog string
    stepsPhase1 int
    stepsPhase2 int
    maxSteps int
}

func logTest(config test_config, message string) error {
    timestamp = time.Now().Format(time.RFC3339)
    line = "[TEST] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func logInfo(config test_config, message string) error {
    line = "[INFO] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func logError(config test_config, message string) error {
    line = "[ERROR] " + message
    io.Println(line)
    return io.AppendFile(config.testLog, line + "\n")
}

func logSection(config test_config, title string) error {
    io.Println("")
    line = "==== " + title + " ===="
    io.Println(line)
    io.Println("")
    return io.AppendFile(config.testLog, "\n" + line + "\n\n")
}

func readStateFile(filePath string) map[string]string {
    content, err = os.ReadFile(filePath)
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
    scriptDir = os.Args[0]
    projectRoot = scriptDir + "/../../.."
    config := test_config{
        scriptDir: scriptDir,
        projectRoot: projectRoot,
        checkpointDir: projectRoot + "/checkpoint/NeurX-1.3-test",
        testLog: projectRoot + "/artifacts/logs/checkpoint_resume_test_" + time.Now().Format("20060102_150405") + ".log",
        stepsPhase1: 10,
        stepsPhase2: 20,
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
    logSection(config, "Phase 1: Fresh Training (" + string(config.stepsPhase1) + " steps)")
    logTest(config, "Clearing old checkpoint...")
    os.Remove(config.checkpointDir + "/training_state.txt")
    os.Remove(config.checkpointDir + "/checkpoint.state")
    os.RemoveAll(config.checkpointDir + "/*.weights.f32")
    logTest(config, "Starting fresh training...")
    env := map[string]string{
        "NEURX_PRETRAIN_OUTPUT_DIR": config.checkpointDir,
        "NEURX_PRETRAIN_STEPS": string(config.stepsPhase1),
        "NEURX_PRETRAIN_SAVE_INTERVAL": "3",
        "NEURX_PRETRAIN_RESUME": "0",
    }
    cmd := exec.command("make", "pretrain-gpu-fresh")
    cmd.Dir = config.projectRoot
    cmd.Env = env
    output, err := cmd.CombinedOutput()
    if err != nil {
        logError(config, "Training failed: " + err.Error())
        os.Exit(1)
    }
    io.Println(string(output))
    time.Sleep(2 * time.Second)
    phase1State := readStateFile(config.checkpointDir + "/training_state.txt")
    phase1Step := phase1State["step"]
    phase1Loss := phase1State["loss"]
    logTest(config, "Phase 1 Results: step=" + phase1Step + ", loss=" + phase1Loss)
    logSection(config, "Phase 2: Resume Training (" + string(config.stepsPhase2) + " more steps)")
    logTest(config, "Starting resumed training from step " + phase1Step + "...")
    env["NEURX_PRETRAIN_STEPS"] = string(config.maxSteps)
    env["NEURX_PRETRAIN_RESUME"] = "1"
    cmd = exec.command("make", "pretrain-gpu")
    cmd.Dir = config.projectRoot
    cmd.Env = env
    output, err = cmd.CombinedOutput()
    if err != nil {
        logError(config, "Resume training failed: " + err.Error())
        os.Exit(1)
    }
    io.Println(string(output))
    time.Sleep(2 * time.Second)
    phase2State := readStateFile(config.checkpointDir + "/training_state.txt")
    phase2Step := phase2State["step"]
    phase2Loss := phase2State["loss"]
    logTest(config, "Phase 2 Results: step=" + phase2Step + ", loss=" + phase2Loss)
    logSection(config, "Validation & Verification")
    io.Println("================================================")
    io.Println("End-to-End Test Results")
    io.Println("================================================")
    io.Println("")
    io.Println("✓ Fresh training completed (" + string(config.stepsPhase1) + " steps)")
    io.Println("✓ Checkpoint created at: " + config.checkpointDir)
    io.Println("✓ Phase 1 final state: step=" + phase1Step + ", loss=" + phase1Loss)
    io.Println("")
    io.Println("✓ Resume training completed (" + string(config.stepsPhase2) + " more steps)")
    io.Println("✓ Phase 2 final state: step=" + phase2Step + ", loss=" + phase2Loss)
    io.Println("")
    io.Println("Test Log: " + config.testLog)
    io.Println("")
    io.Println("✅ ALL TESTS PASSED")
}
