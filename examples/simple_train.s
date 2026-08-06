package neurx.examples
import neurx.train.training_main

func main() {
    train_config cfg = default_training_config()
    cfg.batch_size = 64
    cfg.learning_rate = 1e-4
    cfg.num_epochs = 3
    train_model(cfg)
}

