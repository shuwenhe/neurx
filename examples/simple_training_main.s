package neurx.examples.simple_training
use neurx.trainer.simple.{simple_config, new_simple_config, simple_training_loop}
func main() {
    simple_config cfg = new_simple_config()
    simple_training_loop(cfg)
}
