#pragma once
#include "../native/tensor_runtime.h"
#include <cstdint>
#include <map>
#include <string>
#include <vector>
namespace neurx::runtime::model {
struct safe_tensor_info {
  native::d_type dtype = native::d_type::float32;
  std::vector<int64_t> shape;
  uint64_t begin = 0;
  uint64_t end = 0;
};
class safe_tensor_file {
 public:
  static safe_tensor_file open(const std::string& path);
  const std::string& path() const { return path_; }
  const std::map<std::string, safe_tensor_info>& tensors() const { return tensors_; }
  const std::map<std::string, std::string>& metadata() const { return metadata_; }
  bool contains(const std::string& name) const;
  native::tensor load(const std::string& name,
                      native::device device = {native::device_type::cpu, 0}) const;
 private:
  std::string path_;
  std::vector<uint8_t> bytes_;
  uint64_t data_start_ = 0;
  std::map<std::string, safe_tensor_info> tensors_;
  std::map<std::string, std::string> metadata_;
};
}
