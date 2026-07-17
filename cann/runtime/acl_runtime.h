#pragma once

#include "acl_dynamic.h"

#include <cstddef>
#include <string>
#include <utility>

namespace neurx::cann {

struct Status {
  bool ok = false;
  std::string message;

  static Status success() { return {true, {}}; }
  static Status failure(std::string message) { return {false, std::move(message)}; }
};

class DeviceSession {
 public:
  DeviceSession() = default;
  ~DeviceSession();
  DeviceSession(const DeviceSession&) = delete;
  DeviceSession& operator=(const DeviceSession&) = delete;

  Status initialize(int device_id);
  void shutdown();

  bool ready() const { return ready_; }
  int device_id() const { return device_id_; }
  Context context() const { return context_; }
  Stream stream() const { return stream_; }
  Status synchronize() const;

 private:
  int device_id_ = -1;
  Context context_ = nullptr;
  Stream stream_ = nullptr;
  bool acl_initialized_ = false;
  bool ready_ = false;
};

class DeviceBuffer {
 public:
  DeviceBuffer() = default;
  ~DeviceBuffer();
  DeviceBuffer(const DeviceBuffer&) = delete;
  DeviceBuffer& operator=(const DeviceBuffer&) = delete;
  DeviceBuffer(DeviceBuffer&& other) noexcept;
  DeviceBuffer& operator=(DeviceBuffer&& other) noexcept;

  Status allocate(std::size_t bytes);
  void reset();
  void* data() const { return data_; }
  std::size_t size() const { return size_; }

 private:
  void* data_ = nullptr;
  std::size_t size_ = 0;
};

class HostBuffer {
 public:
  HostBuffer() = default;
  ~HostBuffer();
  HostBuffer(const HostBuffer&) = delete;
  HostBuffer& operator=(const HostBuffer&) = delete;

  Status allocate(std::size_t bytes);
  void reset();
  void* data() const { return data_; }
  std::size_t size() const { return size_; }

 private:
  void* data_ = nullptr;
  std::size_t size_ = 0;
};

}  // namespace neurx::cann
