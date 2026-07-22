#include "acl_runtime.h"

#include <utility>

namespace neurx::cann {
namespace {

Status acl_failure(const char* operation) {
  return Status::failure(std::string(operation) + ": " + recent_error());
}

}

DeviceSession::~DeviceSession() { shutdown(); }

Status DeviceSession::initialize(int device_id) {
  if (ready_) {
    return device_id == device_id_ ? Status::success()
                                   : Status::failure("CANN session is already bound to another device");
  }
  if (!available()) return Status::failure("CANN ACL runtime library is unavailable");
  if (init() != kSuccess) return acl_failure("aclInit");
  acl_initialized_ = true;
  device_id_ = device_id;
  if (set_device(device_id_) != kSuccess) {
    const Status status = acl_failure("aclrtSetDevice");
    shutdown();
    return status;
  }
  if (create_context(&context_, device_id_) != kSuccess) {
    const Status status = acl_failure("aclrtCreateContext");
    shutdown();
    return status;
  }
  if (create_stream(&stream_) != kSuccess) {
    const Status status = acl_failure("aclrtCreateStream");
    shutdown();
    return status;
  }
  ready_ = true;
  return Status::success();
}

void DeviceSession::shutdown() {
  if (stream_) {
    synchronize_stream(stream_);
    destroy_stream(stream_);
    stream_ = nullptr;
  }
  if (context_) {
    destroy_context(context_);
    context_ = nullptr;
  }
  if (device_id_ >= 0) reset_device(device_id_);
  if (acl_initialized_) {
    finalize();
    acl_initialized_ = false;
  }
  device_id_ = -1;
  ready_ = false;
}

Status DeviceSession::synchronize() const {
  if (!ready_) return Status::failure("CANN device session is not initialized");
  return synchronize_stream(stream_) == kSuccess ? Status::success()
                                                  : acl_failure("aclrtSynchronizeStream");
}

DeviceBuffer::~DeviceBuffer() { reset(); }

DeviceBuffer::DeviceBuffer(DeviceBuffer&& other) noexcept
    : data_(std::exchange(other.data_, nullptr)), size_(std::exchange(other.size_, 0)) {}

DeviceBuffer& DeviceBuffer::operator=(DeviceBuffer&& other) noexcept {
  if (this != &other) {
    reset();
    data_ = std::exchange(other.data_, nullptr);
    size_ = std::exchange(other.size_, 0);
  }
  return *this;
}

Status DeviceBuffer::allocate(std::size_t bytes) {
  reset();
  if (bytes == 0) return Status::failure("device allocation size must be positive");
  if (malloc_device(&data_, bytes) != kSuccess) return acl_failure("aclrtMalloc");
  size_ = bytes;
  return Status::success();
}

void DeviceBuffer::reset() {
  if (data_) free_device(data_);
  data_ = nullptr;
  size_ = 0;
}

HostBuffer::~HostBuffer() { reset(); }

Status HostBuffer::allocate(std::size_t bytes) {
  reset();
  if (bytes == 0) return Status::failure("host allocation size must be positive");
  if (malloc_host(&data_, bytes) != kSuccess) return acl_failure("aclrtMallocHost");
  size_ = bytes;
  return Status::success();
}

void HostBuffer::reset() {
  if (data_) free_host(data_);
  data_ = nullptr;
  size_ = 0;
}

}
