#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace neurx::runtime::native {

struct QuantizedWeight {
  int bits = 8;
  std::size_t rows = 0;
  std::size_t columns = 0;
  std::vector<float> scales;
  std::vector<uint8_t> packed;

  int8_t value(std::size_t row, std::size_t column) const;
};

QuantizedWeight quantize_weight_symmetric(const float* weights, std::size_t rows,
                                           std::size_t columns, int bits);
std::vector<float> weight_only_matmul(const float* input, std::size_t batch,
                                      std::size_t inner, const QuantizedWeight& weight);

}  // namespace neurx::runtime::native
