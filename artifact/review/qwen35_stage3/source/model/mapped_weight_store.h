#pragma once
#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace neurx::runtime::model {
struct MappedRegion;
struct TensorDescriptor {
  std::string name, dtype, shard;
  std::vector<uint64_t> shape;
  uint64_t offset=0, size=0; // offset is absolute within shard; contiguous row-major
};
struct StoreLimits {
  uint64_t max_header_bytes=64ULL<<20;
  uint64_t max_metadata_bytes=128ULL<<20;
  uint64_t max_shards=4096;
  uint64_t max_tensors=1000000;
};
class TensorSlice {
 public:
  TensorSlice() = default;
  uint64_t size() const { return size_; }
  const std::vector<uint64_t>& shape() const { return shape_; }
  const std::string& dtype() const { return dtype_; }
  // Read-only mapped pointer; checkpoint files must remain immutable while leased.
  const uint8_t* data() const;
  // Bounded pread, detects short/truncated reads without dereferencing mmap pages.
  void copy(uint64_t offset, void* target, uint64_t bytes) const;
 private:
  std::shared_ptr<const MappedRegion> owner_;
  uint64_t offset_=0, size_=0;
  std::vector<uint64_t> shape_;
  std::string dtype_;
  friend class MappedWeightStore;
};
class MappedWeightStore {
 public:
  static MappedWeightStore open(const std::string& directory, StoreLimits limits={});
  const std::map<std::string,TensorDescriptor>& tensors() const { return tensors_; }
  const TensorDescriptor& view(const std::string& name) const;
  TensorSlice tensor(const std::string& name) const;
  TensorSlice expert(const std::string& name, uint64_t expert_id) const;
  TensorSlice rows(const std::string& name, uint64_t first, uint64_t count) const;
  uint64_t payload_bytes() const { return payload_bytes_; }
  uint64_t mapped_bytes() const { return mapped_bytes_; }
  const std::string& metadata_identity() const { return metadata_identity_; }
 private:
  std::map<std::string,TensorDescriptor> tensors_;
  std::map<std::string,std::shared_ptr<const MappedRegion>> maps_;
  uint64_t payload_bytes_=0, mapped_bytes_=0;
  std::string metadata_identity_;
};
}
