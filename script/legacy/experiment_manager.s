package main
import (
    "fmt"
    "math"
    "time"
)

struct hyper_parameter {
    name            string
    value           string
    data_type       string
    search_range    string
}

struct experiment_metrics {
    step            int64
    train_loss      float64
    val_loss        float64
    perplexity      float64
    learning_rate   float64
    batch_size      int
    throughput      float64
    memory_usage_gb float64
}

struct experiment_config {
    experiment_id       string
    name                string
    description         string
    model_name          string
    dataset_name        string
    hyperparameters     []hyper_parameter
    start_time          int64
    end_time            int64
    status              string
}

struct experiment_result {
    config              experiment_config
    metrics_history     []experiment_metrics
    best_checkpoint     string
    best_loss           float64
    best_perplexity     float64
    training_duration   int64
    converged           bool
}

struct experiment_comparison {
    experiment_ids      string[]
    metric_name         string
    results             map[string]float64
    winner              string
    significance        float64
}

struct experiment_manager {
    experiments         map[string]experiment_result
    current_experiment  string
    comparison_history  []experiment_comparison
    best_experiment     string
}

func (experiment_manager* manager) initialize() {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Industrial Experiment Management System              ║")
    fmt.Println("║  Track, compare, and optimize training experiments    ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝\n")
    fmt.Printf("Initialization:\n")
    fmt.Printf("  Total Experiments: %d\n", len(manager.experiments))
    fmt.Printf("  Current: %s\n\n", manager.current_experiment)
}

func (experiment_manager* manager) create_experiment(
    experiment_id string,
    name string,
    description string,
    model_name string,
    dataset_name string) experiment_config {
    fmt.Printf("\n[Experiment] Creating experiment: %s\n", experiment_id)
    fmt.Printf("  Name: %s\n", name)
    fmt.Printf("  model: %s\n", model_name)
    fmt.Printf("  Dataset: %s\n", dataset_name)
    config := experiment_config{
        experiment_id:   experiment_id,
        name:            name,
        description:     description,
        model_name:      model_name,
        dataset_name:    dataset_name,
        hyperparameters: make([]hyper_parameter, 0),
        start_time:      1719842400,
        end_time:        0,
        status:          "created",
    }
    fmt.Printf("  ✓ Experiment created\n")
    return config
}

func (experiment_manager* manager) add_hyperparameter(
    experiment_id string,
    param_name string,
    param_value string,
    data_type string) {
    if result, exists := manager.experiments[experiment_id]; exists {
        param := hyper_parameter{
            name:        param_name,
            value:       param_value,
            data_type:   data_type,
            search_range: "",
        }
        result.config.hyperparameters = append(result.config.hyperparameters, param)
        manager.experiments[experiment_id] = result
    }
}

func (experiment_manager* manager) log_hyperparameters(experiment_id string) {
    fmt.Printf("\n[Experiment] Hyperparameters for %s:\n", experiment_id)
    if result, exists := manager.experiments[experiment_id]; exists {
        for _, param := range result.config.hyperparameters {
            fmt.Printf("  • %s = %s (%s)\n", param.name, param.value, param.data_type)
        }
    }
}

func (experiment_manager* manager) record_metrics(
    experiment_id string,
    step int64,
    train_loss float64,
    val_loss float64,
    perplexity float64,
    learning_rate float64,
    batch_size int,
    throughput float64,
    memory_gb float64) {
    if result, exists := manager.experiments[experiment_id]; exists {
        metric := experiment_metrics{
            step:           step,
            train_loss:     train_loss,
            val_loss:       val_loss,
            perplexity:     perplexity,
            learning_rate:  learning_rate,
            batch_size:     batch_size,
            throughput:     throughput,
            memory_usage_gb: memory_gb,
        }
        result.metrics_history = append(result.metrics_history, metric)
        if val_loss < result.best_loss {
            result.best_loss = val_loss
            result.best_checkpoint = fmt.Sprintf("ckpt-step-%d", step)
        }
        if perplexity < result.best_perplexity {
            result.best_perplexity = perplexity
        }
        manager.experiments[experiment_id] = result
    }
}

func (experiment_manager* manager) get_metrics_summary(experiment_id string) {
    fmt.Printf("\n[Metrics] Summary for %s:\n", experiment_id)
    if result, exists := manager.experiments[experiment_id]; exists {
        if len(result.metrics_history) > 0 {
            first := result.metrics_history[0]
            last := result.metrics_history[len(result.metrics_history)-1]
            fmt.Printf("  Steps: %d → %d\n", first.step, last.step)
            fmt.Printf("  Loss: %.4f → %.4f (best: %.4f)\n",
                first.train_loss, last.train_loss, result.best_loss)
            fmt.Printf("  Perplexity: %.2f → %.2f (best: %.2f)\n",
                first.perplexity, last.perplexity, result.best_perplexity)
            fmt.Printf("  Throughput: %.1f tok/sec\n", last.throughput)
            fmt.Printf("  Memory: %.1f GB\n", last.memory_usage_gb)
        }
    }
}

func (experiment_manager* manager) compare_experiments(
    exp_ids []string,
    metric string) experiment_comparison {
    fmt.Printf("\n[Comparison] Comparing %d experiments on metric: %s\n", len(exp_ids), metric)
    comparison := experiment_comparison{
        experiment_ids: exp_ids,
        metric_name:    metric,
        results:        make(map[string]float64),
        winner:         "",
        significance:   0.0,
    }
    best_value := math.MaxFloat64
    best_exp := ""
    second_best := math.MaxFloat64
    for _, exp_id := range exp_ids {
        if result, exists := manager.experiments[exp_id]; exists {
            value := 0.0
            if metric == "loss" && len(result.metrics_history) > 0 {
                value = result.best_loss
            } else if metric == "perplexity" && len(result.metrics_history) > 0 {
                value = result.best_perplexity
            }
            comparison.results[exp_id] = value
            fmt.Printf("  %s: %.4f\n", exp_id, value)
            if value < best_value {
                second_best = best_value
                best_value = value
                best_exp = exp_id
            } else if value < second_best {
                second_best = value
            }
        }
    }
    comparison.winner = best_exp
    if second_best < math.MaxFloat64 && second_best > 0.0 {
        comparison.significance = ((second_best - best_value) / second_best) * 100.0
    } else {
        comparison.significance = 0.0
    }
    fmt.Printf("  Winner: %s (%.4f)\n", best_exp, best_value)
    return comparison
}

func (experiment_manager* manager) mark_experiment_complete(
    experiment_id string,
    converged bool) {
    if result, exists := manager.experiments[experiment_id]; exists {
        result.config.end_time = int64(time.Now().Unix())
        result.config.status = "completed"
        result.converged = converged
        if len(result.metrics_history) > 0 {
            result.training_duration = result.config.end_time - result.config.start_time
        }
        manager.experiments[experiment_id] = result
        fmt.Printf("\n[Experiment] Marked as complete: %s\n", experiment_id)
        fmt.Printf("  status: %s\n", result.config.status)
        fmt.Printf("  Duration: %d seconds\n", result.training_duration)
        fmt.Printf("  Converged: %v\n", converged)
    }
}

func (experiment_manager* manager) get_experiment_history() {
    fmt.Println("\n[History] Experiment History:")
    fmt.Println("  ID                    status      Loss        PPL         Time")
    fmt.Println("  ──────────────────────────────────────────────────────────────")
    for exp_id, result := range manager.experiments {
        status := result.config.status
        loss := fmt.Sprintf("%.4f", result.best_loss)
        ppl := fmt.Sprintf("%.2f", result.best_perplexity)
        duration := fmt.Sprintf("%ds", result.training_duration)
        fmt.Printf("  %-20s  %-10s  %-10s  %-10s  %s\n",
            exp_id, status, loss, ppl, duration)
    }
}

func (experiment_manager* manager) export_experiment_config(experiment_id string) string {
    if result, exists := manager.experiments[experiment_id]; exists {
        config_str := fmt.Sprintf("# Experiment: %s\n", result.config.name)
        config_str += fmt.Sprintf("ID: %s\n", experiment_id)
        config_str += fmt.Sprintf("model: %s\n", result.config.model_name)
        config_str += fmt.Sprintf("Dataset: %s\n", result.config.dataset_name)
        config_str += fmt.Sprintf("\n# Hyperparameters\n")
        for _, param := range result.config.hyperparameters {
            config_str += fmt.Sprintf("%s=%s\n", param.name, param.value)
        }
        config_str += fmt.Sprintf("\n# Results\n")
        config_str += fmt.Sprintf("best_loss=%.6f\n", result.best_loss)
        config_str += fmt.Sprintf("best_perplexity=%.4f\n", result.best_perplexity)
        config_str += fmt.Sprintf("best_checkpoint=%s\n", result.best_checkpoint)
        config_str += fmt.Sprintf("converged=%v\n", result.converged)
        return config_str
    }
    return ""
}

func (experiment_manager* manager) find_best_experiment() string {
    best_exp := ""
    best_ppl := math.MaxFloat64
    fmt.Println("\n[Analysis] Finding best experiment...")
    for exp_id, result := range manager.experiments {
        if result.converged && result.best_perplexity < best_ppl {
            best_ppl = result.best_perplexity
            best_exp = exp_id
        }
    }
    manager.best_experiment = best_exp
    fmt.Printf("  Best experiment: %s (PPL: %.2f)\n", best_exp, best_ppl)
    return best_exp
}

func new_experiment_manager() *experiment_manager {
    return *experiment_manager{
        experiments:        make(map[string]experiment_result),
        current_experiment: "",
        comparison_history: make([]experiment_comparison, 0),
        best_experiment:    "",
    }
}

func (experiment_manager* manager) run_complete_experiment_cycle() {
    manager.initialize()
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  Creating and Running Experiments      │")
    fmt.Println("└────────────────────────────────────────┘")
    experiments := []struct {
        id    string
        name  string
        lr    string
        wd    string
    }{
        {"exp-001", "Baseline", "5e-4", "0.01"},
        {"exp-002", "High LR", "1e-3", "0.01"},
        {"exp-003", "High Decay", "5e-4", "0.05"},
    }
    for _, exp := range experiments {
        config := manager.create_experiment(
            exp.id,
            exp.name,
            fmt.Sprintf("Test experiment %s", exp.name),
            "neurx-346m",
            "wikitext",
        )
        result := experiment_result{
            config:          config,
            metrics_history: make([]experiment_metrics, 0),
            best_loss:       math.MaxFloat64,
            best_perplexity: math.MaxFloat64,
        }
        manager.experiments[exp.id] = result
        manager.current_experiment = exp.id
        manager.add_hyperparameter(exp.id, "learning_rate", exp.lr, "float")
        manager.add_hyperparameter(exp.id, "weight_decay", exp.wd, "float")
        manager.add_hyperparameter(exp.id, "batch_size", "32", "int")
        manager.add_hyperparameter(exp.id, "warmup_steps", "1000", "int")
        manager.log_hyperparameters(exp.id)
        converged := false
        for step := int64(1000); step <= 5000; step += 1000 {
            loss := 5.0 - float64(step)/1500.0
            ppl := loss * 1.5
            manager.record_metrics(
                exp.id,
                step,
                loss,
                loss + 0.1,
                ppl,
                5e-4 * float64(6000-step) / 5000,
                32,
                850.0,
                24.0,
            )
            if step == 5000 {
                converged = true
            }
        }
        manager.mark_experiment_complete(exp.id, converged)
        manager.get_metrics_summary(exp.id)
    }
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  Comparing Experiments                 │")
    fmt.Println("└────────────────────────────────────────┘")
    exp_ids := string[]{"exp-001", "exp-002", "exp-003"}
    comparison := manager.compare_experiments(exp_ids, "perplexity")
    manager.comparison_history = append(manager.comparison_history, comparison)
    manager.get_experiment_history()
    manager.find_best_experiment()
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  Exporting Best Configuration          │")
    fmt.Println("└────────────────────────────────────────┘")
    config_export := manager.export_experiment_config(manager.best_experiment)
    fmt.Println("\n" + config_export)
    fmt.Println("[experiment_manager] Complete!")
}
