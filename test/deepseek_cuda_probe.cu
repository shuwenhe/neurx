#include "../backend/platform/cuda/deepseek_v2_cuda.h"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
int main(int argc, char **argv) {
  try {
    if (argc != 3)
      return 2;
    neurx::cuda::deepseek_v2_cuda model(argv[1], 0);
    auto cache = model.create_cache();
    std::ofstream out(argv[2]);
    out << std::setprecision(9) << '[';
    int n = 0;
    for (int id : {1, 5, 7, 9}) {
      auto logits = model.decode(id, cache.get());
      if (n++)
        out << ',';
      out << '[';
      for (size_t j = 0; j < logits.size(); ++j) {
        if (j)
          out << ',';
        out << logits[j];
      }
      out << ']';
    }
    out << ']';
    auto fresh = model.create_cache();
    auto pref = model.prefill({1, 5, 7}, fresh.get());
    auto incremental = model.decode(9, fresh.get());
    auto separate = model.create_cache();
    std::vector<float> expected;
    for (int id : {1, 5, 7, 9})
      expected = model.decode(id, separate.get());
    for (size_t j = 0; j < expected.size(); ++j)
      if (std::abs(expected[j] - incremental[j]) > 1e-5)
        throw std::runtime_error("prefill/decode mismatch");
    if (fresh->length() != 4)
      throw std::runtime_error("cache length mismatch");
    bool failed = false;
    try {
      model.decode(-1, fresh.get());
    } catch (const std::exception &) {
      failed = true;
    }
    if (!failed || fresh->length() != 4)
      throw std::runtime_error("invalid token changed cache");
    auto boundary = model.create_cache();
    std::vector<int32_t> too_many(model.context_limit() + 1, 1);
    failed = false;
    try {
      model.prefill(too_many, boundary.get());
    } catch (const std::exception &) {
      failed = true;
    }
    if (!failed || boundary->length() != 0)
      throw std::runtime_error("oversized prefill changed cache");
    std::cout << "PASS: cache reset, prefill/decode parity, invalid token, "
                 "context boundary\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
