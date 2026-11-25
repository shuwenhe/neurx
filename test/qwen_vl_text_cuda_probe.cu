#include "../backend/platform/cuda/qwen_vl_text_cuda.h"
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
int main(int argc, char **argv) {
  try {
    if (argc != 3)
      return 2;
    neurx::cuda::qwen_vl_text_cuda model(argv[1]);
    auto cache = model.create_cache();
    std::ofstream out(argv[2]);
    out << std::setprecision(9) << '[';
    int n = 0;
    std::vector<float> last;
    for (int id : {1, 5, 7, 9}) {
      last = model.decode(id, cache.get());
      if (n++)
        out << ',';
      out << '[';
      for (size_t j = 0; j < last.size(); ++j) {
        if (j)
          out << ',';
        out << last[j];
      }
      out << ']';
    }
    out << ']';
    auto fresh = model.create_cache();
    model.prefill({1, 5, 7}, fresh.get());
    auto next = model.decode(9, fresh.get());
    for (size_t j = 0; j < next.size(); ++j)
      if (std::abs(next[j] - last[j]) > 1e-5)
        throw std::runtime_error("cache mismatch");
    std::cout << "PASS: Qwen text prefill/decode parity\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
