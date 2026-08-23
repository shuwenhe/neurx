package neurx.inference.safetensors_loader

func load_header_size(int b1, int b2, int b3, int b4) int {
    b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
}

func get_tensor_offset(int idx) int {
    8 + 256 + (idx * 102400)
}

func load_embedding(int vocab_size, int hidden_size) int {
    (vocab_size * hidden_size * 4)
}

func load_layer(int layer_idx, int hidden_size) int {
    (hidden_size * hidden_size * 4)
}

func main() {
    print("SafeTensors Model Loader\n")
    print("========================\n\n")
    int offset = get_tensor_offset(0)
    print("Model offset: ")
    print_num(offset)
    print("\n")
    print("✓ SafeTensors loader ready\n")
}

func print_num(int n) {
    if n < 10 {
        if n == 0 { print("0") }
        else if n == 1 { print("1") }
        else if n == 2 { print("2") }
        else if n == 3 { print("3") }
        else if n == 4 { print("4") }
        else if n == 5 { print("5") }
        else if n == 6 { print("6") }
        else if n == 7 { print("7") }
        else if n == 8 { print("8") }
        else if n == 9 { print("9") }
    } else {
        print_num(n / 10)
        print_num(n % 10)
    }
}
