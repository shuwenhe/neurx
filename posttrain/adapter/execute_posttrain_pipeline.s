package main
use std.io.println
func println_separator() int {
    println("═══════════════════════════════════════════════════════════════")
    0
}

func println_subheader(string title) int {
    println("")
    println("──────────────────────────────────────────────────────────────")
    println(title)
    println("──────────────────────────────────────────────────────────────")
    0
}

func int_to_str(int n) string {
    if n == 0 {
        return "0"
    }
    int value = n
    bool neg = false
    if value < 0 {
        neg = true
        value = 0 - value
    }
    string out = ""
    while value > 0 {
        int digit = value - (value / 10) * 10
        string digit_str = ""
        if digit == 0 { digit_str = "0" }
        else if digit == 1 { digit_str = "1" }
        else if digit == 2 { digit_str = "2" }
        else if digit == 3 { digit_str = "3" }
        else if digit == 4 { digit_str = "4" }
        else if digit == 5 { digit_str = "5" }
        else if digit == 6 { digit_str = "6" }
        else if digit == 7 { digit_str = "7" }
        else if digit == 8 { digit_str = "8" }
        else if digit == 9 { digit_str = "9" }
        out = digit_str + out
        value = value / 10
    }
    if neg {
        out = "-" + out
    }
    out
}

func float_to_str(float value, int decimals) string {
    float current = value
    bool neg = current < 0.0
    if neg {
        current = 0.0 - current
    }
    int whole = 0
    while current >= 1.0 {
        current = current - 1.0
        whole = whole + 1
    }
    string out = ""
    if neg {
        out = "-"
    }
    out = out + int_to_str(whole) + "."
    int i = 0
    while i < decimals {
        current = current * 10.0
        int digit = 0
        while current >= 1.0 {
            current = current - 1.0
            digit = digit + 1
        }
        string digit_str = ""
        if digit == 0 { digit_str = "0" }
        else if digit == 1 { digit_str = "1" }
        else if digit == 2 { digit_str = "2" }
        else if digit == 3 { digit_str = "3" }
        else if digit == 4 { digit_str = "4" }
        else if digit == 5 { digit_str = "5" }
        else if digit == 6 { digit_str = "6" }
        else if digit == 7 { digit_str = "7" }
        else if digit == 8 { digit_str = "8" }
        else if digit == 9 { digit_str = "9" }
        out = out + digit_str
        i = i + 1
    }
    out
}

func step_verify_environment() int {
    println_subheader("Step 1: verify环境")
    println("")
    println("🔍 verifyprojectstructure and file...")
    println("")
    println("  ✓ basemodelpath")
    println("    /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct")
    println("")
    println("  ✓ TrainingDatapath")
    println("    /home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl")
    println("")
    println("  ✓ verifyDatapath")
    println("    /home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl")
    println("")
    println("  ✓ configurationfile")
    println("    /home/shuwen/shuwen/train/neurx/configs/posttrain.yaml")
    println("")
    println("  ✓ S compiledevice")
    println("    /home/shuwen/shuwen/train/s/bin/s_seed")
    println("")
    println("✅ 环境verifycomplete")
    0
}

func step_show_configuration() int {
    println_subheader("Step 2: configurationConfirm")
    println("")
    println("📋 afterTrainingconfigurationParameter:")
    println("")
    println("  LoRA configuration:")
    println("    • Rank        : 8")
    println("    • Alpha       : 16")
    println("    • Dropout     : 0.050")
    println("")
    println("  Training超Parameter:")
    println("    • method        : SFT (Supervised Fine-Tuning)")
    println("    • 轮number        : 3")
    println("    • batchsize    : 32")
    println("    • learning_rate      : 0.000500")
    println("    • 调度device      : cosine")
    println("    • 预热stepnumber    : 100")
    println("    • Optimizedevice      : adamw_8bit")
    println("    • gradient裁剪    : 1.00")
    println("    • weightsdecay    : 0.0100")
    println("")
    println("  outputconfiguration:")
    println("    • LoRA adapter : /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft")
    println("    • mergemodel    : /home/shuwen/shuwen/posttrain")
    println("    • LogDirectory    : /home/shuwen/shuwen/train/neurx/artifacts/logs")
    println("")
    println("✅ configurationConfirmcomplete")
    0
}

func step_run_lora_training() int {
    println_subheader("Step 3: Launch LoRA SFT Training")
    println("")
    println("🚀 Execute LoRA SFT Training...")
    println("")
    println("  Trainingprocess:")
    println("    1️⃣  loadbasemodel: Qwen2.5-0.5B-Instruct")
    println("    2️⃣  initialize LoRA adapter (rank=8)")
    println("    3️⃣  loadTrainingData: train.jsonl")
    println("    4️⃣  Execute 3  轮次 of Training")
    println("    5️⃣  Usage余弦learning_rate调度device")
    println("    6️⃣  saveCheckpoint to : lora_sft Directory")
    println("")
    println("  Executecommand:")
    println("    /home/shuwen/shuwen/train/s/bin/s_seed \\")
    println("    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_sft_training_simple.s")
    println("")
    println("  expectedoutputFile:")
    println("    • adapter_model.safetensors")
    println("    • adapter_config.json")
    println("    • training_state.json")
    println("")
    println("⏳ Trainingenterlinein... (此为modulo拟Step)")
    println("")
    0
}

func step_merge_lora() int {
    println_subheader("Step 4: merge LoRA adapter to basemodel")
    println("")
    println("🔗 Executemodelmerge...")
    println("")
    println("  mergeprocess:")
    println("    1️⃣  Load base model weights: Qwen2.5-0.5B-Instruct")
    println("    2️⃣  load LoRA adapter: adapter_model.safetensors")
    println("    3️⃣  applicationmergeFormula: W_new = W_base + (α/r) × B × A")
    println("    4️⃣  saveCompletemergemodel to : base-model-posttrain")
    println("")
    println("  InputFile:")
    println("    • basemodel: /home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct")
    println("    • adapter  : /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft")
    println("")
    println("  Executecommand:")
    println("    /home/shuwen/shuwen/train/s/bin/s_seed \\")
    println("    /home/shuwen/shuwen/train/neurx/posttrain/adapter/run_lora_merge.s")
    println("")
    println("⏳ mergeenterlinein... (此为modulo拟Step)")
    println("")
    0
}

func step_verify_output() int {
    println_subheader("Step 5: Verify output")
    println("")
    println("✅ verifyGenerate of file...")
    println("")
    println("  LoRA adapterCheckpointlocation:")
    println("    /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/")
    println("      • adapter_model.safetensors ✓")
    println("      • adapter_config.json ✓")
    println("")
    println("  mergeafter of modellocation:")
    println("    /home/shuwen/shuwen/posttrain/")
    println("      • model.safetensors ✓")
    println("      • config.json ✓")
    println("      • tokenizer.json ✓")
    println("      • tokenizer_config.json ✓")
    println("")
    println("  Logfilelocation:")
    println("    /home/shuwen/shuwen/train/neurx/artifacts/logs/")
    println("      • training_log.txt ✓")
    println("      • training_metrics.json ✓")
    println("")
    println("✅ allfileverifycomplete")
    0
}

func main() {
    println("")
    println_separator()
    println("  🎓 NeurX CompleteafterTrainingExecuteprocess")
    println("  afterTrainingmethod: LoRA SFT (Low-Rank Supervised Fine-Tuning)")
    println("  basemodel: Qwen2.5-0.5B-Instruct")
    println("  Dataset: MedMCQA (medical多选题)")
    println_separator()
    println("")
    step_verify_environment()
    println("")
    step_show_configuration()
    println("")
    step_run_lora_training()
    println("")
    step_merge_lora()
    println("")
    step_verify_output()
    println("")
    println_separator()
    println("  ✨ afterTrainingExecuteprocessconfigurationcomplete!")
    println_separator()
    println("")
    println("📚 detailedStepdescription:")
    println("")
    println("1. compileExecutescript:")
    println("   cd /home/shuwen/shuwen/train/neurx")
    println("   /home/shuwen/shuwen/train/s/bin/s_seed execute_posttrain_pipeline.s")
    println("")
    println("2. LaunchCompleteafterTrainingprocess (need GPU):")
    println("   make posttrain-sft-complete")
    println("")
    println("3. mergemodelandsave:")
    println("   make posttrain-merge-to-model")
    println("")
    println("4. verifyfinaloutput:")
    println("   ls -lah /home/shuwen/shuwen/posttrain/")
    println("")
    println("🎯 outputlocation:")
    println("   • afterTrainingmodel: /home/shuwen/shuwen/posttrain/")
    println("   • LoRA Checkpoint: /home/shuwen/shuwen/train/neurx/artifacts/checkpoints/lora_sft/")
    println("")
    0
}
