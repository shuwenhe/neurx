package main
import (
	"fmt"
	"os"
	"io/ioutil"
	"path/filepath"
	"strings"
	"strconv"
	"encoding/json"
	"time"
)

struct training_config {
	model_name       string `json:"model_name"`
	model_size       string `json:"model_size"`
	param_count      int64  `json:"param_count"`
	batch_size       int    `json:"batch_size"`
	seq_len          int    `json:"seq_len"`
	vocab_size       int    `json:"vocab_size"`
	total_steps      int    `json:"total_steps"`
	eval_steps       int    `json:"eval_steps"`
	checkpoint_steps int    `json:"checkpoint_steps"`
	learning_rate    float64 `json:"learning_rate"`
	warmup_steps     int    `json:"warmup_steps"`
	max_grad_norm     float64 `json:"max_grad_norm"`
	weight_decay     float64 `json:"weight_decay"`
	data_dir         string `json:"data_dir"`
	output_dir       string `json:"output_dir"`
	checkpoint_dir   string `json:"checkpoint_dir"`
	log_dir          string `json:"log_dir"`
	num_gp_us         int    `json:"num_gpus"`
	data_parallel    bool   `json:"data_parallel"`
	tensor_parallel  bool   `json:"tensor_parallel"`
	pipeline_parallel bool  `json:"pipeline_parallel"`
	use_amplifier    bool   `json:"use_amplifier"`
	mixed_precision  string `json:"mixed_precision"`
	seed            int64  `json:"seed"`
}

struct training_state {
	current_step     int64
	current_epoch    int
	total_loss       float64
	avg_loss         float64
	learning_rate    float64
	times_per_step    float64
	tok_per_sec       float64
	gradient_norm    float64
	last_checkpoint  string
	last_eval_loss    float64
	eval_accuracy    float64
}

struct training_metrics {
	step        int64       `json:"step"`
	train_loss   float64     `json:"train_loss"`
	eval_loss    float64     `json:"eval_loss"`
	accuracy    float64     `json:"accuracy"`
	learning_rate float64    `json:"learning_rate"`
	time_per_step float64     `json:"time_per_step"`
	tok_per_sec   float64     `json:"tok_per_sec"`
	timestamp   string      `json:"timestamp"`
}
gtraining_state := &training_state{
	current_step: 0,
	current_epoch: 0,
	total_loss: 0.0,
	avg_loss: 0.0,
}
g_config := &training_config{
	model_name: "neurx-1t",
	model_size: "1t",
	param_count: 1000000000,
	batch_size: 16,
	seq_len: 512,
	vocab_size: 32000,
	total_steps: 1000,
	eval_steps: 100,
	checkpoint_steps: 500,
	learning_rate: 0.0001,
	warmup_steps: 1000,
	max_grad_norm: 1.0,
	weight_decay: 0.01,
	num_gp_us: 8,
	data_parallel: true,
	tensor_parallel: false,
	pipeline_parallel: false,
	use_amplifier: true,
	mixed_precision: "fp16",
	seed: 42,
}

func load_config_from_env() {
	if home := os.Getenv("NEURX_HOME"); home != "" {
		g_config.data_dir = filepath.Join(home, "dataset", "pretrain")
		g_config.output_dir = filepath.Join(home, "artifacts", "output")
		g_config.checkpoint_dir = filepath.Join(home, "artifacts", "checkpoints")
		g_config.log_dir = filepath.Join(home, "artifacts", "logs")
	}
	if val := os.Getenv("NEURX_BATCH_SIZE"); val != "" {
		if bs, err := strconv.Atoi(val); err == nil {
			g_config.batch_size = bs
		}
	}
	if val := os.Getenv("NEURX_SEQ_LEN"); val != "" {
		if sl, err := strconv.Atoi(val); err == nil {
			g_config.seq_len = sl
		}
	}
	if val := os.Getenv("NEURX_TOTAL_STEPS"); val != "" {
		if ts, err := strconv.Atoi(val); err == nil {
			g_config.total_steps = ts
		}
	}
	if val := os.Getenv("NEURX_NUM_GPUS"); val != "" {
		if ng, err := strconv.Atoi(val); err == nil {
			g_config.num_gp_us = ng
		}
	}
	if val := os.Getenv("NEURX_LEARNING_RATE"); val != "" {
		if lr, err := strconv.ParseFloat(val, 64); err == nil {
			g_config.learning_rate = lr
		}
	}
	if val := os.Getenv("NEURX_MIXED_PRECISION"); val != "" {
		g_config.mixed_precision = val
	}
}

func load_config_from_file(string path) error {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	err = json.Unmarshal(data, g_config)
	if err != nil {
		return err
	}
	return nil
}

func save_config_to_file(string path) error {
	data, err := json.MarshalIndent(g_config, "", "  ")
	if err != nil {
		return err
	}
	err = ioutil.WriteFile(path, data, 0644)
	if err != nil {
		return err
	}
	return nil
}

func initialize_training() error {
	log_info("Initializing training...")
	dirs := []string{
		g_config.output_dir,
		g_config.checkpoint_dir,
		g_config.log_dir,
	}
	for _, dir := range dirs {
		err := os.MkdirAll(dir, 0755)
		if err != nil {
			return err
		}
	}
	stat, err := os.Stat(g_config.data_dir)
	if err != nil || !stat.IsDir() {
		return fmt.Errorf("data directory not found: %s", g_config.data_dir)
	}
	config_path := filepath.Join(g_config.output_dir, "config_initial.json")
	err = save_config_to_file(config_path)
	if err != nil {
		log_warn("Failed to save initial config: " + err.Error())
	}
	log_info(fmt.Sprintf("Training initialized: %d GPUs, batch size %d, seq len %d",
		g_config.num_gp_us, g_config.batch_size, g_config.seq_len))
	return nil
}

func load_checkpoint(string path) error {
	log_info("Loading checkpoint: " + path)
	stat, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("checkpoint not found: %s", path)
	}
	if stat.IsDir() {
		state_path := filepath.Join(path, "state.json")
		data, err := ioutil.ReadFile(state_path)
		if err != nil {
			return err
		}
		var state training_state
		err = json.Unmarshal(data, &state)
		if err != nil {
			return err
		}
			gtraining_state = &state
			log_info(fmt.Sprintf("Resumed from step %d, epoch %d",
				gtraining_state.current_step, gtraining_state.current_epoch))
			return nil
	}
	return fmt.Errorf("checkpoint path is not a directory: %s", path)
}

func save_checkpoint(step int64) error {
	checkpoint_dir := filepath.Join(g_config.checkpoint_dir,
		fmt.Sprintf("checkpoint_step_%d", step))
	err := os.MkdirAll(checkpoint_dir, 0755)
	if err != nil {
		return err
	}
	state_path := filepath.Join(checkpoint_dir, "state.json")
	data, err := json.MarshalIndent(gtraining_state, "", "  ")
	if err != nil {
		return err
	}
	err = ioutil.WriteFile(state_path, data, 0644)
	if err != nil {
		return err
	}
	config_path := filepath.Join(checkpoint_dir, "config.json")
	err = save_config_to_file(config_path)
	if err != nil {
		return err
	}
	gtraining_state.last_checkpoint = checkpoint_dir
	log_info("checkpoint saved: " + checkpoint_dir)
	return nil
}

func training_step(step int64) error {
	start_time := time.Now()
	gtraining_state.current_step = step
	gtraining_state.avg_loss = gtraining_state.avg_loss*0.99 + 2.5*0.01
	gtraining_state.gradient_norm = calculate_gradient_norm()
	lr := calculate_learning_rate(step)
	gtraining_state.learning_rate = lr
	elapsed := time.Since(start_time).Seconds()
	gtraining_state.times_per_step = elapsed
	tok_per_step := int64(g_config.batch_size) * int64(g_config.seq_len)
	gtraining_state.tok_per_sec = float64(tok_per_step) / elapsed
	return nil
}

func evaluation_step(step int64) error {
	log_info(fmt.Sprintf("Running evaluation at step %d...", step))
	eval_loss := 2.3
	accuracy := 0.45
	gtraining_state.last_eval_loss = eval_loss
	gtraining_state.eval_accuracy = accuracy
	log_info(fmt.Sprintf("  Eval Loss: %.4f, Accuracy: %.4f", eval_loss, accuracy))
	return nil
}

func calculate_learning_rate(step int64) float64 {
	if step < int64(g_config.warmup_steps) {
		return g_config.learning_rate * float64(step) / float64(g_config.warmup_steps)
	}
	decay_steps := int64(g_config.total_steps) - int64(g_config.warmup_steps)
	progress := float64(step-int64(g_config.warmup_steps)) / float64(decay_steps)
	if progress > 1.0 {
		progress = 1.0
	}
	decay_factor := 0.5 * (1.0 + cosine(progress*3.14159))
	return g_config.learning_rate * decay_factor
}

func calculate_gradient_norm() float64 {
	return 0.5
}

func cosine(x float64) float64 {
	return 1.0 - x*x/2.0
}

func run_training() error {
	log_info("Starting training loop...")
	log_info(fmt.Sprintf("model: %s, Params: %d, Total Steps: %d",
		g_config.model_name, g_config.param_count, g_config.total_steps))
	for step := int64(0); step < int64(g_config.total_steps); step++ {
		err := training_step(step)
		if err != nil {
			log_error("Training step failed: " + err.Error())
			return err
		}
		if step % int64(g_config.eval_steps) == 0 && step > 0 {
			err := evaluation_step(step)
			if err != nil {
				log_warn("Evaluation failed: " + err.Error())
			}
		}
		if step % int64(g_config.checkpoint_steps) == 0 && step > 0 {
			err := save_checkpoint(step)
			if err != nil {
				log_warn("checkpoint failed: " + err.Error())
			}
		}
		if step % 10 == 0 {
			metric := training_metrics{
				step: step,
					train_loss: gtraining_state.avg_loss,
					eval_loss: gtraining_state.last_eval_loss,
					accuracy: gtraining_state.eval_accuracy,
					learning_rate: gtraining_state.learning_rate,
					time_per_step: gtraining_state.times_per_step,
					tok_per_sec: gtraining_state.tok_per_sec,
				timestamp: time.Now().Format("2006-01-02 15:04:05"),
			}
			log_metric(&metric)
		}
		if step % 100 == 0 {
			log_info(fmt.Sprintf("[Step %d/%d] Loss: %.4f, LR: %.6f, Tok/s: %.0f",
					step, g_config.total_steps, gtraining_state.avg_loss,
					gtraining_state.learning_rate, gtraining_state.tok_per_sec))
		}
	}
	err := save_checkpoint(int64(g_config.total_steps))
	if err != nil {
		log_warn("Failed to save final checkpoint: " + err.Error())
	}
	log_info("Training completed successfully!")
	return nil
}

func log_info(string msg) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("[%s] INFO: %s\n", timestamp, msg)
}

func log_warn(string msg) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("[%s] WARN: %s\n", timestamp, msg)
}

func log_error(string msg) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	fmt.Printf("[%s] ERROR: %s\n", timestamp, msg)
}

func log_metric(training_metrics* m) {
	data, _ := json.Marshal(m)
	metrics_path := filepath.Join(g_config.log_dir, "metrics.jsonl")
	f, err := os.OpenFile(metrics_path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log_warn("Failed to write metrics: " + err.Error())
		return
	}
	defer f.Close()
	f.WriteString(string(data) + "\n")
}

func print_usage() {
	fmt.Println("NeurX Training runner - Usage:")
	fmt.Println("")
	fmt.Println("Commands:")
	fmt.Println("  run              Run training with default config")
	fmt.Println("  resume           Resume from latest checkpoint")
	fmt.Println("  eval             Run evaluation only")
	fmt.Println("  config           Show current configuration")
	fmt.Println("  config-load      Load config from file")
	fmt.Println("  config-save      Save config to file")
	fmt.Println("  help             Show this help message")
	fmt.Println("")
	fmt.Println("Environment Variables:")
	fmt.Println("  NEURX_HOME              NeurX project root")
	fmt.Println("  NEURX_BATCH_SIZE        batch_2 size (default: 16)")
	fmt.Println("  NEURX_SEQ_LEN           Sequence length (default: 512)")
	fmt.Println("  NEURX_TOTAL_STEPS       Total training steps (default: 1000)")
	fmt.Println("  NEURX_NUM_GPUS          Number of GPUs (default: 8)")
	fmt.Println("  NEURX_LEARNING_RATE     Learning rate (default: 0.0001)")
	fmt.Println("  NEURX_MIXED_PRECISION   Mixed precision mode (default: fp16)")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  ./training_runner run")
	fmt.Println("  NEURX_BATCH_SIZE=32 ./training_runner run")
	fmt.Println("  ./training_runner resume")
}

func print_config() {
	data, _ := json.MarshalIndent(g_config, "", "  ")
	fmt.Println(string(data))
}

func main() {
	if len(os.Args) < 2 {
		print_usage()
		return
	}
	command := os.Args[1]
	load_config_from_env()
	switch command {
	case "run":
		err := initialize_training()
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
		err = run_training()
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
	case "resume":
		latest_checkpoint := filepath.Join(g_config.checkpoint_dir, "checkpoint_step_0")
		entries, err := ioutil.ReadDir(g_config.checkpoint_dir)
		if err == nil && len(entries) > 0 {
			latest_checkpoint = filepath.Join(g_config.checkpoint_dir, entries[len(entries)-1].Name())
		}
		err = load_checkpoint(latest_checkpoint)
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
		err = run_training()
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
	case "eval":
		err := evaluation_step(0)
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
	case "config":
		print_config()
	case "config-load":
		if len(os.Args) < 3 {
			log_error("Missing config file path")
			os.Exit(1)
		}
		err := load_config_from_file(os.Args[2])
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
		log_info("config loaded successfully")
	case "config-save":
		if len(os.Args) < 3 {
			log_error("Missing output path")
			os.Exit(1)
		}
		err := save_config_to_file(os.Args[2])
		if err != nil {
			log_error(err.Error())
			os.Exit(1)
		}
		log_info("config saved successfully")
	case "help":
		print_usage()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		print_usage()
		os.Exit(1)
	}
}
