package main
import (
    "time"
    "os"
    "fmt"
    "encoding/json"
    "math"
)
type perplexity_metrics struct {
    step: int
    loss: float
    perplexity: float
    val_loss: float
    val_perplexity: float
    improvement: float
}
type training_metrics struct {
    step: int
    epoch: int
    batch_idx: int
    loss: float
    learning_rate: float
    throughput: float
    time_elapsed: float
    eta: float
    memory_used: float
    grad_norm: float
    perplexity: perplexity_metrics
}
type advanced_training_monitor struct {
    start_time: time.Time
    steps: []training_metrics
    total_steps: int
    log_file: string
    update_interval: int
    ppl_history: []perplexity_metrics
    best_val_ppl: float
    best_step: int
    convergence_window: int
    convergence_threshold: float
}

func (atm *advanced_training_monitor) init(
    total_steps: int,
    log_file: string,
    update_interval: int,
    convergence_window: int) error {
    atm.start_time = time.Now()
    atm.steps = make([]training_metrics, 0)
    atm.ppl_history = make([]perplexity_metrics, 0)
    atm.total_steps = total_steps
    atm.log_file = log_file
    atm.update_interval = update_interval
    atm.convergence_window = convergence_window
    atm.convergence_threshold = 0.01
    atm.best_val_ppl = math.MaxFloat
    atm.best_step = 0
    f, err := os.Create(log_file)
    if err != nil {
        return err
    }
    defer f.Close()
    return nil
}

func calculate_perplexity(float loss): float {
    if loss < 0 {
        return -1.0
    }
    return math.Exp(loss)
}

func (atm *advanced_training_monitor) log_perplexity(
    step: int,
    train_loss: float,
    val_loss: float) {
    train_ppl := calculate_perplexity(train_loss)
    val_ppl := calculate_perplexity(val_loss)
    improvement := 0.0
    if len(atm.ppl_history) > 0 {
        prev := atm.ppl_history[len(atm.ppl_history)-1]
        improvement = (prev.val_perplexity - val_ppl) / prev.val_perplexity * 100.0
    }
    ppl_metric := perplexity_metrics{
        step: step,
        loss: train_loss,
        perplexity: train_ppl,
        val_loss: val_loss,
        val_perplexity: val_ppl,
        improvement: improvement,
    }
    atm.ppl_history = append(atm.ppl_history, ppl_metric)
    if val_ppl < atm.best_val_ppl {
        atm.best_val_ppl = val_ppl
        atm.best_step = step
    }
}

func (atm *advanced_training_monitor) log_step(
    step: int,
    epoch: int,
    batch_idx: int,
    loss: float,
    learning_rate: float,
    throughput: float,
    memory_used: float,
    grad_norm: float,
    train_ppl: perplexity_metrics) {
    elapsed := time.Since(atm.start_time).Seconds()
    eta := atm.calculate_eta(step, elapsed)
    metrics := training_metrics{
        step: step,
        epoch: epoch,
        batch_idx: batch_idx,
        loss: loss,
        learning_rate: learning_rate,
        throughput: throughput,
        time_elapsed: elapsed,
        eta: eta,
        memory_used: memory_used,
        grad_norm: grad_norm,
        perplexity: train_ppl,
    }
    atm.steps = append(atm.steps, metrics)
    if step % atm.update_interval == 0 {
        atm.print_progress(metrics)
    }
    atm.log_to_file(metrics)
}

func (atm *advanced_training_monitor) calculate_eta(int step, float elapsed): float {
    if step <= 0 {
        return 0.0
    }
    avg_step_time := elapsed / float(step)
    remaining_steps := atm.total_steps - step
    return avg_step_time * float(remaining_steps)
}

func (atm *advanced_training_monitor) print_progress(metrics: training_metrics) {
    progress := float(metrics.step) / float(atm.total_steps) * 100.0
    bar_length := 50
    filled := int(progress / 100.0 * float(bar_length))
    bar := "["
    for i := 0; i < bar_length; i++ {
        if i < filled {
            bar += "="
        } else if i == filled {
            bar += ">"
        } else {
            bar += " "
        }
    }
    bar += "]"
    elapsed_str := format_time(metrics.time_elapsed)
    eta_str := format_time(metrics.eta)
    convergence := atm.check_convergence()
    convergence_str := "→"
    if convergence {
        convergence_str = "✓"
    }
    status := fmt.Sprintf(
        "%s %.1f%% [%s] | Step %d/%d | Loss: %.4f | PPL: %.1f | Val-PPL: %.1f | LR: %.2e | Speed: %.0f tok/s | Mem: %.1fMB | Grad: %.2f | Elapsed: %s | ETA: %s",
        bar, progress, convergence_str, metrics.step, atm.total_steps,
        metrics.loss, metrics.perplexity.perplexity, metrics.perplexity.val_perplexity,
        metrics.learning_rate, metrics.throughput,
        metrics.memory_used, metrics.grad_norm, elapsed_str, eta_str)
    println(status)
}

func (atm *advanced_training_monitor) log_to_file(metrics: training_metrics) {
    f, err := os.OpenFile(atm.log_file, os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        return
    }
    defer f.Close()
    json_data, _ := json.Marshal(metrics)
    f.WriteString(string(json_data) + "\n")
}

func (atm *advanced_training_monitor) check_convergence(): bool {
    if len(atm.ppl_history) < atm.convergence_window {
        return false
    }
    start_idx := len(atm.ppl_history) - atm.convergence_window
    recent_ppl := atm.ppl_history[start_idx].val_perplexity
    current_ppl := atm.ppl_history[len(atm.ppl_history)-1].val_perplexity
    change := math.Abs(current_ppl - recent_ppl) / recent_ppl
    return change < atm.convergence_threshold
}

func (atm *advanced_training_monitor) get_stats(): map[string]interface{} {
    if len(atm.steps) == 0 {
        return map[string]interface{}{
            "status": "no_data",
        }
    }
    first := atm.steps[0]
    last := atm.steps[len(atm.steps)-1]
    avg_loss := 0.0
    min_loss := last.loss
    max_loss := first.loss
    for _, m := range atm.steps {
        avg_loss += m.loss
        if m.loss < min_loss {
            min_loss = m.loss
        }
        if m.loss > max_loss {
            max_loss = m.loss
        }
    }
    if len(atm.steps) > 0 {
        avg_loss = avg_loss / float(len(atm.steps))
    }
    initial_ppl := 0.0
    final_ppl := 0.0
    if len(atm.ppl_history) > 0 {
        initial_ppl = atm.ppl_history[0].val_perplexity
        final_ppl = atm.ppl_history[len(atm.ppl_history)-1].val_perplexity
    }
    improvement_pct := 0.0
    if initial_ppl > 0 {
        improvement_pct = (initial_ppl - final_ppl) / initial_ppl * 100.0
    }
    return map[string]interface{}{
        "total_steps": len(atm.steps),
        "current_step": last.step,
        "current_loss": last.loss,
        "average_loss": avg_loss,
        "min_loss": min_loss,
        "max_loss": max_loss,
        "initial_perplexity": initial_ppl,
        "final_perplexity": final_ppl,
        "best_perplexity": atm.best_val_ppl,
        "best_step": atm.best_step,
        "perplexity_improvement_percent": improvement_pct,
        "is_converged": atm.check_convergence(),
        "average_throughput": last.throughput,
        "time_elapsed": last.time_elapsed,
        "estimated_total_time": last.time_elapsed + last.eta,
    }
}

func (atm *advanced_training_monitor) generate_report(): string {
    stats := atm.get_stats()
    report := "╔════════════════════════════════════════════════════════════╗\n"
    report += "║          🎯 NeurX Advanced Training Report                 ║\n"
    report += "╚════════════════════════════════════════════════════════════╝\n\n"
    report += "📊 Loss Metrics:\n"
    report += "├─ Current: " + fmt.Sprintf("%.4f", stats["current_loss"]) + "\n"
    report += "├─ Average: " + fmt.Sprintf("%.4f", stats["average_loss"]) + "\n"
    report += "├─ Min: " + fmt.Sprintf("%.4f", stats["min_loss"]) + "\n"
    report += "└─ Max: " + fmt.Sprintf("%.4f", stats["max_loss"]) + "\n\n"
    report += "📈 Perplexity Progression:\n"
    report += "├─ Initial: " + fmt.Sprintf("%.1f", stats["initial_perplexity"]) + "\n"
    report += "├─ Current: " + fmt.Sprintf("%.1f", stats["final_perplexity"]) + "\n"
    report += "├─ Best: " + fmt.Sprintf("%.1f", stats["best_perplexity"]) + " (Step " + fmt.Sprintf("%d", stats["best_step"]) + ")\n"
    report += "└─ Improvement: " + fmt.Sprintf("%.2f%%", stats["perplexity_improvement_percent"]) + "\n\n"
    report += "⏱️  Time Metrics:\n"
    report += "├─ Elapsed: " + format_time(stats["time_elapsed"].(float)) + "\n"
    report += "├─ Estimated Total: " + format_time(stats["estimated_total_time"].(float)) + "\n"
    report += "└─ Progress: " + fmt.Sprintf("%.1f%%", float(stats["total_steps"].(int))/float(atm.total_steps)*100) + "\n\n"
    report += "🚀 Performance:\n"
    report += "├─ Average Throughput: " + fmt.Sprintf("%.0f", stats["average_throughput"]) + " tok/s\n"
    report += "├─ Steps Completed: " + fmt.Sprintf("%d", stats["total_steps"]) + "\n"
    report += "└─ status: "
    if stats["is_converged"].(bool) {
        report += "✅ Converged\n"
    } else {
        report += "🔄 Training in progress\n"
    }
    report += "\n📉 Perplexity Trend (Last 10 evaluations):\n"
    start_idx := len(atm.ppl_history) - 10
    if start_idx < 0 {
        start_idx = 0
    }
    for i := start_idx; i < len(atm.ppl_history); i++ {
        ppl := atm.ppl_history[i]
        bar := ""
        for j := 0; j < int(ppl.val_perplexity/10); j++ {
            bar += "█"
        }
        report += fmt.Sprintf("Step %d: %s %.1f\n", ppl.step, bar, ppl.val_perplexity)
    }
    return report
}

func (atm *advanced_training_monitor) export_json(): string {
    data := map[string]interface{}{
        "summary": atm.get_stats(),
        "perplexity_history": atm.ppl_history,
        "detailed_history": atm.steps,
        "convergence_status": map[string]interface{}{
            "is_converged": atm.check_convergence(),
            "convergence_window": atm.convergence_window,
            "convergence_threshold": atm.convergence_threshold,
        },
    }
    json_bytes, _ := json.Marshal(data)
    return string(json_bytes)
}

func format_time(float seconds): string {
    if seconds < 0 {
        return "N/A"
    }
    h := int(seconds) / 3600
    m := (int(seconds) % 3600) / 60
    s := int(seconds) % 60
    if h > 0 {
        return fmt.Sprintf("%dh %dm %ds", h, m, s)
    } else if m > 0 {
        return fmt.Sprintf("%dm %ds", m, s)
    } else {
        return fmt.Sprintf("%ds", s)
    }
}

func main() {
    monitor := &advanced_training_monitor{}
    if err := monitor.init(100000, "./logs/training_advanced.jsonl", 100, 500); err != nil {
        println("Error:", err.Error())
        return
    }
    for step := 100; step <= 10000; step += 100 {
        loss := 5.0 - float(step/1000)*0.8 + math.Sin(float(step))*0.1
        val_loss := 4.8 - float(step/1000)*0.7 + math.Sin(float(step/2))*0.15
        ppl_metric := perplexity_metrics{
            step: step,
            loss: loss,
            perplexity: calculate_perplexity(loss),
            val_loss: val_loss,
            val_perplexity: calculate_perplexity(val_loss),
        }
        monitor.log_perplexity(step, loss, val_loss)
        lr := 5e-4 * math.Cos(float(step)/100000*3.14159)
        throughput := 1000.0
        memory := 512.0 + float(step/1000)*64
        grad_norm := 1.5 - float(step/10000)*0.5
        monitor.log_step(step, 1, 0, loss, lr, throughput, memory, grad_norm, ppl_metric)
    }
    println("\n" + monitor.generate_report())
}

