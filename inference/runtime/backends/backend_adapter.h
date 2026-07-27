#pragma once

#include "../inference_runtime.h"

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>

namespace neurx::inference {

struct adapter_status {
  bool ok = false;
  std::string message;

  static adapter_status success() { return {true, {}}; }
  static adapter_status failure(std::string message) { return {false, std::move(message)}; }
};

struct device_batch {
  batch_2 schedule;
  const void* token_ids = nullptr;
  const void* kv_block_table = nullptr;
  void* logits = nullptr;
  void* stream = nullptr;
  const int32_t* sequence_lengths = nullptr;
  const int32_t* slot_mapping = nullptr;
  std::size_t batch_size = 0;
  std::size_t token_count = 0;
  std::size_t block_table_stride = 0;
  const void* model = nullptr;
  void* kv_cache = nullptr;
  void* workspace = nullptr;
  std::size_t workspace_bytes = 0;

  const void* sampling_params = nullptr;
  void* sampled_token_ids = nullptr;
  bool device_sampling = false;
};

using KernelLauncher = std::function<adapter_status(const device_batch&)>;

class BackendAdapter {
 public:
  virtual ~BackendAdapter() = default;
  virtual Backend kind() const = 0;
  virtual const char* name() const = 0;
  virtual adapter_status initialize(int device_id) = 0;
  virtual bool ready() const = 0;
  virtual adapter_status execute(const device_batch& batch) = 0;
  virtual adapter_status synchronize() = 0;
};

}
