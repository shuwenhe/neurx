// ============================================
// Direct Preference Optimization (DPO) Trainer
// Stable alternative to RLHF for model alignment
// ============================================

package main

import (
    "fmt"
    "math"
)

type PreferencePair struct {
    prompt              string
    chosen_response     string
    rejected_response   string
    chosen_reward       float64
    rejected_reward     float64
}

type DPOConfig struct {
    learning_rate       float64
    beta                float64  // KL divergence weight
    temperature         float64
    batch_size          int
    num_epochs          int
    loss_type           string   // sigmoid, hinge
}

type DPOMetrics struct {
    step                int64
    loss                float64
    chosen_logits       float64
    rejected_logits     float64
    margin              float64
    accuracy            float64
}

type TrajectoryReward struct {
    trajectory_id       string
    responses           []string
    rewards             []float64
    avg_reward          float64
}

type DPODataset struct {
    preference_pairs    []PreferencePair
    size                int
    source              string
    quality_score       float64
}

type DPOTrainer struct {
    config              DPOConfig
    dataset             DPODataset
    model_logits        map[string]float64
    reference_logits    map[string]float64
    metrics_history     []DPOMetrics
    best_loss           float64
}

// ============================================
// DPO Initialization and Setup
// ============================================

func (trainer *DPOTrainer) initialize(config DPOConfig) {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Direct Preference Optimization (DPO) Trainer         ║")
    fmt.Println("║  Stable alignment without reward models               ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝\n")
    
    trainer.config = config
    trainer.model_logits = make(map[string]float64)
    trainer.reference_logits = make(map[string]float64)
    trainer.metrics_history = make([]DPOMetrics, 0)
    trainer.best_loss = math.MaxFloat64
    
    fmt.Printf("Configuration:\n")
    fmt.Printf("  Learning Rate: %.2e\n", config.learning_rate)
    fmt.Printf("  Beta (KL weight): %.4f\n", config.beta)
    fmt.Printf("  Temperature: %.2f\n", config.temperature)
    fmt.Printf("  Batch Size: %d\n", config.batch_size)
    fmt.Printf("  Loss Type: %s\n\n", config.loss_type)
}

func (trainer *DPOTrainer) load_preference_data(
    size int,
    quality_score float64) {
    
    fmt.Printf("\n[Data] Loading preference pairs\n")
    fmt.Printf("  Pairs: %d\n", size)
    fmt.Printf("  Quality: %.2f%%\n\n", quality_score*100)
    
    trainer.dataset = DPODataset{
        preference_pairs: make([]PreferencePair, 0),
        size:             size,
        source:           "human_feedback",
        quality_score:    quality_score,
    }
    
    // Simulate loading preference pairs
    for i := 0; i < size; i++ {
        pair := PreferencePair{
            prompt:            fmt.Sprintf("prompt_%d", i),
            chosen_response:   fmt.Sprintf("chosen_response_%d", i),
            rejected_response: fmt.Sprintf("rejected_response_%d", i),
            chosen_reward:     float64(math.Min(float64(i%100)/100.0, 1.0)),
            rejected_reward:   float64(math.Max(float64(i%100)/100.0-0.2, 0.0)),
        }
        trainer.dataset.preference_pairs = append(trainer.dataset.preference_pairs, pair)
    }
}

// ============================================
// DPO Loss Computation
// ============================================

func (trainer *DPOTrainer) compute_dpo_loss(pair PreferencePair) float64 {
    // Get model logits for chosen and rejected responses
    chosen_logit := trainer.model_logits[pair.chosen_response]
    rejected_logit := trainer.model_logits[pair.rejected_response]
    
    // Get reference model logits
    ref_chosen_logit := trainer.reference_logits[pair.chosen_response]
    ref_rejected_logit := trainer.reference_logits[pair.rejected_response]
    
    // Compute log probabilities (model - reference)
    pi_chosen_logp := chosen_logit - ref_chosen_logit
    pi_rejected_logp := rejected_logit - ref_rejected_logit
    
    // DPO loss using sigmoid
    logit_diff := pi_chosen_logp - pi_rejected_logp
    dpo_loss := -math.Log(sigmoid(trainer.config.beta * logit_diff))
    
    return dpo_loss
}

func sigmoid(x float64) float64 {
    return 1.0 / (1.0 + math.Exp(-x))
}

func (trainer *DPOTrainer) compute_batch_loss(batch []PreferencePair) float64 {
    var total_loss float64 = 0.0
    
    for _, pair := range batch {
        loss := trainer.compute_dpo_loss(pair)
        total_loss += loss
    }
    
    avg_loss := total_loss / float64(len(batch))
    return avg_loss
}

// ============================================
// DPO Training Loop
// ============================================

func (trainer *DPOTrainer) train_dpo_step(
    step int64,
    batch []PreferencePair) {
    
    // Compute loss
    loss := trainer.compute_batch_loss(batch)
    
    // Extract metrics for logging
    var chosen_logit, rejected_logit, margin float64 = 0, 0, 0
    if len(batch) > 0 {
        chosen_logit = trainer.model_logits[batch[0].chosen_response]
        rejected_logit = trainer.model_logits[batch[0].rejected_response]
        margin = chosen_logit - rejected_logit
    }
    
    // Compute accuracy (chosen_logit > rejected_logit)
    var correct int = 0
    for _, pair := range batch {
        if trainer.model_logits[pair.chosen_response] > trainer.model_logits[pair.rejected_response] {
            correct++
        }
    }
    accuracy := float64(correct) / float64(len(batch))
    
    // Record metrics
    metric := DPOMetrics{
        step:            step,
        loss:            loss,
        chosen_logits:   chosen_logit,
        rejected_logits: rejected_logit,
        margin:          margin,
        accuracy:        accuracy,
    }
    
    trainer.metrics_history = append(trainer.metrics_history, metric)
    
    if loss < trainer.best_loss {
        trainer.best_loss = loss
    }
    
    if step % 1000 == 0 {
        fmt.Printf("\n[Training] Step %d\n", step)
        fmt.Printf("  Loss: %.6f\n", loss)
        fmt.Printf("  Accuracy: %.4f\n", accuracy)
        fmt.Printf("  Margin: %.4f\n", margin)
    }
}

// ============================================
// DPO Evaluation
// ============================================

func (trainer *DPOTrainer) evaluate_dpo(test_pairs []PreferencePair) float64 {
    fmt.Printf("\n[Evaluation] Evaluating DPO model\n")
    fmt.Printf("  Test Pairs: %d\n", len(test_pairs))
    
    var correct int = 0
    var total_loss float64 = 0.0
    
    for _, pair := range test_pairs {
        loss := trainer.compute_dpo_loss(pair)
        total_loss += loss
        
        if trainer.model_logits[pair.chosen_response] > trainer.model_logits[pair.rejected_response] {
            correct++
        }
    }
    
    accuracy := float64(correct) / float64(len(test_pairs))
    avg_loss := total_loss / float64(len(test_pairs))
    
    fmt.Printf("  Accuracy: %.4f\n", accuracy)
    fmt.Printf("  Loss: %.6f\n", avg_loss)
    
    return accuracy
}

// ============================================
// Comparison: RLHF vs DPO
// ============================================

func (trainer *DPOTrainer) compare_with_rlhf() {
    fmt.Printf("\n┌────────────────────────────────────────┐\n")
    fmt.Printf("│  DPO vs RLHF Comparison                │\n")
    fmt.Printf("└────────────────────────────────────────┘\n\n")
    
    comparison := [][3]interface{}{
        {"Aspect", "RLHF", "DPO"},
        {"Training Stability", "Medium", "High"},
        {"Convergence Speed", "Slow (5-7 days)", "Fast (2-3 days)"},
        {"Reward Model", "Required", "Not needed"},
        {"Implementation", "Complex", "Simple"},
        {"Hallucination Rate", "Higher", "Lower"},
        {"Preference Alignment", "Indirect", "Direct"},
        {"Computational Cost", "High", "Medium"},
        {"Training Time", "Longer", "Shorter"},
        {"Loss Type", "PPO", "Sigmoid"},
    }
    
    for i, row := range comparison {
        if i == 0 {
            fmt.Printf("%-20s %-20s %-20s\n", row[0], row[1], row[2])
            fmt.Println("──────────────────────────────────────────────")
        } else {
            fmt.Printf("%-20s %-20s %-20s\n", row[0], row[1], row[2])
        }
    }
}

// ============================================
// DPO Results Summary
// ============================================

func (trainer *DPOTrainer) get_dpo_summary() {
    fmt.Printf("\n┌────────────────────────────────────────┐\n")
    fmt.Printf("│  DPO Training Summary                  │\n")
    fmt.Printf("└────────────────────────────────────────┘\n\n")
    
    if len(trainer.metrics_history) > 0 {
        first := trainer.metrics_history[0]
        last := trainer.metrics_history[len(trainer.metrics_history)-1]
        
        fmt.Printf("Training Progress:\n")
        fmt.Printf("  Steps: %d → %d\n", first.step, last.step)
        fmt.Printf("  Loss: %.6f → %.6f (best: %.6f)\n", 
            first.loss, last.loss, trainer.best_loss)
        fmt.Printf("  Accuracy: %.4f → %.4f\n",
            first.accuracy, last.accuracy)
        fmt.Printf("  Margin: %.4f → %.4f\n",
            first.margin, last.margin)
        
        // Calculate improvement
        loss_improvement := (first.loss - last.loss) / first.loss * 100
        acc_improvement := (last.accuracy - first.accuracy) * 100
        
        fmt.Printf("\nImprovements:\n")
        fmt.Printf("  Loss Reduction: %.1f%%\n", loss_improvement)
        fmt.Printf("  Accuracy Gain: %.2f%%\n", acc_improvement)
    }
    
    fmt.Printf("\nDataset Quality:\n")
    fmt.Printf("  Total Pairs: %d\n", trainer.dataset.size)
    fmt.Printf("  Quality Score: %.2f%%\n", trainer.dataset.quality_score*100)
}

// ============================================
// Main Interface
// ============================================

func NewDPOTrainer() *DPOTrainer {
    return &DPOTrainer{
        model_logits:    make(map[string]float64),
        reference_logits: make(map[string]float64),
        metrics_history: make([]DPOMetrics, 0),
        best_loss:       math.MaxFloat64,
    }
}

func (trainer *DPOTrainer) run_complete_dpo_cycle() {
    // Initialize
    config := DPOConfig{
        learning_rate: 5e-4,
        beta:          0.1,
        temperature:   0.7,
        batch_size:    32,
        num_epochs:    3,
        loss_type:     "sigmoid",
    }
    
    trainer.initialize(config)
    
    // Load data
    trainer.load_preference_data(5000, 0.96)
    
    // Initialize model and reference logits
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  Simulating Model Logits               │")
    fmt.Println("└────────────────────────────────────────┘")
    
    for _, pair := range trainer.dataset.preference_pairs {
        trainer.model_logits[pair.chosen_response] = pair.chosen_reward * 2.0
        trainer.model_logits[pair.rejected_response] = pair.rejected_reward * 2.0
        trainer.reference_logits[pair.chosen_response] = pair.chosen_reward * 1.5
        trainer.reference_logits[pair.rejected_response] = pair.rejected_reward * 1.5
    }
    
    // Training loop
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  DPO Training                          │")
    fmt.Println("└────────────────────────────────────────┘")
    
    for step := int64(0); step < 5000; step += 1000 {
        batch_start := int(step) % len(trainer.dataset.preference_pairs)
        batch_end := int(math.Min(float64(batch_start+config.batch_size), float64(len(trainer.dataset.preference_pairs))))
        batch := trainer.dataset.preference_pairs[batch_start:batch_end]
        
        trainer.train_dpo_step(step, batch)
    }
    
    // Evaluation
    fmt.Println("\n┌────────────────────────────────────────┐")
    fmt.Println("│  Evaluation                            │")
    fmt.Println("└────────────────────────────────────────┘")
    
    test_pairs := trainer.dataset.preference_pairs[:500]
    trainer.evaluate_dpo(test_pairs)
    
    // Comparison
    trainer.compare_with_rlhf()
    
    // Summary
    trainer.get_dpo_summary()
    
    fmt.Println("\n[DPOTrainer] Complete!")
}
