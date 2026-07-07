// ============================================
// Supervised Fine-Tuning (SFT) Framework
// For instruction-following ability
// ============================================

package main

import (
    "fmt"
    "json"
    "math"
    "strings"
    "time"
)

type InstructionExample struct {
    string instruction
    string input
    string output
    string category
    int difficulty  // 1-5
    float64 quality_score
    []int tokens
}

type instruction_dataset struct {
    []InstructionExample examples
    map[string]int categories
    int64 total_tokens
}

type SFTConfig struct {
    float64 learning_rate
    int warmup_steps
    int total_steps
    int batch_size
    int gradient_accumulation
    int max_seq_length
    int eval_interval
    int save_interval
    float64 weight_decay
    float64 dropout
}

type SFTTrainer struct {
    SFTConfig config
    PolicyModel model
    Optimizer optimizer
    instruction_dataset dataset
    instruction_dataset val_dataset
    int step_count
    []sft_metric training_history
}

type sft_metric struct {
    int step
    float64 loss
    float64 perplexity
    float64 accuracy
    float64 bleu_score
    float64 rouge_score
    float64 eval_loss
    float64 eval_perplexity
    float64 learning_rate
    float64 throughput
    int64 timestamp
}

// ============================================
// Data Loading and Processing
// ============================================

func (trainer *SFTTrainer) load_instruction_data(data_path string) {
    fmt.Printf("[SFT] Loading instruction data from %s\n", data_path)
    
    // Simulate loading instruction data
    categories := []string{"math", "writing", "coding", "qa", "reasoning"}
    
    for i := 0; i < 2000; i++ {
        category := categories[i%len(categories)]
        
        example := InstructionExample{
            instruction: fmt.Sprintf("Solve this problem: %d", i),
            input: fmt.Sprintf("Input data %d", i),
            output: fmt.Sprintf("The solution is %d", i*2),
            category: category,
            difficulty: (i % 5) + 1,
            quality_score: 0.7 + float64(i%30)/100.0,
        }
        
        // Tokenize
        full_text := fmt.Sprintf("%s %s %s", example.instruction, example.input, example.output)
        example.tokens = trainer.tokenize(full_text)
        
        trainer.dataset.examples = append(trainer.dataset.examples, example)
        
        if trainer.dataset.categories[category] == 0 {
            trainer.dataset.categories[category] = 0
        }
        trainer.dataset.categories[category]++
        trainer.dataset.total_tokens += int64(len(example.tokens))
    }
    
    fmt.Printf("  Loaded %d instruction examples\n", len(trainer.dataset.examples))
    fmt.Printf("  Total tokens: %d\n", trainer.dataset.total_tokens)
}

func (trainer *SFTTrainer) tokenize(text string) []int {
    words := strings.Split(text, " ")
    tokens := []int{}
    for i, word := range words {
        token := (len(word) + i*73) % 128000
        tokens = append(tokens, token)
    }
    return tokens
}

// ============================================
// Loss Functions
// ============================================

func (trainer *SFTTrainer) causal_language_modeling_loss(logits [][]float64, labels []int) float64 {
    loss := 0.0
    
    for i := 0; i < len(labels)-1; i++ {
        target_token := labels[i+1]
        
        // Softmax
        max_logit := logits[i][0]
        for j := range logits[i] {
            if logits[i][j] > max_logit {
                max_logit = logits[i][j]
            }
        }
        
        sum_exp := 0.0
        for j := range logits[i] {
            sum_exp += math.Exp(logits[i][j] - max_logit)
        }
        
        log_softmax := logits[i][target_token] - max_logit - math.Log(sum_exp)
        loss -= log_softmax
    }
    
    return loss / float64(len(labels)-1)
}

func (trainer *SFTTrainer) perplexity(loss float64) float64 {
    return math.Exp(loss)
}

// ============================================
// Tokenization and Batching
// ============================================

func (trainer *SFTTrainer) create_batch(examples []InstructionExample) ([][]int, [][]int) {
    inputs := [][]int{}
    labels := [][]int{}
    
    for _, example := range examples {
        if len(example.tokens) < trainer.config.max_seq_length {
            input := example.tokens
            label := example.tokens[1:] // Shifted for next-token prediction
            
            // Pad to max length
            for len(input) < trainer.config.max_seq_length {
                input = append(input, 0) // Padding token
                label = append(label, -100) // Ignore index
            }
            
            inputs = append(inputs, input[:trainer.config.max_seq_length])
            labels = append(labels, label[:trainer.config.max_seq_length])
        }
    }
    
    return inputs, labels
}

// ============================================
// Training Step
// ============================================

func (trainer *SFTTrainer) train_step(batch_inputs [][]int, batch_labels [][]int) float64 {
    total_loss := 0.0
    
    for i := 0; i < len(batch_inputs); i++ {
        // Forward pass
        logits := trainer.model_forward(batch_inputs[i])
        
        // Calculate loss
        loss := trainer.causal_language_modeling_loss(logits, batch_labels[i])
        total_loss += loss
        
        // Backward pass (simulated)
        trainer.optimizer.backward(loss)
    }
    
    // Gradient clipping
    trainer.optimizer.clip_grad_norm(1.0)
    
    // Optimizer step
    trainer.optimizer.step()
    trainer.step_count += 1
    
    return total_loss / float64(len(batch_inputs))
}

func (trainer *SFTTrainer) model_forward(tokens []int) [][]float64 {
    batch_size := 1
    vocab_size := 128000
    seq_len := len(tokens)
    
    // Simulate forward pass through transformer
    logits := make([][]float64, seq_len)
    for i := 0; i < seq_len; i++ {
        logits[i] = make([]float64, vocab_size)
        for j := 0; j < vocab_size; j++ {
            logits[i][j] = math.Sin(float64(tokens[i]) / float64(vocab_size)) * 
                          math.Cos(float64(j) / float64(seq_len))
        }
    }
    
    return logits
}

// ============================================
// Evaluation
// ============================================

func (trainer *SFTTrainer) evaluate(dataset instruction_dataset) sft_metric {
    fmt.Printf("[SFT] Evaluating on %d examples\n", len(dataset.examples))
    
    total_loss := 0.0
    total_tokens := 0
    
    for _, example := range dataset.examples {
        if len(example.tokens) == 0 {
            continue
        }
        
        // Forward pass
        logits := trainer.model_forward(example.tokens)
        
        // Loss
        labels := example.tokens[1:]
        loss := trainer.causal_language_modeling_loss(logits, labels)
        total_loss += loss
        total_tokens += len(example.tokens)
    }
    
    avg_loss := total_loss / float64(len(dataset.examples))
    ppl := trainer.perplexity(avg_loss)
    
    metric := sft_metric{
        step: trainer.step_count,
        eval_loss: avg_loss,
        eval_perplexity: ppl,
        timestamp: time.Now().Unix(),
    }
    
    return metric
}

// ============================================
// Learning Rate Scheduling
// ============================================

func (trainer *SFTTrainer) get_learning_rate() float64 {
    if trainer.step_count < trainer.config.warmup_steps {
        // Linear warmup
        return trainer.config.learning_rate * float64(trainer.step_count) / float64(trainer.config.warmup_steps)
    } else {
        // Cosine annealing
        progress := float64(trainer.step_count-trainer.config.warmup_steps) / 
                   float64(trainer.config.total_steps-trainer.config.warmup_steps)
        return trainer.config.learning_rate * 0.5 * (1.0 + math.Cos(math.Pi*progress))
    }
}

// ============================================
// Generation Quality Metrics
// ============================================

func (trainer *SFTTrainer) calculate_bleu(reference []int, generated []int, n_gram int) float64 {
    if len(generated) == 0 {
        return 0.0
    }
    
    matches := 0
    total := 0
    
    for i := 0; i <= len(generated)-n_gram; i++ {
        found := false
        for j := 0; j <= len(reference)-n_gram; j++ {
            match := true
            for k := 0; k < n_gram; k++ {
                if generated[i+k] != reference[j+k] {
                    match = false
                    break
                }
            }
            if match {
                found = true
                break
            }
        }
        if found {
            matches += 1
        }
        total += 1
    }
    
    return float64(matches) / float64(total)
}

func (trainer *SFTTrainer) calculate_rouge_l(reference []int, generated []int) float64 {
    if len(reference) == 0 || len(generated) == 0 {
        return 0.0
    }
    
    // Longest common subsequence
    lcs := trainer.compute_lcs(reference, generated)
    recall := float64(lcs) / float64(len(reference))
    precision := float64(lcs) / float64(len(generated))
    
    if recall+precision == 0 {
        return 0.0
    }
    
    f1 := 2 * (recall * precision) / (recall + precision)
    return f1
}

func (trainer *SFTTrainer) compute_lcs(a []int, b []int) int {
    dp := make([][]int, len(a)+1)
    for i := range dp {
        dp[i] = make([]int, len(b)+1)
    }
    
    for i := 1; i <= len(a); i++ {
        for j := 1; j <= len(b); j++ {
            if a[i-1] == b[j-1] {
                dp[i][j] = dp[i-1][j-1] + 1
            } else {
                if dp[i-1][j] > dp[i][j-1] {
                    dp[i][j] = dp[i-1][j]
                } else {
                    dp[i][j] = dp[i][j-1]
                }
            }
        }
    }
    
    return dp[len(a)][len(b)]
}

// ============================================
// Main Training Interface
// ============================================

func NewSFTTrainer(config SFTConfig) *SFTTrainer {
    return &SFTTrainer{
        config: config,
        model: PolicyModel{
            model_name: "gpt_large",
            num_layers: 12,
            hidden_size: 768,
            vocab_size: 128000,
        },
        optimizer: Optimizer{
            name: "adamw",
            learning_rate: config.learning_rate,
            beta1: 0.9,
            beta2: 0.999,
            epsilon: 1e-8,
            weight_decay: config.weight_decay,
        },
        dataset: instruction_dataset{
            examples: []InstructionExample{},
            categories: make(map[string]int),
        },
        val_dataset: instruction_dataset{
            examples: []InstructionExample{},
            categories: make(map[string]int),
        },
        step_count: 0,
        training_history: []sft_metric{},
    }
}

func (trainer *SFTTrainer) train() {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Supervised Fine-Tuning (SFT) for Instruction Following║")
    fmt.Println("╚════════════════════════════════════════════════════════╝")
    
    trainer.load_instruction_data("data/instructions")
    
    num_batches := len(trainer.dataset.examples) / trainer.config.batch_size
    
    for step := 0; step < trainer.config.total_steps && step < 1000; step++ {
        batch_start := (step % num_batches) * trainer.config.batch_size
        batch_end := batch_start + trainer.config.batch_size
        if batch_end > len(trainer.dataset.examples) {
            batch_end = len(trainer.dataset.examples)
        }
        
        batch_examples := trainer.dataset.examples[batch_start:batch_end]
        batch_inputs, batch_labels := trainer.create_batch(batch_examples)
        
        loss := trainer.train_step(batch_inputs, batch_labels)
        
        if (step + 1) % trainer.config.eval_interval == 0 {
            eval_metric := trainer.evaluate(trainer.val_dataset)
            fmt.Printf("\n[Step %d] Train Loss: %.6f | Val Loss: %.6f | Val PPL: %.2f | LR: %.2e\n",
                step+1, loss, eval_metric.eval_loss, eval_metric.eval_perplexity, trainer.get_learning_rate())
            trainer.training_history = append(trainer.training_history, eval_metric)
        }
        
        if (step + 1) % trainer.config.save_interval == 0 {
            trainer.save_checkpoint(step + 1)
        }
    }
    
    trainer.print_summary()
}

func (trainer *SFTTrainer) save_checkpoint(step int) {
    fmt.Printf("[SFT] Saving checkpoint at step %d\n", step)
}

func (trainer *SFTTrainer) print_summary() {
    fmt.Println("\n╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  SFT Training Summary                                 ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝")
    fmt.Printf("Total Steps: %d\n", trainer.step_count)
    fmt.Printf("Training Examples: %d\n", len(trainer.dataset.examples))
    fmt.Printf("Total Tokens: %d\n", trainer.dataset.total_tokens)
    
    if len(trainer.training_history) > 0 {
        latest := trainer.training_history[len(trainer.training_history)-1]
        fmt.Printf("Final Validation Loss: %.6f\n", latest.eval_loss)
        fmt.Printf("Final Perplexity: %.2f\n", latest.eval_perplexity)
    }
}
