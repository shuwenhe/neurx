package neurx.examples

import neurx.train.training_main

func main() {
    // Create training config
    train_config cfg = default_training_config()
    
    // Customize
    cfg.batch_size = 64
    cfg.learning_rate = 1e-4
    cfg.num_epochs = 3
    
    // Train
    train_model(cfg)
}
