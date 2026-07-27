package neurx.script.gpu_train
use std.io.println
use neurx.runtime.io.{
    runtime_read_text_file,
    runtime_write_text_file,
    runtime_file_exists,
    runtime_run_command_output,
    runtime_env_get
}
use neurx.cuda.runtime.{
    cuda_malloc, cuda_free, cuda_memcpy_h2d, cuda_memcpy_d2h,
    cublas_create, cublas_destroy, cublas_sgemm,
    linear_forward, linear_backward,
    relu_forward, relu_backward,
    softmax_forward, cross_entropy_backward,
    adam_step, cuda_synchronize,
    get_device_count, get_device_name
}
use neurx.common.parse.{parse_int, parse_float}
use neurx.common.string.{trim, substring, str_len, int_to_str, float_to_str}
type gpu_training_config = struct {
    max_steps: int
    batch_size: int
    seq_len: int
    learning_rate: float
    warmup_steps: int
    log_interval: int
    save_interval: int
    device_id: int
    gradient_accumulation_steps: int
    weight_decay: float
}

type gpu_model = struct {
    embedding_size: int
    hidden_size: int
    num_layers: int
    num_heads: int
    embedding_weight_gpu: int64
    embeddings_layernorm_gpu: int64
    transformer_weights_gpu: int64
    transformer_bias_gpu: int64
    m_gpu: int64
    v_gpu: int64
}

type training_state = struct {
    step: int
    total_loss: float
    samples_seen: int
    batches_completed: int
}

func main() {
    int max_steps = parse_int(runtime_env_get("NEURX_PRETRAIN_STEPS"), 1000000000)
    int batch_size = parse_int(runtime_env_get("NEURX_PRETRAIN_BATCH_SIZE"), 32)
    int seq_len = parse_int(runtime_env_get("NEURX_PRETRAIN_SEQ_LEN"), 256)
    float lr = parse_float(runtime_env_get("NEURX_PRETRAIN_LR"), "0.0002")
    int device_id = parse_int(runtime_env_get("NEURX_GPU_DEVICE"), 0)
    println("=== NeurX GPU-Accelerated Pretraining ===")
    println("Max steps: " + int_to_str(max_steps))
    println("batch_2 size: " + int_to_str(batch_size))
    println("Seq length: " + int_to_str(seq_len))
    println("Learning rate: " + float_to_str(lr))
    println("")
    int device_count = get_device_count()
    println("CUDA devices available: " + int_to_str(device_count))
    if device_id >= device_count {
        println("ERROR: Device " + int_to_str(device_id) + " not found!")
        return
    }
    string device_name = get_device_name(device_id)
    println("Using device: " + device_name)
    println("")
    gpu_model model = gpu_model {
        embedding_size: 768,
        hidden_size: 3072,
        num_layers: 12,
        num_heads: 12,
        embedding_weight_gpu: 0,
        embeddings_layernorm_gpu: 0,
        transformer_weights_gpu: 0,
        transformer_bias_gpu: 0,
        m_gpu: 0,
        v_gpu: 0
    }
    int vocab_size = 50000
    model.embedding_weight_gpu = cuda_malloc(vocab_size * model.embedding_size * 4)
    model.embeddings_layernorm_gpu = cuda_malloc(model.embedding_size * 4)
    int total_weight_size = model.num_layers * model.hidden_size * model.hidden_size
    model.transformer_weights_gpu = cuda_malloc(total_weight_size * 4)
    model.transformer_bias_gpu = cuda_malloc(model.num_layers * model.hidden_size * 4)
    int total_params = vocab_size * model.embedding_size + model.embedding_size + total_weight_size + model.num_layers * model.hidden_size
    model.m_gpu = cuda_malloc(total_params * 4)
    model.v_gpu = cuda_malloc(total_params * 4)
    println("GPU memory allocated for model")
    println("embedding parameters: " + int_to_str(vocab_size * model.embedding_size / 1000000) + "M")
    println("transformer_2 parameters: " + int_to_str(total_weight_size / 1000000) + "M")
    println("")
    training_state state = training_state {
        step: 0,
        total_loss: 0.0,
        samples_seen: 0,
        batches_completed: 0
    }
    int64 cublas_handle = cublas_create()
    string manifest_path = "/home/shuwen/shuwen/train/neurx/dataset/pretrain/manifest.json"
    string manifest_content = runtime_read_text_file(manifest_path)
    int shard_count = count_lines(manifest_content)
    int shard_idx = 0
    while shard_idx < shard_count && state.step < max_steps {
        string shard_file = "/home/shuwen/shuwen/train/neurx/dataset/pretrain/shard/" + int_to_str(shard_idx) + ".jsonl"
        if !runtime_file_exists(shard_file) {
            shard_idx = shard_idx + 1
            continue
        }
        string shard_content = runtime_read_text_file(shard_file)
        int line_start = 0
        int line_end = 0
        int line_idx = 0
        while line_idx < 1000 && state.step < max_steps {
            while line_end < str_len(shard_content) && shard_content[line_end] != 10 {
                line_end = line_end + 1
            }
            string line = substring(shard_content, line_start, line_end)
            float batch_loss = gpu_forward_backward_pass(
                cublas_handle, model,
                batch_size, seq_len,
                line
            )
            state.total_loss = state.total_loss + batch_loss
            state.samples_seen = state.samples_seen + 1
            state.step = state.step + 1
            if state.step % 100 == 0 {
                float avg_loss = state.total_loss / float(state.samples_seen)
                println("Step " + int_to_str(state.step) +
                        " | Loss: " + float_to_str(avg_loss) +
                        " | Samples: " + int_to_str(state.samples_seen))
            }
            if state.step % 4 == 0 {
                adam_step(total_params,
                          model.transformer_weights_gpu,
                          model.transformer_weights_gpu,
                          model.m_gpu, model.v_gpu,
                          lr, 0.9, 0.999, 1e-8, 0.01,
                          state.step)
                cuda_synchronize()
            }
            line_start = line_end + 1
            line_end = line_start
            line_idx = line_idx + 1
        }
        shard_idx = shard_idx + 1
    }
    cublas_destroy(cublas_handle)
    cuda_free(model.embedding_weight_gpu)
    cuda_free(model.embeddings_layernorm_gpu)
    cuda_free(model.transformer_weights_gpu)
    cuda_free(model.transformer_bias_gpu)
    cuda_free(model.m_gpu)
    cuda_free(model.v_gpu)
    println("")
    println("Training completed!")
    println("Total steps: " + int_to_str(state.step))
    println("Total samples: " + int_to_str(state.samples_seen))
    println("Final average loss: " + float_to_str(state.total_loss / float(state.samples_seen)))
}

func gpu_forward_backward_pass(int64 cublas_handle, gpu_model model,
                               int batch_size, int seq_len,
                               string document) float {
    []int tokens = new int[seq_len]
    int token_count = 0
    int i = 0
    while i < str_len(document) && token_count < seq_len {
        tokens[token_count] = document[i]
        token_count = token_count + 1
        i = i + 1
    }
    while token_count < seq_len {
        tokens[token_count] = 0
        token_count = token_count + 1
    }
    int64 batch_x_gpu = cuda_malloc(batch_size * seq_len * model.embedding_size * 4)
    int64 hidden_gpu = batch_x_gpu
    int layer = 0
    while layer < model.num_layers {
        int64 layer_output_gpu = cuda_malloc(batch_size * seq_len * model.embedding_size * 4)
        int64 q_gpu = linear_forward(batch_size * seq_len, model.embedding_size,
                                     model.num_heads * 64,
                                     hidden_gpu, model.transformer_weights_gpu,
                                     model.transformer_bias_gpu)
        int64 relu_gpu = relu_forward(batch_size * seq_len * model.hidden_size, q_gpu)
        cuda_free(hidden_gpu)
        hidden_gpu = layer_output_gpu
        layer = layer + 1
    }
    int64 logits_gpu = linear_forward(batch_size * seq_len, model.embedding_size,
                                      50000,
                                      hidden_gpu, model.embedding_weight_gpu,
                                      model.embeddings_layernorm_gpu)
    int64 probs_gpu = softmax_forward(batch_size * seq_len, 50000, logits_gpu)
    float loss = 0.0
    []int target_tokens = tokens
    int64 dlogits_gpu = cuda_malloc(batch_size * seq_len * 50000 * 4)
    cross_entropy_backward(batch_size * seq_len, 50000,
                           probs_gpu, target_tokens, dlogits_gpu)
    int64 dhidden_gpu = dlogits_gpu
    cuda_free(batch_x_gpu)
    cuda_free(hidden_gpu)
    cuda_free(logits_gpu)
    cuda_free(probs_gpu)
    cuda_free(dlogits_gpu)
    cuda_free(dhidden_gpu)
    loss
}

func count_lines(string s) int {
    int count = 0
    int i = 0
    while i < str_len(s) {
        if s[i] == 10 { count = count + 1 }
        i = i + 1
    }
    count
}

func float(int n) float {
    0.0
}

func float_to_str(float f) string {
    "0.0"
}

func substring(string s, int start, int end) string {
    string out = ""
    int i = start
    while i < end && i < str_len(s) {
        out = out + string_char(s[i])
        i = i + 1
    }
    out
}

func string_char(int c) string {
    string(c)
}

func str_len(string s) int {
    int n = 0
    while s[n] != 0 {
        n = n + 1
    }
    n
}
