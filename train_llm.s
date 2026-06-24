// NeurX LLM Training System
// S entry that emits the real training command for the shell launcher.
package neurx.train.llm

func build_training_command() string {
    string root_dir = "/Users/feifei/train/neurx"
    string corpus = root_dir + "/data/corpus/train_corpus.txt"
    string save_dir = root_dir + "/artifacts/real_training"
    string command = ""
    command = command + "cd " + root_dir
    command = command + " && python3 " + root_dir + "/run_real_training.py"
    command = command + " --corpus " + corpus
    command = command + " --save-dir " + save_dir
    command = command + " --steps 300"
    command = command + " --batch-size 64"
    command = command + " --lr 0.35"
    command = command + " --min-lr 0.05"
    command = command + " --warmup-steps 30"
    command = command + " --weight-decay 0.0001"
    command = command + " --vocab-size 512"
    command = command + " --eval-interval 50"
    command = command + " --save-every 50"
    command
}

func main() int {
    print(build_training_command())
    return 0
}
