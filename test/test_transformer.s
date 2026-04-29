package neurx.test_transformer

use neurx.transformer.{transformer_config, transformer_init, transformer_forward}
use neurx.tensor.{tensor, new}

func main() int {
    let config = transformer_config{
        num_layers: 2,
        num_heads: 2,
        d_model: 4,
        d_ff: 8,
        dropout: 0.1,
    }
    let model = transformer_init(config)
    let x = new([
        0.1, 0.2, 0.3, 0.4,
        0.5, 0.6, 0.7, 0.8
    ], [2, 4], false)
    let out = transformer_forward(model, x)
    println("transformer out: ", out.data)
    0
}
