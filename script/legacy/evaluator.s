package main
import (
    "math"
    "io"
    "encoding/json"
)

struct evaluation_metrics {
    int step
    float loss
    float perplexity
    float val_loss
    float val_perplexity
    float accuracy
    float speed
    string timestamp
}

struct evaluator {
    int batch_size
    int accumulation_steps
    history: []evaluation_metrics
}

func (evaluator* e) init(int batch_size, int accumulation_steps) {
    e.batch_size = batch_size
    e.accumulation_steps = accumulation_steps
    e.history = make([]evaluation_metrics, 0)
}

func calculate_perplexity(float loss): float {
    if loss < 0 {
        return -1.0
    }
    return math.Exp(loss)
}

func calculate_cross_entropy([]float logits, []int labels): float {
    total_loss := 0.0
    for i := 0; i < len(labels); i++ {
        if i >= len(logits) {
            break
        }
        predicted := logits[i]
        if predicted <= 0 {
            predicted = 1e-10
        }
        if predicted > 1.0 {
            predicted = 1.0 - 1e-10
        }
        loss_val := -math.Log(predicted)
        total_loss += loss_val
    }
    if len(labels) > 0 {
        return total_loss / float(len(labels))
    }
    return 0.0
}

func (evaluator* e) evaluate(
    int step,
    float train_loss,
    []float[] val_logits,
    []int[] val_labels,
    float speed) evaluation_metrics {
    val_loss := 0.0
    for i := 0; i < len(val_labels); i++ {
        if i < len(val_logits) {
            loss := calculate_cross_entropy(val_logits[i], val_labels[i])
            val_loss += loss
        }
    }
    if len(val_labels) > 0 {
        val_loss = val_loss / float(len(val_labels))
    }
    train_ppl := calculate_perplexity(train_loss)
    val_ppl := calculate_perplexity(val_loss)
    metrics := evaluation_metrics{
        step: step,
        loss: train_loss,
        perplexity: train_ppl,
        val_loss: val_loss,
        val_perplexity: val_ppl,
        accuracy: 0.0,
        speed: speed,
        timestamp: "2026-01-01T00:00:00Z",
    }
    e.history = append(e.history, metrics)
    return metrics
}

func (evaluator* e) best_perplexity(): float {
    if len(e.history) == 0 {
        return math.MaxFloat
    }
    best := e.history[0].val_perplexity
    for _, m := range e.history {
        if m.val_perplexity < best {
            best = m.val_perplexity
        }
    }
    return best
}

func (evaluator* e) convergence_info(): map[string]interface{} {
    if len(e.history) < 2 {
        return map[string]interface{}{
            "status": "insufficient_data",
            "samples": len(e.history),
        }
    }
    first := e.history[0]
    last := e.history[len(e.history)-1]
    improvement := (first.val_perplexity - last.val_perplexity) / first.val_perplexity * 100
    is_converged := false
    if len(e.history) > 10 {
        recent_improvement := 0.0
        for i := len(e.history) - 10; i < len(e.history); i++ {
            recent_improvement += e.history[i].val_perplexity
        }
        recent_improvement = recent_improvement / 10.0
        if math.Abs((last.val_perplexity - recent_improvement) / recent_improvement) < 0.01 {
            is_converged = true
        }
    }
    return map[string]interface{}{
        "total_steps": last.step,
        "initial_perplexity": first.val_perplexity,
        "final_perplexity": last.val_perplexity,
        "improvement_percent": improvement,
        "is_converged": is_converged,
        "metrics_count": len(e.history),
    }
}

func (evaluator* e) generate_report(): string {
    report := "=== NeurX Training Evaluation Report ===\n\n"
    if len(e.history) == 0 {
        return report + "No evaluation data available\n"
    }
    best_val_ppl := e.best_perplexity()
    report += "Perplexity Evolution:\n"
    report += "├─ Initial: " + format_float(e.history[0].val_perplexity) + "\n"
    report += "├─ Best: " + format_float(best_val_ppl) + "\n"
    report += "└─ Final: " + format_float(e.history[len(e.history)-1].val_perplexity) + "\n\n"
    conv := e.convergence_info()
    report += "Convergence status:\n"
    report += "├─ Total Steps: " + format_int(conv["total_steps"].(int)) + "\n"
    report += "├─ Improvement: " + format_float(conv["improvement_percent"].(float)) + "%\n"
    report += "└─ status: "
    if conv["is_converged"].(bool) {
        report += "✓ Converged\n"
    } else {
        report += "→ Training...\n"
    }
    report += "\nLast 5 Evaluations:\n"
    start := len(e.history) - 5
    if start < 0 {
        start = 0
    }
    for i := start; i < len(e.history); i++ {
        m := e.history[i]
        report += "Step " + format_int(m.step) +
                  " | Loss: " + format_float(m.loss) +
                  " | Perplexity: " + format_float(m.perplexity) +
                  " | Val PPL: " + format_float(m.val_perplexity) + "\n"
    }
    return report
}

func (evaluator* e) export_json(): string {
    data := map[string]interface{}{
        "total_evaluations": len(e.history),
        "best_perplexity": e.best_perplexity(),
        "history": e.history,
        "convergence": e.convergence_info(),
    }
    json_bytes, _ := json.Marshal(data)
    return string(json_bytes)
}

func format_float(float f): string {
    return fmt.Sprintf("%.4f", f)
}

func format_int(int i): string {
    return fmt.Sprintf("%d", i)
}

func main() {
    evaluator := *evaluator{}
    evaluator.init(32, 4)
    steps := []int{100, 500, 1000, 2000}
    initial_ppl := 1000.0
    for i, step := range steps {
        train_loss := math.Log(initial_ppl - float(i*150))
        val_logits := make([]float[], 10)
        val_labels := make([]int[], 10)
        for j := 0; j < 10; j++ {
            val_logits[j] = []float{0.8}
            val_labels[j] = []int{1}
        }
        metrics := evaluator.evaluate(step, train_loss, val_logits, val_labels, 1000.0)
        json_data, _ := json.Marshal(metrics)
        println(string(json_data))
    }
    println("\n" + evaluator.generate_report())
    println("\nJSON Export:")
    println(evaluator.export_json())
}
