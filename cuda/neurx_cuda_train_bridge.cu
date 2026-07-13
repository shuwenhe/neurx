#include <cublas_v2.h>
#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
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

__global__ void error_loss_kernel(float *pred, const float *target, float *loss, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) {
        return;
    }
    float diff = pred[i] - target[i];
    pred[i] = diff;
    atomicAdd(loss, diff * diff);
}

__global__ void sgd_update_kernel(float *w, const float *grad, float lr, float inv_batch, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) {
        return;
    }
    w[i] -= lr * grad[i] * inv_batch;
}

void fail_cuda(cudaError_t err, const char *expr, const char *file, int line) {
    if (err == cudaSuccess) {
        return;
    }
    std::fprintf(stderr, "[cuda-train] CUDA error at %s:%d: %s -> %s\n",
                 file, line, expr, cudaGetErrorString(err));
    std::exit(2);
}

void fail_cublas(cublasStatus_t status, const char *expr, const char *file, int line) {
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

struct PairReader {
    std::vector<std::string> shards;
    size_t shard_index = 0;
    int line_in_shard = 0;
    std::ifstream current;
    std::string current_path;
    std::vector<unsigned char> pending;

    explicit PairReader(std::vector<std::string> input) : shards(std::move(input)) {}

    bool open_next() {
        if (current.is_open()) {
            current.close();
        }
        while (shard_index < shards.size()) {
            current_path = shards[shard_index];
            line_in_shard = 0;
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
            if (pending.size() >= 2) {
                *a = static_cast<int>(pending[0]);
                *b = static_cast<int>(pending[1]);
                pending.erase(pending.begin());
                return true;
            }
            if (!current.is_open() && !open_next()) {
                return false;
            }
            std::string line;
            if (std::getline(current, line)) {
                line_in_shard++;
                pending.assign(line.begin(), line.end());
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
        }
    }
};

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
    std::ofstream latest(output_dir + "/latest_checkpoint.txt");
    latest << output_dir << "/final_model.neurx\n";
}

}  // namespace

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
    float lr = env_float("NEURX_PRETRAIN_LR", 0.0002f);

    int device_count = 0;
    CUDA_OK(cudaGetDeviceCount(&device_count));
    if (device_count <= 0) {
        std::fprintf(stderr, "[cuda-train] no CUDA devices available\n");
        return 5;
    }
    if (device >= device_count) {
        std::fprintf(stderr, "[cuda-train] requested device %d but only %d CUDA device(s) exist\n",
                     device, device_count);
        return 6;
    }
    CUDA_OK(cudaSetDevice(device));

    cudaDeviceProp prop{};
    CUDA_OK(cudaGetDeviceProperties(&prop, device));
    size_t free_bytes = 0;
    size_t total_bytes = 0;
    CUDA_OK(cudaMemGetInfo(&free_bytes, &total_bytes));

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
    std::vector<float> h_x(batch_elems);
    std::vector<float> h_y(batch_elems);

    float *d_w = nullptr;
    float *d_x = nullptr;
    float *d_y = nullptr;
    float *d_err = nullptr;
    float *d_grad = nullptr;
    float *d_loss = nullptr;

    CUDA_OK(cudaMalloc(&d_w, matrix_elems * sizeof(float)));
    CUDA_OK(cudaMalloc(&d_x, batch_elems * sizeof(float)));
    CUDA_OK(cudaMalloc(&d_y, batch_elems * sizeof(float)));
    CUDA_OK(cudaMalloc(&d_err, batch_elems * sizeof(float)));
    CUDA_OK(cudaMalloc(&d_grad, matrix_elems * sizeof(float)));
    CUDA_OK(cudaMalloc(&d_loss, sizeof(float)));
    CUDA_OK(cudaMemcpy(d_w, h_w.data(), matrix_elems * sizeof(float), cudaMemcpyHostToDevice));

    cublasHandle_t handle = nullptr;
    CUBLAS_OK(cublasCreate(&handle));

    PairReader reader(std::move(shards));
    long long pairs_seen = 0;
    float final_loss = 0.0f;
    auto start = std::chrono::steady_clock::now();

    const float one = 1.0f;
    const float zero = 0.0f;
    int update_blocks = static_cast<int>((matrix_elems + 255) / 256);
    int loss_blocks = static_cast<int>((batch_elems + 255) / 256);

    for (int step = 1; step <= steps; ++step) {
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

        CUDA_OK(cudaMemcpy(d_x, h_x.data(), batch_elems * sizeof(float), cudaMemcpyHostToDevice));
        CUDA_OK(cudaMemcpy(d_y, h_y.data(), batch_elems * sizeof(float), cudaMemcpyHostToDevice));

        CUBLAS_OK(cublasSgemm(handle,
                              CUBLAS_OP_N, CUBLAS_OP_N,
                              vocab_size, batch_pairs, vocab_size,
                              &one,
                              d_w, vocab_size,
                              d_x, vocab_size,
                              &zero,
                              d_err, vocab_size));

        CUDA_OK(cudaMemset(d_loss, 0, sizeof(float)));
        error_loss_kernel<<<loss_blocks, 256>>>(d_err, d_y, d_loss, static_cast<int>(batch_elems));
        CUDA_OK(cudaGetLastError());

        CUBLAS_OK(cublasSgemm(handle,
                              CUBLAS_OP_N, CUBLAS_OP_T,
                              vocab_size, vocab_size, batch_pairs,
                              &one,
                              d_err, vocab_size,
                              d_x, vocab_size,
                              &zero,
                              d_grad, vocab_size));

        float inv_batch = 1.0f / static_cast<float>(std::max(1, actual_pairs));
        sgd_update_kernel<<<update_blocks, 256>>>(d_w, d_grad, lr, inv_batch, static_cast<int>(matrix_elems));
        CUDA_OK(cudaGetLastError());

        CUDA_OK(cudaMemcpy(&final_loss, d_loss, sizeof(float), cudaMemcpyDeviceToHost));
        final_loss = final_loss / static_cast<float>(std::max(1, actual_pairs));
        pairs_seen += actual_pairs;

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
    }

    CUDA_OK(cudaDeviceSynchronize());

    std::filesystem::create_directories(output_dir);
    std::string weights_path = output_dir + "/weights.f32";
    CUDA_OK(cudaMemcpy(h_w.data(), d_w, matrix_elems * sizeof(float), cudaMemcpyDeviceToHost));
    std::ofstream weights(weights_path, std::ios::binary);
    weights.write(reinterpret_cast<const char *>(h_w.data()), static_cast<std::streamsize>(matrix_elems * sizeof(float)));
    weights.close();
    write_checkpoint(output_dir, weights_path, steps, pairs_seen, vocab_size, batch_pairs, final_loss);

    CUBLAS_OK(cublasDestroy(handle));
    CUDA_OK(cudaFree(d_loss));
    CUDA_OK(cudaFree(d_grad));
    CUDA_OK(cudaFree(d_err));
    CUDA_OK(cudaFree(d_y));
    CUDA_OK(cudaFree(d_x));
    CUDA_OK(cudaFree(d_w));

    std::printf("[cuda-train] complete steps=%d pairs=%lld loss=%.6f\n", steps, pairs_seen, final_loss);
    std::printf("[cuda-train] checkpoint=%s/final_model.neurx\n", output_dir.c_str());
    std::printf("[cuda-train] weights=%s\n", weights_path.c_str());
    std::fflush(stdout);
    return 0;
}
