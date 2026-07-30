#pragma once

#include "../native/tensor_runtime.h"

#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace neurx::runtime::model {

struct SafeTensorInfo {
  native::DType dtype = native::DType::float32;
  std::vector<int64_t> shape;
  uint64_t begin = 0;
  uint64_t end = 0;
};

class SafeTensorFile {
 public:
  static SafeTensorFile open(const std::string& path);

  const std::string& path() const { return path_; }
  const std::map<std::string, SafeTensorInfo>& tensors() const { return tensors_; }
  const std::map<std::string, std::string>& metadata() const { return metadata_; }
  bool contains(const std::string& name) const;
  native::Tensor load(const std::string& name,
                      native::Device device = {native::DeviceType::cpu, 0}) const;

 private:
  std::string path_;
  std::vector<uint8_t> bytes_;
  uint64_t data_start_ = 0;
  std::map<std::string, SafeTensorInfo> tensors_;
  std::map<std::string, std::string> metadata_;
};

}
