#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <algorithm>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <random>
#include <sstream>
#include <string>
#include <vector>
namespace {
volatile std::sig_atomic_t stop_requested = 0;
void request_stop(int) {
    stop_requested = 1;
}
__global__ void error_loss_kernel(float *pred, const float *target, float *loss, int n) {
    int i = block_idx.x * block_dim.x + thread_idx.x;
    if (i >= n) {
        return;
    }
    float diff = pred[i] - target[i];
    pred[i] = diff;
    atomic_add(loss, diff * diff);
}
__global__ void sgd_update_kernel(float *w, const float *grad, float lr, float inv_batch, int n) {
    int i = block_idx.x * block_dim.x + thread_idx.x;
    if (i >= n) {
        return;
    }
    w[i] -= lr * grad[i] * inv_batch;
}
void fail_cuda(cuda_error_t err, const char *expr, const char *file, int line) {
    if (err == cuda_success) {
        return;
    }
    std::fprintf(stderr, "[cuda-train] CUDA error at %s:%d: %s -> %s\n",
                 file, line, expr, cuda_get_error_string(err));
    std::exit(2);
}
void fail_cublas(cublas_status_t status, const char *expr, const char *file, int line) {
    if (status == CUBLAS_STATUS_SUCCESS) {
        return;
    }
    std::fprintf(stderr, "[cuda-train] cuBLAS error at %s:%d: %s -> status=%d\n",
                 file, line, expr, static_cast<int>(status));
    std::exit(3);
}
#define CUDA_OK(expr) fail_cuda((expr), #expr, __FILE__, __LINE__)
#define CUBLAS_OK(expr) fail_cublas((expr), #expr, __FILE__, __LINE__)
std::string env_str(const char *name, const std::string &fallback) {
    const char *value = std::getenv(name);
    if (value == nullptr || value[0] == '\0') {
        return fallback;
    }
    return value;
}
int env_int(const char *name, int fallback) {
    const char *value = std::getenv(name);
    if (value == nullptr || value[0] == '\0') {
        return fallback;
    }
    char *end = nullptr;
    long parsed = std::strtol(value, &end, 10);
    if (end == value) {
        return fallback;
    }
    return static_cast<int>(parsed);
}
float env_float(const char *name, float fallback) {
    const char *value = std::getenv(name);
    if (value == nullptr || value[0] == '\0') {
        return fallback;
    }
    char *end = nullptr;
    float parsed = std::strtof(value, &end);
    if (end == value) {
        return fallback;
    }
    return parsed;
}
std::vector<std::string> read_shard_list(const std::string &path) {
    std::ifstream in(path);
    if (!in) {
        std::fprintf(stderr, "[cuda-train] failed to open shard list: %s\n", path.c_str());
        std::exit(4);
    }
    std::vector<std::string> shards;
    std::string line;
    while (std::getline(in, line)) {
        if (!line.empty()) {
            shards.push_back(line);
        }
    }
    return shards;
}
std::string basename(const std::string &path) {
    size_t slash = path.find_last_of("/\\");
    if (slash == std::string::npos) {
        return path;
    }
    return path.substr(slash + 1);
}
struct pair_reader {
    std::vector<std::string> shards;
    size_t shard_index = 0;
    int line_in_shard = 0;
    std::ifstream current;
    std::string current_path;
    std::vector<unsigned char> pending;
    size_t pending_offset = 0;
    explicit pair_reader(std::vector<std::string> input) : shards(std::move(input)) {}
    bool open_next() {
        if (current.is_open()) {
            current.close();
        }
        while (shard_index < shards.size()) {
            current_path = shards[shard_index];
            line_in_shard = 0;
            pending_offset = 0;
            current.open(current_path);
            if (current) {
                std::printf("[cuda-train] shard-start %zu/%zu file=%s\n",
                            shard_index + 1, shards.size(), basename(current_path).c_str());
                std::fflush(stdout);
                return true;
            }
            std::printf("[cuda-train] shard-skip %zu/%zu file=%s reason=open-failed\n",
                        shard_index + 1, shards.size(), basename(current_path).c_str());
            shard_index++;
        }
        return false;
    }
    bool next_pair(int *a, int *b) {
        while (true) {
            if (pending.size() >= pending_offset + 2) {
                *a = static_cast<int>(pending[pending_offset]);
                *b = static_cast<int>(pending[pending_offset + 1]);
                pending_offset++;
                return true;
            }
            if (!current.is_open() && !open_next()) {
                return false;
            }
            std::string line;
            if (std::getline(current, line)) {
                line_in_shard++;
                pending.assign(line.begin(), line.end());
                pending_offset = 0;
                if (pending.size() < 2) {
                    pending.clear();
                }
                continue;
            }
            std::printf("[cuda-train] shard-complete %zu/%zu file=%s lines=%d\n",
                        shard_index + 1, shards.size(), basename(current_path).c_str(), line_in_shard);
            std::fflush(stdout);
            current.close();
            shard_index++;
            pending.clear();
            pending_offset = 0;
        }
    }
    bool restore(size_t saved_shard, int saved_line, size_t saved_offset) {
        if (saved_shard >= shards.size()) {
            shard_index = shards.size();
            return saved_shard == shards.size();
        }
        shard_index = saved_shard;
        if (!open_next()) {
            return false;
        }
        std::string line;
        pending.clear();
        for (int i = 0; i < saved_line; ++i) {
            if (!std::getline(current, line)) {
                return false;
            }
            line_in_shard++;
        }
        if (saved_line > 0) {
            pending.assign(line.begin(), line.end());
        }
        if (saved_offset > pending.size()) {
            return false;
        }
        pending_offset = saved_offset;
        return true;
    }
};
struct resume_state {
    int completed_step = 0;
    long long pairs_seen = 0;
    size_t shard_index = 0;
    int line_in_shard = 0;
    size_t pending_offset = 0;
    int vocab_size = 0;
    int batch_pairs = 0;
    float loss = 0.0f;
    std::string weights_path;
};
bool atomic_replace(const std::string &temporary, const std::string &destination) {
    std::error_code ec;
    std::filesystem::rename(temporary, destination, ec);
    if (!ec) {
        return true;
    }
    std::fprintf(stderr, "[cuda-train] checkpoint rename failed: %s -> %s: %s\n",
                 temporary.c_str(), destination.c_str(), ec.message().c_str());
    return false;
}
bool load_resume_state(const std::string &path, resume_state *state) {
    std::ifstream in(path);
    if (!in) {
        return false;
    }
    std::string line;
    while (std::getline(in, line)) {
        size_t equals = line.find('=');
        if (equals == std::string::npos) {
            continue;
        }
        std::string key = line.substr(0, equals);
        std::string value = line.substr(equals + 1);
        try {
            if (key == "completed_step") state->completed_step = std::stoi(value);
            else if (key == "pairs_seen") state->pairs_seen = std::stoll(value);
            else if (key == "shard_index") state->shard_index = static_cast<size_t>(std::stoull(value));
            else if (key == "line_in_shard") state->line_in_shard = std::stoi(value);
            else if (key == "pending_offset") state->pending_offset = static_cast<size_t>(std::stoull(value));
            else if (key == "vocab_size") state->vocab_size = std::stoi(value);
            else if (key == "batch_pairs") state->batch_pairs = std::stoi(value);
            else if (key == "loss") state->loss = std::stof(value);
            else if (key == "weights") state->weights_path = value;
        } catch (const std::exception &) {
            return false;
        }
    }
    return state->completed_step >= 0 && !state->weights_path.empty();
}
bool save_training_checkpoint(const std::string &output_dir,
                              float *device_weights,
                              std::vector<float> *host_weights,
                              int completed_step,
                              long long pairs_seen,
                              int vocab_size,
                              int batch_pairs,
                              float loss,
                              const pair_reader &reader) {
    std::filesystem::create_directories(output_dir);
    std::string state_path = output_dir + "/checkpoint.state";
    resume_state previous;
    bool had_previous = load_resume_state(state_path, &previous);
    std::string weights_path = output_dir + "/checkpoint_step_" +
                               std::to_string(completed_step) + ".weights.f32";
    std::string weights_tmp = weights_path + ".tmp";
    std::string state_tmp = state_path + ".tmp";
    CUDA_OK(cuda_memcpy(host_weights->data(), device_weights,
                       host_weights->size() * sizeof(float), cuda_memcpy_device_to_host));
    {
        std::ofstream weights(weights_tmp, std::ios::binary | std::ios::trunc);
        weights.write(reinterpret_cast<const char *>(host_weights->data()),
                      static_cast<std::streamsize>(host_weights->size() * sizeof(float)));
        weights.flush();
        if (!weights) {
            std::fprintf(stderr, "[cuda-train] failed to write checkpoint weights: %s\n", weights_tmp.c_str());
            return false;
        }
    }
    if (!atomic_replace(weights_tmp, weights_path)) {
        return false;
    }
    {
        std::ofstream state(state_tmp, std::ios::trunc);
        state << "version=1\n";
        state << "completed_step=" << completed_step << "\n";
        state << "pairs_seen=" << pairs_seen << "\n";
        state << "shard_index=" << reader.shard_index << "\n";
        state << "line_in_shard=" << reader.line_in_shard << "\n";
        state << "pending_offset=" << reader.pending_offset << "\n";
        state << "vocab_size=" << vocab_size << "\n";
        state << "batch_pairs=" << batch_pairs << "\n";
        state << "loss=" << loss << "\n";
        state << "weights=" << weights_path << "\n";
        state.flush();
        if (!state) {
            std::fprintf(stderr, "[cuda-train] failed to write checkpoint state: %s\n", state_tmp.c_str());
            return false;
        }
    }
    if (!atomic_replace(state_tmp, state_path)) {
        return false;
    }
    if (had_previous && previous.weights_path != weights_path) {
        std::error_code remove_error;
        std::filesystem::remove(previous.weights_path, remove_error);
    }
    std::string latest_tmp = output_dir + "/latest_checkpoint.txt.tmp";
    {
        std::ofstream latest(latest_tmp, std::ios::trunc);
        latest << state_path << "\n";
    }
    if (!atomic_replace(latest_tmp, output_dir + "/latest_checkpoint.txt")) {
        return false;
    }
    std::printf("[cuda-train] checkpoint-saved step=%d path=%s\n", completed_step, state_path.c_str());
    std::fflush(stdout);
    return true;
}
void write_checkpoint(const std::string &output_dir,
                      const std::string &weights_path,
                      int steps,
                      long long pairs_seen,
                      int vocab_size,
                      int batch_pairs,
                      float loss) {
    std::filesystem::create_directories(output_dir);
    std::ofstream ckpt(output_dir + "/final_model.neurx");
    ckpt << "{\n";
    ckpt << "  \"model_name\": \"NeurX-1.3\",\n";
    ckpt << "  \"backend\": \"cuda-runtime-cublas\",\n";
    ckpt << "  \"architecture\": \"byte_bigram_linear\",\n";
    ckpt << "  \"vocab_size\": " << vocab_size << ",\n";
    ckpt << "  \"batch_pairs\": " << batch_pairs << ",\n";
    ckpt << "  \"steps\": " << steps << ",\n";
    ckpt << "  \"tokens_seen\": " << pairs_seen << ",\n";
    ckpt << "  \"loss\": " << loss << ",\n";
    ckpt << "  \"weights_format\": \"f32_column_major_vocab_x_vocab\",\n";
    ckpt << "  \"weights\": \"" << weights_path << "\"\n";
    ckpt << "}\n";
}
}
int main() {
    std::string project_root = env_str("NEURX_ROOT", ".");
    std::string shard_list_file = env_str(
        "NEURX_PRETRAIN_SHARD_LIST_FILE",
        project_root + "/artifacts/build/run_large_pretrain/shard_list.txt");
    std::string output_dir = env_str(
        "NEURX_PRETRAIN_OUTPUT_DIR",
        project_root + "/checkpoint/NeurX-1.3");
    int device = env_int("NEURX_CUDA_DEVICE", 0);
    int steps = std::max(1, env_int("NEURX_PRETRAIN_STEPS", 64));
    int micro_batch = std::max(1, env_int("NEURX_PRETRAIN_MICRO_BATCH", 32));
    int seq_len = std::max(1, env_int("NEURX_PRETRAIN_SEQ_LEN", 512));
    int requested_batch = micro_batch * seq_len;
    int batch_pairs = std::max(1, env_int("NEURX_CUDA_BATCH_PAIRS", std::min(requested_batch, 256)));
    int vocab_size = std::max(16, env_int("NEURX_CUDA_VOCAB_SIZE", 4096));
    int log_interval = std::max(1, env_int("NEURX_PRETRAIN_LOG_INTERVAL", 1));
    int save_interval = std::max(1, env_int("NEURX_PRETRAIN_SAVE_INTERVAL", 10000));
    bool resume = env_int("NEURX_PRETRAIN_RESUME", 1) != 0;
    float lr = env_float("NEURX_PRETRAIN_LR", 0.0002f);
    int device_count = 0;
    CUDA_OK(cuda_get_device_count(&device_count));
    if (device_count <= 0) {
        std::fprintf(stderr, "[cuda-train] no CUDA devices available\n");
        return 5;
    }
    if (device >= device_count) {
        std::fprintf(stderr, "[cuda-train] requested device %d but only %d CUDA device(s) exist\n",
                     device, device_count);
        return 6;
    }
    CUDA_OK(cuda_set_device(device));
    cuda_device_prop prop{};
    CUDA_OK(cuda_get_device_properties(&prop, device));
    size_t free_bytes = 0;
    size_t total_bytes = 0;
    CUDA_OK(cuda_mem_get_info(&free_bytes, &total_bytes));
    std::vector<std::string> shards = read_shard_list(shard_list_file);
    if (shards.empty()) {
        std::fprintf(stderr, "[cuda-train] shard list is empty: %s\n", shard_list_file.c_str());
        return 7;
    }
    std::printf("[cuda-train] backend=cuda-runtime-cublas device=%d name=%s\n", device, prop.name);
    std::printf("[cuda-train] memory free=%zu total=%zu\n", free_bytes, total_bytes);
    std::printf("[cuda-train] shards=%zu first=%s last=%s\n",
                shards.size(), shards.front().c_str(), shards.back().c_str());
    std::printf("[cuda-train] model=byte_bigram_linear vocab=%d batch_pairs=%d steps=%d lr=%g\n",
                vocab_size, batch_pairs, steps, lr);
    std::fflush(stdout);
    size_t matrix_elems = static_cast<size_t>(vocab_size) * static_cast<size_t>(vocab_size);
    size_t batch_elems = static_cast<size_t>(vocab_size) * static_cast<size_t>(batch_pairs);
    std::vector<float> h_w(matrix_elems);
    std::mt19937 rng(17);
    std::uniform_real_distribution<float> dist(-0.001f, 0.001f);
    for (float &v : h_w) {
        v = dist(rng);
    }
    resume_state resume_state;
    std::string resume_path = env_str("NEURX_PRETRAIN_RESUME_FROM", output_dir + "/checkpoint.state");
    int start_step = 1;
    long long pairs_seen = 0;
    float final_loss = 0.0f;
    bool resumed = false;
    if (resume && std::filesystem::exists(resume_path)) {
        if (!load_resume_state(resume_path, &resume_state)) {
            std::fprintf(stderr, "[cuda-train] invalid checkpoint state: %s\n", resume_path.c_str());
            return 8;
        }
        if (resume_state.vocab_size != vocab_size || resume_state.batch_pairs != batch_pairs) {
            std::fprintf(stderr,
                         "[cuda-train] checkpoint configuration mismatch: vocab=%d/%d batch_pairs=%d/%d\n",
                         resume_state.vocab_size, vocab_size, resume_state.batch_pairs, batch_pairs);
            return 9;
        }
        std::ifstream weights(resume_state.weights_path, std::ios::binary);
        weights.read(reinterpret_cast<char *>(h_w.data()),
                     static_cast<std::streamsize>(h_w.size() * sizeof(float)));
        if (!weights || weights.peek() != std::ifstream::traits_type::eof()) {
            std::fprintf(stderr, "[cuda-train] invalid checkpoint weights: %s\n",
                         resume_state.weights_path.c_str());
            return 10;
        }
        start_step = resume_state.completed_step + 1;
        pairs_seen = resume_state.pairs_seen;
        final_loss = resume_state.loss;
        resumed = true;
    }
    std::vector<float> h_x(batch_elems);
    std::vector<float> h_y(batch_elems);
    float *d_w = nullptr;
    float *d_x = nullptr;
    float *d_y = nullptr;
    float *d_err = nullptr;
    float *d_grad = nullptr;
    float *d_loss = nullptr;
    CUDA_OK(cuda_malloc(&d_w, matrix_elems * sizeof(float)));
    CUDA_OK(cuda_malloc(&d_x, batch_elems * sizeof(float)));
    CUDA_OK(cuda_malloc(&d_y, batch_elems * sizeof(float)));
    CUDA_OK(cuda_malloc(&d_err, batch_elems * sizeof(float)));
    CUDA_OK(cuda_malloc(&d_grad, matrix_elems * sizeof(float)));
    CUDA_OK(cuda_malloc(&d_loss, sizeof(float)));
    CUDA_OK(cuda_memcpy(d_w, h_w.data(), matrix_elems * sizeof(float), cuda_memcpy_host_to_device));
    cublas_handle_t handle = nullptr;
    CUBLAS_OK(cublas_create(&handle));
    pair_reader reader(std::move(shards));
    if (resumed && !reader.restore(resume_state.shard_index,
                                   resume_state.line_in_shard,
                                   resume_state.pending_offset)) {
        std::fprintf(stderr, "[cuda-train] failed to restore dataset cursor\n");
        return 11;
    }
    if (resumed) {
        std::printf("[cuda-train] checkpoint-restored step=%d next_step=%d pairs=%lld path=%s\n",
                    resume_state.completed_step, start_step, pairs_seen, resume_path.c_str());
        std::fflush(stdout);
    }
    std::signal(SIGINT, request_stop);
    std::signal(SIGTERM, request_stop);
    auto start = std::chrono::steady_clock::now();
    const float one = 1.0f;
    const float zero = 0.0f;
    int update_blocks = static_cast<int>((matrix_elems + 255) / 256);
    int loss_blocks = static_cast<int>((batch_elems + 255) / 256);
    int completed_step = start_step - 1;
    for (int step = start_step; step <= steps; ++step) {
        std::fill(h_x.begin(), h_x.end(), 0.0f);
        std::fill(h_y.begin(), h_y.end(), 0.0f);
        int actual_pairs = 0;
        for (int b = 0; b < batch_pairs; ++b) {
            int prev = 0;
            int next = 0;
            if (!reader.next_pair(&prev, &next)) {
                break;
            }
            prev %= vocab_size;
            next %= vocab_size;
            h_x[static_cast<size_t>(prev) + static_cast<size_t>(b) * vocab_size] = 1.0f;
            h_y[static_cast<size_t>(next) + static_cast<size_t>(b) * vocab_size] = 1.0f;
            actual_pairs++;
        }
        if (actual_pairs == 0) {
            std::printf("[cuda-train] dataset exhausted at step=%d\n", step);
            steps = step - 1;
            break;
        }
        CUDA_OK(cuda_memcpy(d_x, h_x.data(), batch_elems * sizeof(float), cuda_memcpy_host_to_device));
        CUDA_OK(cuda_memcpy(d_y, h_y.data(), batch_elems * sizeof(float), cuda_memcpy_host_to_device));
        CUBLAS_OK(cublas_sgemm(handle,
                              CUBLAS_OP_N, CUBLAS_OP_N,
                              vocab_size, batch_pairs, vocab_size,
                              &one,
                              d_w, vocab_size,
                              d_x, vocab_size,
                              &zero,
                              d_err, vocab_size));
        CUDA_OK(cuda_memset(d_loss, 0, sizeof(float)));
        error_loss_kernel<<<loss_blocks, 256>>>(d_err, d_y, d_loss, static_cast<int>(batch_elems));
        CUDA_OK(cuda_get_last_error());
        CUBLAS_OK(cublas_sgemm(handle,
                              CUBLAS_OP_N, CUBLAS_OP_T,
                              vocab_size, vocab_size, batch_pairs,
                              &one,
                              d_err, vocab_size,
                              d_x, vocab_size,
                              &zero,
                              d_grad, vocab_size));
        float inv_batch = 1.0f / static_cast<float>(std::max(1, actual_pairs));
        sgd_update_kernel<<<update_blocks, 256>>>(d_w, d_grad, lr, inv_batch, static_cast<int>(matrix_elems));
        CUDA_OK(cuda_get_last_error());
        CUDA_OK(cuda_memcpy(&final_loss, d_loss, sizeof(float), cuda_memcpy_device_to_host));
        final_loss = final_loss / static_cast<float>(std::max(1, actual_pairs));
        pairs_seen += actual_pairs;
        completed_step = step;
        if (step == 1 || step % log_interval == 0 || step == steps) {
            auto now = std::chrono::steady_clock::now();
            double seconds = std::chrono::duration<double>(now - start).count();
            double pairs_per_sec = seconds > 0.0 ? static_cast<double>(pairs_seen) / seconds : 0.0;
            std::printf("[cuda-train] step=%d/%d pairs=%d total_pairs=%lld loss=%.6f pairs_per_sec=%.2f shard=%zu/%zu line=%d\n",
                        step, steps, actual_pairs, pairs_seen, final_loss, pairs_per_sec,
                        std::min(reader.shard_index + 1, reader.shards.size()), reader.shards.size(),
                        reader.line_in_shard);
            std::fflush(stdout);
        }
        if (step % save_interval == 0 || stop_requested) {
            if (!save_training_checkpoint(output_dir, d_w, &h_w, step, pairs_seen,
                                          vocab_size, batch_pairs, final_loss, reader)) {
                return 12;
            }
        }
        if (stop_requested) {
            std::printf("[cuda-train] stop requested; exiting after checkpoint at step=%d\n", step);
            std::fflush(stdout);
            break;
        }
    }
    CUDA_OK(cuda_device_synchronize());
    if (!save_training_checkpoint(output_dir, d_w, &h_w, completed_step, pairs_seen,
                                  vocab_size, batch_pairs, final_loss, reader)) {
        return 12;
    }
    std::filesystem::create_directories(output_dir);
    std::string weights_path = output_dir + "/weights.f32";
    CUDA_OK(cuda_memcpy(h_w.data(), d_w, matrix_elems * sizeof(float), cuda_memcpy_device_to_host));
    std::ofstream weights(weights_path, std::ios::binary);
    weights.write(reinterpret_cast<const char *>(h_w.data()), static_cast<std::streamsize>(matrix_elems * sizeof(float)));
    weights.close();
    write_checkpoint(output_dir, weights_path, completed_step, pairs_seen, vocab_size, batch_pairs, final_loss);
    CUBLAS_OK(cublas_destroy(handle));
    CUDA_OK(cuda_free(d_loss));
    CUDA_OK(cuda_free(d_grad));
    CUDA_OK(cuda_free(d_err));
    CUDA_OK(cuda_free(d_y));
    CUDA_OK(cuda_free(d_x));
    CUDA_OK(cuda_free(d_w));
    std::printf("[cuda-train] complete steps=%d pairs=%lld loss=%.6f\n", completed_step, pairs_seen, final_loss);
    std::printf("[cuda-train] checkpoint=%s/final_model.neurx\n", output_dir.c_str());
    std::printf("[cuda-train] weights=%s\n", weights_path.c_str());
    std::fflush(stdout);
    return 0;
}
