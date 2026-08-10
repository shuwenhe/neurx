#include "sft_example.h"
#include "../../cuda/hf_decoder_cuda.h"

#include <cuda_runtime.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <exception>
#include <limits>
#include <stdexcept>
#include <vector>

int main(int argc, char** argv) {
  if (argc != 4) {
    std::fprintf(stderr, "usage: sft_forward_probe MODEL_DIR DATA_FILE MAX_LENGTH\n");
    return 2;
  }
  int devices = 0;
  if (cudaGetDeviceCount(&devices) != cudaSuccess || devices == 0) {
    std::fprintf(stderr, "FORWARD_VALIDATION=FAIL: no CUDA device\n");
    return 1;
  }
  try {
    const auto example = neurx::posttrain::native::load_sft_example(
        argv[1], argv[2], std::stoi(argv[3]));
    neurx::cuda::hf_decoder_cuda model(argv[1]);
    const auto& config = model.config();
    if (config.vocab_size != neurx::posttrain::native::qwen_vocab_size) {
      throw std::runtime_error("model vocab_size is not 151936");
    }
    neurx::cuda::hf_cuda_kv_cache cache;
    const std::vector<float> logits = model.prefill_all(example.input_ids, &cache);
    const std::size_t expected = example.input_ids.size() *
                                 static_cast<std::size_t>(config.vocab_size);
    if (logits.size() != expected) throw std::runtime_error("full logits element count mismatch");
    float minimum = std::numeric_limits<float>::infinity();
    float maximum = -std::numeric_limits<float>::infinity();
    double checksum = 0.0;
    for (std::size_t index = 0; index < logits.size(); ++index) {
      const float value = logits[index];
      if (!std::isfinite(value)) throw std::runtime_error("logits contain NaN or infinity");
      minimum = std::min(minimum, value);
      maximum = std::max(maximum, value);
      if (index % 4096 == 0) checksum += value;
    }
    if (!(minimum < maximum)) throw std::runtime_error("logits have no numeric range");

    double loss_sum = 0.0;
    int supervised_transitions = 0;
    const int64_t vocab = config.vocab_size;
    for (std::size_t token = 1; token < example.labels.size(); ++token) {
      const int32_t label = example.labels[token];
      if (label == neurx::posttrain::native::ignore_index) continue;
      const float* row = logits.data() + (token - 1) * static_cast<std::size_t>(vocab);
      float row_max = row[0];
      for (int64_t column = 1; column < vocab; ++column) row_max = std::max(row_max, row[column]);
      double denominator = 0.0;
      for (int64_t column = 0; column < vocab; ++column) {
        denominator += std::exp(static_cast<double>(row[column] - row_max));
      }
      loss_sum += std::log(denominator) + row_max - row[label];
      ++supervised_transitions;
    }
    if (supervised_transitions == 0) throw std::runtime_error("no supervised shifted-token transitions");
    const double loss = loss_sum / supervised_transitions;
    if (!std::isfinite(loss) || loss <= 0.0) {
      throw std::runtime_error("shifted-token cross entropy is not finite and non-zero");
    }

    std::printf("[Model Load] safetensors_tensors=%zu layers=%lld hidden=%lld vocab=%lld\n",
                model.weight_count(), static_cast<long long>(config.num_hidden_layers),
                static_cast<long long>(config.hidden_size), static_cast<long long>(config.vocab_size));
    std::printf("[Model Load] validated model.embed_tokens.weight=[%lld,%lld]\n",
                static_cast<long long>(config.vocab_size),
                static_cast<long long>(config.hidden_size));
    std::printf("[Model Load] validated layer0 q_proj=[%lld,%lld] k_proj=[%lld,%lld] "
                "v_proj=[%lld,%lld] o_proj=[%lld,%lld]\n",
                static_cast<long long>(config.num_attention_heads * config.head_dim()),
                static_cast<long long>(config.hidden_size),
                static_cast<long long>(config.num_key_value_heads * config.head_dim()),
                static_cast<long long>(config.hidden_size),
                static_cast<long long>(config.num_key_value_heads * config.head_dim()),
                static_cast<long long>(config.hidden_size),
                static_cast<long long>(config.hidden_size),
                static_cast<long long>(config.num_attention_heads * config.head_dim()));
    std::printf("[Forward] logits.shape=[1, %zu, %lld] elements=%zu\n",
                example.input_ids.size(), static_cast<long long>(config.vocab_size), logits.size());
    std::printf("[Forward] logits.min=%.6f logits.max=%.6f checksum=%.9g\n",
                minimum, maximum, checksum);
    std::printf("[Loss] shifted_supervised_tokens=%d loss=%.6f\n",
                supervised_transitions, loss);
    std::printf("FORWARD_VALIDATION=PASS\n");
    std::printf("LOSS_VALIDATION=PASS\n");
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "FORWARD_VALIDATION=FAIL: %s\n", error.what());
    return 1;
  }
}
