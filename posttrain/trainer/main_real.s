package neurx.posttrain.trainer.main_real
use std.io.eprintln
use neurx.posttrain.trainer.real_training.{run_real_training}
func main() {
    eprintln("[NeurX PostTrain] Starting Real Training Pipeline")
    eprintln("[Version] Phase 1: Proof of Concept")
    eprintln("[Components] Real Transformer + Real Loss + Real Tokenizer")
    eprintln("")
    int result = run_real_training()
    if result == 0 {
        eprintln("")
        eprintln("[Success] Training completed successfully")
    } else {
        eprintln("")
        eprintln("[Error] Training failed with code: " + int_to_str(result))
    }
    result
}

func int_to_str(int x) string {
    if x == 0 { return "0" }
    if x < 0 { return "-" + int_to_str(0 - x) }
    string result = ""
    int num = x
    while num > 0 {
        int digit = num - ((num / 10) * 10)
        if digit == 0 { result = "0" + result }
        if digit == 1 { result = "1" + result }
        if digit == 2 { result = "2" + result }
        if digit == 3 { result = "3" + result }
        if digit == 4 { result = "4" + result }
        if digit == 5 { result = "5" + result }
        if digit == 6 { result = "6" + result }
        if digit == 7 { result = "7" + result }
        if digit == 8 { result = "8" + result }
        if digit == 9 { result = "9" + result }
        num = num / 10
    }
    result
}
