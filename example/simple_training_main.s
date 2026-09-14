package neurx.examples.simple_training
import (
    "neurx.trainer.simple."
)

func main() {
    simple_config cfg = new_simple_config()
    simple_training_loop(cfg)
}
