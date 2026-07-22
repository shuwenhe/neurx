#pragma once

#include "../inference_runtime.h"

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>

namespace neurx::inference {

struct AdapterStatus {
  bool ok = false;
  std::string message;

  static AdapterStatus success() { return {true, {}}; }
  static AdapterStatus failure(std::string message) { return {false, std::move(message)}; }
};

struct DeviceBatch {
  Batch schedule;
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

using KernelLauncher = std::function<AdapterStatus(const DeviceBatch&)>;

class BackendAdapter {
 public:
  virtual ~BackendAdapter() = default;
  virtual Backend kind() const = 0;
  virtual const char* name() const = 0;
  virtual AdapterStatus initialize(int device_id) = 0;
  virtual bool ready() const = 0;
  virtual AdapterStatus execute(const DeviceBatch& batch) = 0;
  virtual AdapterStatus synchronize() = 0;
};

}
