#!/usr/bin/env s

// ============================================
// NeurX Training Monitor and Logger
// Purpose: Real-time training progress monitoring
// Language: S
// ============================================

package main

import (
    "time"
    "os"
    "fmt"
    "encoding/json"
)

// training_metrics captures single step metrics
type training_metrics struct {
    step: int
    epoch: int
    loss: float
    learning_rate: float
    throughput: float  // tokens/sec
    time_elapsed: float  // seconds
    eta: float  // estimated time to completion in seconds
    memory_used: float  // MB
}

// training_monitor tracks training progress
type training_monitor struct {
    start_time: time.Time
    steps: []training_metrics
    total_steps: int
    log_file: string
    update_interval: int  // Update UI every N steps
}

// Initialize monitor
func (tm *training_monitor) init(
    total_steps: int,
    log_file: string,
    update_interval: int) error {
    
    tm.start_time = time.Now()
    tm.steps = make([]training_metrics, 0)
    tm.total_steps = total_steps
    tm.log_file = log_file
    tm.update_interval = update_interval
    
    // Create log file
    f, err := os.Create(log_file)
    if err != nil {
        return err
    }
    defer f.Close()
    
    return nil
}

// Log training step
func (tm *training_monitor) log_step(
    step: int,
    epoch: int,
    loss: float,
    learning_rate: float,
    throughput: float,
    memory_used: float) {
    
    elapsed := time.Since(tm.start_time).Seconds()
    
    // Calculate ETA
    avg_step_time := 0.0
    if step > 0 {
        avg_step_time = elapsed / float(step)
    }
    remaining_steps := tm.total_steps - step
    eta := avg_step_time * float(remaining_steps)
    
    // Create metrics
    metrics := training_metrics{
        step: step,
        epoch: epoch,
        loss: loss,
        learning_rate: learning_rate,
        throughput: throughput,
        time_elapsed: elapsed,
        eta: eta,
        memory_used: memory_used,
    }
    
    tm.steps = append(tm.steps, metrics)
    
    // Print progress if needed
    if step % tm.update_interval == 0 {
        tm.print_progress(metrics)
    }
    
    // Log to file
    tm.log_to_file(metrics)
}

// Print progress bar
func (tm *training_monitor) print_progress(metrics: training_metrics) {
    progress := float(metrics.step) / float(tm.total_steps) * 100.0
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
    
    // Format ETA
    eta_str := format_time(metrics.eta)
    elapsed_str := format_time(metrics.time_elapsed)
    
    // Print status line
    status := fmt.Sprintf(
        "%s %.1f%% | Step %d/%d | Loss: %.4f | LR: %.2e | Speed: %.0f tok/s | Mem: %.1fMB | Elapsed: %s | ETA: %s",
        bar, progress, metrics.step, tm.total_steps,
        metrics.loss, metrics.learning_rate, metrics.throughput,
        metrics.memory_used, elapsed_str, eta_str)
    
    println(status)
}

// Log to file
func (tm *training_monitor) log_to_file(metrics: training_metrics) {
    f, err := os.OpenFile(tm.log_file, os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        return
    }
    defer f.Close()
    
    json_data, _ := json.Marshal(metrics)
    f.WriteString(string(json_data) + "\n")
}

// Get current statistics
func (tm *training_monitor) get_stats(): map[string]interface{} {
    if len(tm.steps) == 0 {
        return map[string]interface{}{
            "status": "no_data",
        }
    }
    
    first := tm.steps[0]
    last := tm.steps[len(tm.steps)-1]
    
    // Calculate statistics
    avg_loss := 0.0
    min_loss := last.loss
    max_loss := first.loss
    
    for _, m := range tm.steps {
        avg_loss += m.loss
        if m.loss < min_loss {
            min_loss = m.loss
        }
        if m.loss > max_loss {
            max_loss = m.loss
        }
    }
    avg_loss = avg_loss / float(len(tm.steps))
    
    // Calculate improvement
    improvement := (first.loss - last.loss) / first.loss * 100.0
    
    return map[string]interface{}{
        "total_steps": len(tm.steps),
        "current_step": last.step,
        "current_loss": last.loss,
        "average_loss": avg_loss,
        "min_loss": min_loss,
        "max_loss": max_loss,
        "improvement_percent": improvement,
        "average_throughput": last.throughput,
        "time_elapsed": last.time_elapsed,
        "estimated_total_time": last.time_elapsed + last.eta,
    }
}

// Generate training report
func (tm *training_monitor) generate_report(): string {
    stats := tm.get_stats()
    
    report := "========================================\n"
    report += "🎯 NeurX Training Report\n"
    report += "========================================\n\n"
    
    report += "📊 Loss Metrics:\n"
    report += "├─ Current: " + fmt.Sprintf("%.4f", stats["current_loss"]) + "\n"
    report += "├─ Average: " + fmt.Sprintf("%.4f", stats["average_loss"]) + "\n"
    report += "├─ Best: " + fmt.Sprintf("%.4f", stats["min_loss"]) + "\n"
    report += "└─ Improvement: " + fmt.Sprintf("%.2f%%", stats["improvement_percent"]) + "\n\n"
    
    report += "⏱️ Time Metrics:\n"
    report += "├─ Elapsed: " + format_time(stats["time_elapsed"].(float)) + "\n"
    report += "└─ Estimated Total: " + format_time(stats["estimated_total_time"].(float)) + "\n\n"
    
    report += "🚀 Performance:\n"
    report += "├─ Steps Completed: " + fmt.Sprintf("%d", stats["total_steps"]) + "\n"
    report += "├─ Avg Throughput: " + fmt.Sprintf("%.0f", stats["average_throughput"]) + " tok/s\n"
    report += "└─ Completion: " + fmt.Sprintf("%.1f%%", float(stats["total_steps"].(int))/float(tm.total_steps)*100) + "\n"
    
    return report
}

// Export training history as JSON
func (tm *training_monitor) export_json(): string {
    data := map[string]interface{}{
        "training_info": tm.get_stats(),
        "history": tm.steps,
    }
    
    json_bytes, _ := json.Marshal(data)
    return string(json_bytes)
}

// Helper functions
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

// Example main function
func main() {
    // Initialize monitor
    monitor := &training_monitor{}
    if err := monitor.init(10000, "./logs/training.jsonl", 100); err != nil {
        println("Error:", err.Error())
        return
    }
    
    // Simulate training steps
    for step := 100; step <= 1000; step += 100 {
        loss := 5.0 - float(step/100)*0.4 + (math.Sin(float(step))*0.1)
        lr := 5e-4 * math.Cos(float(step)/1000*3.14159)
        throughput := 1000.0 + math.Sin(float(step))*100
        memory := 512.0 + float(step/100)*32
        
        monitor.log_step(step, 1, loss, lr, throughput, memory)
    }
    
    // Print final report
    println("\n" + monitor.generate_report())
    
    // Export JSON
    println("\nJSON Export:")
    println(monitor.export_json())
}
