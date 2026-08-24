package neurx.runtime.device.device_binding
use neurx.runtime.device.device_ops.{op_int_string}
func binding_buffer(string name, int handle) string {
    "buffer." + name + "=" + op_int_string(handle)
}

func binding_int(string name, int value) string {
    name + "=" + op_int_string(value)
}

func binding_join(string left, string right) string {
    if len(left) == 0 { return right }
    if len(right) == 0 { return left }
    left + ";" + right
}

func embedding_binding(int ids, int weight, int output, int tokens) string {
    binding_buffer("ids", ids) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("output", output) + ";" + binding_int("tokens", tokens)
}

func rms_norm_binding(int input, int weight, int output, int rows) string {
    binding_buffer("input", input) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("output", output) + ";" + binding_int("rows", rows)
}

func linear_binding(int input, int weight, int bias, int output, int rows) string {
    binding_buffer("input", input) + ";" + binding_buffer("weight", weight) + ";" +
        binding_buffer("bias", bias) + ";" + binding_buffer("output", output) + ";" +
        binding_int("rows", rows)
}

func rope_binding(int input, int tokens, int position) string {
    binding_buffer("input", input) + ";" + binding_int("tokens", tokens) + ";" +
        binding_int("position", position)
}

func swiglu_binding(int gate, int up, int output, int elements) string {
    binding_buffer("gate", gate) + ";" + binding_buffer("up", up) + ";" +
        binding_buffer("output", output) + ";" + binding_int("elements", elements)
}

func residual_add_binding(int left, int right, int output, int elements) string {
    binding_buffer("left", left) + ";" + binding_buffer("right", right) + ";" +
        binding_buffer("output", output) + ";" + binding_int("elements", elements)
}

func paged_attention_binding(int query, int key_cache, int value_cache, int block_table,
                             int workspace, int output, int position, int max_sequence,
                             int block_size) string {
    binding_buffer("query", query) + ";" + binding_buffer("key_cache", key_cache) + ";" +
        binding_buffer("value_cache", value_cache) + ";" + binding_buffer("block_table", block_table) + ";" +
        binding_buffer("workspace", workspace) + ";" +
        binding_buffer("output", output) + ";" + binding_int("position", position) + ";" +
        binding_int("max_sequence", max_sequence) + ";" + binding_int("block_size", block_size)
}
