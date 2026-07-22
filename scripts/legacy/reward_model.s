




package main

import (
    "fmt"
    "json"
    "math"
    "time"
)

type preference_data struct {
    prompt              string
    response_a          string
    response_b          string
    preferred           int
    confidence          float64
    annotation_time     int64
    annotator_id        string
}

type preference_dataset struct {
    examples            []preference_data
    train_size          int
    val_size            int
    test_size           int
}

type reward_model_config struct {
    learning_rate       float64
    weight_decay        float64
    num_epochs          int
    batch_size          int
    dropout             float64
    hidden_size         int
    num_layers          int
    max_seq_length      int
    temperature         float64
    save_interval       int
}

type reward_model_trainer struct {
    config              reward_model_config
    model               reward_model
    optimizer           Optimizer
    train_dataset       preference_dataset
    val_dataset         preference_dataset
    test_dataset        preference_dataset
    training_history    []training_metric
    step_count          int
}

type training_metric struct {
    step                int
    train_loss          float64
    train_accuracy      float64
    val_loss            float64
    val_accuracy        float64
    calibration_error   float64
    auc_score           float64
    timestamp           int64
}

type reward_model struct {
    model_name          string
    hidden_size         int
    num_layers          int
    vocab_size          int
    trained_steps       int
    best_val_accuracy   float64
    is_trained          bool
}

type bradley_terry_loss struct {
    reward_a            float64
    reward_b            float64
    preference_label    int
}





func (trainer *reward_model_trainer) load_preference_data(data_path string) {
    fmt.Printf("[Reward Model] Loading preference data from %s\n", data_path)


    for i := 0; i < 1000; i++ {
        example := preference_data{
            prompt: fmt.Sprintf("Prompt %d: What is %d + %d?", i, i%100, (i+1)%100),
            response_a: fmt.Sprintf("The answer is %d", (i%100 + (i+1)%100)),
            response_b: fmt.Sprintf("Calculating: %d + %d = %d", i%100, (i+1)%100, (i%100 + (i+1)%100)),
            preferred: i % 2,
            confidence: 0.8 + float64(i%20)/100.0,
            annotator_id: fmt.Sprintf("annotator_%d", i%10),
        }

        trainer.train_dataset.examples = append(trainer.train_dataset.examples, example)
    }

    trainer.train_dataset.train_size = 800
    trainer.train_dataset.val_size = 100
    trainer.train_dataset.test_size = 100

    fmt.Printf("  Loaded %d preference pairs\n", len(trainer.train_dataset.examples))
}

func (trainer *reward_model_trainer) preprocess_example(example preference_data) ([]float64, int) {

    tokens_a := trainer.tokenize(example.response_a)
    tokens_b := trainer.tokenize(example.response_b)

    features_a := trainer.embed_tokens(tokens_a)
    features_b := trainer.embed_tokens(tokens_b)


    combined := append(features_a, features_b...)

    return combined, example.preferred
}

func (trainer *reward_model_trainer) tokenize(text string) []int {

    words := strings.Split(text, " ")
    tokens := []int{}
    for i, word := range words {
        token := (len(word) + i*73) % trainer.config.vocab_size
        tokens = append(tokens, token)
    }
    return tokens
}

func (trainer *reward_model_trainer) embed_tokens(tokens []int) []float64 {
    embeddings := []float64{}
    for i, token := range tokens {
        emb := math.Sin(float64(token) / 1000.0) * math.Cos(float64(i) / 100.0)
        embeddings = append(embeddings, emb)
    }
    return embeddings
}





func (trainer *reward_model_trainer) bradley_terry_loss(reward_a float64, reward_b float64, preference int) float64 {
    if preference == 0 {

        diff := reward_a - reward_b
        return -trainer.log_sigmoid(diff)
    } else {

        diff := reward_b - reward_a
        return -trainer.log_sigmoid(diff)
    }
}

func (trainer *reward_model_trainer) log_sigmoid(x float64) float64 {
    if x >= 0 {
        return -math.Log(1.0 + math.Exp(-x))
    } else {
        return x - math.Log(1.0+math.Exp(x))
    }
}

func (trainer *reward_model_trainer) sigmoid(x float64) float64 {
    return 1.0 / (1.0 + math.Exp(-x))
}





func (trainer *reward_model_trainer) predict_reward(text string) float64 {
    tokens := trainer.tokenize(text)
    embeddings := trainer.embed_tokens(tokens)


    hidden := 0.0
    for i, emb := range embeddings {
        hidden += emb * math.Cos(float64(i) / 10.0)
    }


    reward := trainer.sigmoid(hidden)
    return reward
}





func (trainer *reward_model_trainer) train_step(batch []preference_data) float64 {
    total_loss := 0.0
    correct := 0

    for _, example := range batch {

        reward_a := trainer.predict_reward(example.response_a)
        reward_b := trainer.predict_reward(example.response_b)


        loss := trainer.bradley_terry_loss(reward_a, reward_b, example.preferred)
        total_loss += loss


        prediction := 0
        if reward_b > reward_a {
            prediction = 1
        }
        if prediction == example.preferred {
            correct += 1
        }
    }

    trainer.step_count += 1
    batch_loss := total_loss / float64(len(batch))
    accuracy := float64(correct) / float64(len(batch))

    return batch_loss
}

func (trainer *reward_model_trainer) evaluate(dataset preference_dataset) training_metric {
    fmt.Printf("[Reward Model] Evaluating on %d examples\n", len(dataset.examples))

    total_loss := 0.0
    correct := 0
    logits := []float64{}
    labels := []int{}

    for _, example := range dataset.examples {
        reward_a := trainer.predict_reward(example.response_a)
        reward_b := trainer.predict_reward(example.response_b)

        loss := trainer.bradley_terry_loss(reward_a, reward_b, example.preferred)
        total_loss += loss

        logits = append(logits, reward_a-reward_b)
        labels = append(labels, example.preferred)

        prediction := 0
        if reward_b > reward_a {
            prediction = 1
        }
        if prediction == example.preferred {
            correct += 1
        }
    }

    avg_loss := total_loss / float64(len(dataset.examples))
    accuracy := float64(correct) / float64(len(dataset.examples))

    metric := training_metric{
        step: trainer.step_count,
        val_loss: avg_loss,
        val_accuracy: accuracy,
        calibration_error: trainer.calculate_calibration_error(logits, labels),
        auc_score: trainer.calculate_auc(logits, labels),
        timestamp: time.Now().Unix(),
    }

    return metric
}

func (trainer *reward_model_trainer) calculate_calibration_error(logits []float64, labels []int) float64 {

    ece := 0.0
    num_bins := 10
    bin_size := 1.0 / float64(num_bins)

    for bin_idx := 0; bin_idx < num_bins; bin_idx++ {
        bin_lower := float64(bin_idx) * bin_size
        bin_upper := float64(bin_idx+1) * bin_size

        in_bin := 0
        correct_in_bin := 0
        avg_conf := 0.0

        for i, logit := range logits {
            conf := trainer.sigmoid(logit)
            if conf >= bin_lower && conf < bin_upper {
                in_bin += 1
                avg_conf += conf
                if (labels[i] == 0 && logit > 0) || (labels[i] == 1 && logit <= 0) {
                    correct_in_bin += 1
                }
            }
        }

        if in_bin > 0 {
            bin_acc := float64(correct_in_bin) / float64(in_bin)
            avg_conf /= float64(in_bin)
            ece += math.Abs(avg_conf-bin_acc) * float64(in_bin) / float64(len(logits))
        }
    }

    return ece
}

func (trainer *reward_model_trainer) calculate_auc(logits []float64, labels []int) float64 {

    pairs := 0
    correct := 0

    for i := range logits {
        for j := i + 1; j < len(logits); j++ {
            if labels[i] != labels[j] {
                pairs += 1
                if (logits[i] > logits[j] && labels[i] == 0) ||
                   (logits[i] < logits[j] && labels[i] == 1) {
                    correct += 1
                }
            }
        }
    }

    if pairs == 0 {
        return 0.5
    }
    return float64(correct) / float64(pairs)
}





func NewRewardModelTrainer(config reward_model_config) *reward_model_trainer {
    return &reward_model_trainer{
        config: config,
        model: reward_model{
            model_name: "reward_model",
            hidden_size: config.hidden_size,
            num_layers: config.num_layers,
            vocab_size: 128000,
            trained_steps: 0,
            best_val_accuracy: 0.0,
        },
        optimizer: Optimizer{
            name: "adamw",
            learning_rate: config.learning_rate,
            beta1: 0.9,
            beta2: 0.999,
            epsilon: 1e-8,
            weight_decay: config.weight_decay,
        },
        train_dataset: preference_dataset{
            examples: []preference_data{},
        },
        val_dataset: preference_dataset{
            examples: []preference_data{},
        },
        test_dataset: preference_dataset{
            examples: []preference_data{},
        },
        training_history: []training_metric{},
        step_count: 0,
    }
}

func (trainer *reward_model_trainer) train() {
    fmt.Println("╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Reward Model Training for Preference Learning        ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝")

    trainer.load_preference_data("data/preferences")

    num_batches := trainer.train_dataset.train_size / trainer.config.batch_size

    for epoch := 0; epoch < trainer.config.num_epochs; epoch++ {
        fmt.Printf("\n[Epoch %d]\n", epoch+1)

        total_loss := 0.0
        for batch := 0; batch < num_batches; batch++ {
            start := batch * trainer.config.batch_size
            end := start + trainer.config.batch_size
            if end > trainer.train_dataset.train_size {
                end = trainer.train_dataset.train_size
            }

            batch_data := trainer.train_dataset.examples[start:end]
            loss := trainer.train_step(batch_data)
            total_loss += loss

            if (batch + 1) % 10 == 0 {
                fmt.Printf("  Batch %d/%d - Loss: %.6f\n", batch+1, num_batches, loss)
            }
        }


        val_metric := trainer.evaluate(trainer.val_dataset)
        fmt.Printf("  Validation - Loss: %.6f, Accuracy: %.4f, ECE: %.4f, AUC: %.4f\n",
            val_metric.val_loss, val_metric.val_accuracy, val_metric.calibration_error, val_metric.auc_score)

        trainer.training_history = append(trainer.training_history, val_metric)

        if val_metric.val_accuracy > trainer.model.best_val_accuracy {
            trainer.model.best_val_accuracy = val_metric.val_accuracy
            trainer.save_checkpoint()
        }
    }

    trainer.print_summary()
}

func (trainer *reward_model_trainer) save_checkpoint() {
    fmt.Printf("[Reward Model] Saving checkpoint (Accuracy: %.4f)\n", trainer.model.best_val_accuracy)
}

func (trainer *reward_model_trainer) print_summary() {
    fmt.Println("\n╔════════════════════════════════════════════════════════╗")
    fmt.Println("║  Reward Model Training Summary                        ║")
    fmt.Println("╚════════════════════════════════════════════════════════╝")
    fmt.Printf("Best Validation Accuracy: %.4f\n", trainer.model.best_val_accuracy)

    if len(trainer.training_history) > 0 {
        latest := trainer.training_history[len(trainer.training_history)-1]
        fmt.Printf("Final Calibration Error: %.4f\n", latest.calibration_error)
        fmt.Printf("Final AUC Score: %.4f\n", latest.auc_score)
    }
}
