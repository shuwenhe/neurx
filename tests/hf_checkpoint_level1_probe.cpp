#include "../runtime/model/hf_model.h"

#include <cmath>
#include <cstdio>
#include <exception>
#include <vector>

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  try {
    const auto config = neurx::runtime::model::hf_config::from_file(
        std::string(argv[1]) + "/config.json");
    const auto store = neurx::runtime::model::hf_weight_store::open(argv[1]);
    store.validate_architecture(config);
    const auto norm = store.load("model.norm.weight").to(
        neurx::runtime::native::d_type::float32);
    std::vector<float> values(static_cast<std::size_t>(norm.numel()));
    norm.copy_to_host(values.data(), values.size() * sizeof(float));
    double sum = 0.0;
    for (float value : values) {
      if (!std::isfinite(value)) return 1;
      sum += value;
    }
    std::printf("checkpoint tensors=%zu layers=%lld vocab=%lld norm_sum=%.9g\n",
                store.size(), static_cast<long long>(config.num_hidden_layers),
                static_cast<long long>(config.vocab_size), sum);
    return store.size() == 290 && values.size() == 896 && sum != 0.0 ? 0 : 1;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "%s\n", error.what());
    return 1;
  }
}
