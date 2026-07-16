#!/usr/bin/env s

// ============================================
// NeurX Advanced Training Monitor with Perplexity Tracking
// Purpose: Track progress + perplexity + convergence
// Language: S
// ============================================

package main

import (
    "time"
    "os"
    "fmt"
    "encoding/json"
    "math"
)

// PerplexityMetrics tracks perplexity progression
type PerplexityMetrics struct {
    step: int
    loss: float
    perplexity: float
    val_loss: float
    val_perplexity: float
    improvement: float  // % improvement from previous
}

// TrainingMetrics captures single step metrics
type training_metrics struct {
    step: int
    epoch: int
    batch_idx: int
    loss: float
    learning_rate: float
    throughput: float  // tokens/sec
    time_elapsed: float  // seconds
    eta: float  // estimated time in seconds
    memory_used: float  // MB
    grad_norm: float  // gradient norm
    perplexity: PerplexityMetrics
}

// AdvancedTrainingMonitor tracks comprehensive training progress
type AdvancedTrainingMonitor struct {
    start_time: time.Time
    steps: []training_metrics
    total_steps: int
    log_file: string
    update_interval: int
    
    // Perplexity tracking
    ppl_history: []PerplexityMetrics
    best_val_ppl: float
    best_step: int
    
    // Convergence tracking
    convergence_window: int  // Steps to check for convergence
    convergence_threshold: float  // % change threshold
}

// ============================================
// Initialization
// ============================================

func (atm *AdvancedTrainingMonitor) init(
    total_steps: int,
    log_file: string,
    update_interval: int,
    convergence_window: int) error {
    
    atm.start_time = time.Now()
    atm.steps = make([]training_metrics, 0)
    atm.ppl_history = make([]PerplexityMetrics, 0)
    atm.total_steps = total_steps
    atm.log_file = log_file
    atm.update_interval = update_interval
    atm.convergence_window = convergence_window
    atm.convergence_threshold = 0.01  // 1% threshold
    atm.best_val_ppl = math.MaxFloat
    atm.best_step = 0
    
    // Create log file
    f, err := os.Create(log_file)
    if err != nil {
        return err
    }
    defer f.Close()
    
    return nil
}

// ============================================
// Perplexity Calculation
// ============================================

// Calculate perplexity from loss
func calculate_perplexity(loss: float): float {
    if loss < 0 {
        return -1.0
    }
    return math.Exp(loss)
}

// Track perplexity progression
func (atm *AdvancedTrainingMonitor) log_perplexity(
    step: int,
    train_loss: float,
    val_loss: float) {
    
    train_ppl := calculate_perplexity(train_loss)
    val_ppl := calculate_perplexity(val_loss)
    
    // Calculate improvement
    improvement := 0.0
    if len(atm.ppl_history) > 0 {
        prev := atm.ppl_history[len(atm.ppl_history)-1]
        improvement = (prev.val_perplexity - val_ppl) / prev.val_perplexity * 100.0
    }
    
    ppl_metric := PerplexityMetrics{
        step: step,
        loss: train_loss,
        perplexity: train_ppl,
        val_loss: val_loss,
        val_perplexity: val_ppl,
        improvement: improvement,
    }
    
    atm.ppl_history = append(atm.ppl_history, ppl_metric)
    
    // Track best validation perplexity
    if val_ppl < atm.best_val_ppl {
        atm.best_val_ppl = val_ppl
        atm.best_step = step
    }
}

// ============================================
// Main Logging Functions
// ============================================

func (atm *AdvancedTrainingMonitor) log_step(
    step: int,
    epoch: int,
    batch_idx: int,
    loss: float,
    learning_rate: float,
    throughput: float,
    memory_used: float,
    grad_norm: float,
    train_ppl: PerplexityMetrics) {
    
    elapsed := time.Since(atm.start_time).Seconds()
    
    // Calculate ETA
    eta := atm.calculate_eta(step, elapsed)
    
    // Create metrics
    metrics := TrainingMetrics{
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
    
    // Print progress
    if step % atm.update_interval == 0 {
        atm.print_progress(metrics)
    }
    
    // Log to file
    atm.log_to_file(metrics)
}

// Calculate ETA
func (atm *AdvancedTrainingMonitor) calculate_eta(step: int, elapsed: float): float {
    if step <= 0 {
        return 0.0
    }
    
    avg_step_time := elapsed / float(step)
    remaining_steps := atm.total_steps - step
    return avg_step_time * float(remaining_steps)
}

// Print detailed progress
func (atm *AdvancedTrainingMonitor) print_progress(metrics: TrainingMetrics) {
    progress := float(metrics.step) / float(atm.total_steps) * 100.0
    bar_length := 50
    filled := int(progress / 100.0 * float(bar_length))
    
    // Build progress bar
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
    
    // Format time strings
    elapsed_str := format_time(metrics.time_elapsed)
    eta_str := format_time(metrics.eta)
    
    // Get convergence status
    convergence := atm.check_convergence()
    convergence_str := "→"
    if convergence {
        convergence_str = "✓"
    }
    
    // Build status line
    status := fmt.Sprintf(
        "%s %.1f%% [%s] | Step %d/%d | Loss: %.4f | PPL: %.1f | Val-PPL: %.1f | LR: %.2e | Speed: %.0f tok/s | Mem: %.1fMB | Grad: %.2f | Elapsed: %s | ETA: %s",
        bar, progress, convergence_str, metrics.step, atm.total_steps,
        metrics.loss, metrics.perplexity.perplexity, metrics.perplexity.val_perplexity,
        metrics.learning_rate, metrics.throughput,
        metrics.memory_used, metrics.grad_norm, elapsed_str, eta_str)
    
    println(status)
}

// Log to file
func (atm *AdvancedTrainingMonitor) log_to_file(metrics: TrainingMetrics) {
    f, err := os.OpenFile(atm.log_file, os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        return
    }
    defer f.Close()
    
    json_data, _ := json.Marshal(metrics)
    f.WriteString(string(json_data) + "\n")
}

// ============================================
// Convergence Detection
// ============================================

// Check for convergence
func (atm *AdvancedTrainingMonitor) check_convergence(): bool {
    if len(atm.ppl_history) < atm.convergence_window {
        return false
    }
    
    // Get recent PPL values
    start_idx := len(atm.ppl_history) - atm.convergence_window
    recent_ppl := atm.ppl_history[start_idx].val_perplexity
    current_ppl := atm.ppl_history[len(atm.ppl_history)-1].val_perplexity
    
    // Calculate % change
    change := math.Abs(current_ppl - recent_ppl) / recent_ppl
    
    return change < atm.convergence_threshold
}

// ============================================
// Statistics and Reporting
// ============================================

// Get current statistics
func (atm *AdvancedTrainingMonitor) get_stats(): map[string]interface{} {
    if len(atm.steps) == 0 {
        return map[string]interface{}{
            "status": "no_data",
        }
    }
    
    first := atm.steps[0]
    last := atm.steps[len(atm.steps)-1]
    
    // Calculate statistics
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
    
    // PPL improvement
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

// Generate detailed report
func (atm *AdvancedTrainingMonitor) generate_report(): string {
    stats := atm.get_stats()
    
    report := "╔════════════════════════════════════════════════════════════╗\n"
    report += "║          🎯 NeurX Advanced Training Report                 ║\n"
    report += "╚════════════════════════════════════════════════════════════╝\n\n"
    
    // Loss metrics
    report += "📊 Loss Metrics:\n"
    report += "├─ Current: " + fmt.Sprintf("%.4f", stats["current_loss"]) + "\n"
    report += "├─ Average: " + fmt.Sprintf("%.4f", stats["average_loss"]) + "\n"
    report += "├─ Min: " + fmt.Sprintf("%.4f", stats["min_loss"]) + "\n"
    report += "└─ Max: " + fmt.Sprintf("%.4f", stats["max_loss"]) + "\n\n"
    
    // Perplexity metrics
    report += "📈 Perplexity Progression:\n"
    report += "├─ Initial: " + fmt.Sprintf("%.1f", stats["initial_perplexity"]) + "\n"
    report += "├─ Current: " + fmt.Sprintf("%.1f", stats["final_perplexity"]) + "\n"
    report += "├─ Best: " + fmt.Sprintf("%.1f", stats["best_perplexity"]) + " (Step " + fmt.Sprintf("%d", stats["best_step"]) + ")\n"
    report += "└─ Improvement: " + fmt.Sprintf("%.2f%%", stats["perplexity_improvement_percent"]) + "\n\n"
    
    // Time metrics
    report += "⏱️  Time Metrics:\n"
    report += "├─ Elapsed: " + format_time(stats["time_elapsed"].(float)) + "\n"
    report += "├─ Estimated Total: " + format_time(stats["estimated_total_time"].(float)) + "\n"
    report += "└─ Progress: " + fmt.Sprintf("%.1f%%", float(stats["total_steps"].(int))/float(atm.total_steps)*100) + "\n\n"
    
    // Performance
    report += "🚀 Performance:\n"
    report += "├─ Average Throughput: " + fmt.Sprintf("%.0f", stats["average_throughput"]) + " tok/s\n"
    report += "├─ Steps Completed: " + fmt.Sprintf("%d", stats["total_steps"]) + "\n"
    report += "└─ Status: "
    
    if stats["is_converged"].(bool) {
        report += "✅ Converged\n"
    } else {
        report += "🔄 Training in progress\n"
    }
    
    // Perplexity trend
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

// Export as JSON
func (atm *AdvancedTrainingMonitor) export_json(): string {
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

// ============================================
// Helper Functions
// ============================================

func format_time(seconds: float): string {
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

// ============================================
// Example Usage
// ============================================

func main() {
    // Initialize advanced monitor
    monitor := &AdvancedTrainingMonitor{}
    if err := monitor.init(100000, "./logs/training_advanced.jsonl", 100, 500); err != nil {
        println("Error:", err.Error())
        return
    }
    
    // Simulate training
    for step := 100; step <= 10000; step += 100 {
        loss := 5.0 - float(step/1000)*0.8 + math.Sin(float(step))*0.1
        val_loss := 4.8 - float(step/1000)*0.7 + math.Sin(float(step/2))*0.15
        
        ppl_metric := PerplexityMetrics{
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
    
    // Print final report
    println("\n" + monitor.generate_report())
}
