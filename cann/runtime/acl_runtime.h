#pragma once
#include "acl_dynamic.h"
#include <cstddef>
#include <string>
#include <utility>
namespace neurx::cann {
struct status {
  bool ok = false;
  std::string message;
  static status success() { return {true, {}}; }
  static status failure(std::string message) { return {false, std::move(message)}; }
};
class device_session {
 public:
  device_session() = default;
  ~device_session();
  device_session(const device_session&) = delete;
  device_session& operator=(const device_session&) = delete;
  status initialize(int device_id);
  void shutdown();
  bool ready() const { return ready_; }
  int device_id() const { return device_id_; }
  context context() const { return context_; }
  stream stream() const { return stream_; }
  status synchronize() const;
 private:
  int device_id_ = -1;
  context context_ = nullptr;
  stream stream_ = nullptr;
  bool acl_initialized_ = false;
  bool ready_ = false;
};
class device_buffer {
 public:
  device_buffer() = default;
  ~device_buffer();
  device_buffer(const device_buffer&) = delete;
  device_buffer& operator=(const device_buffer&) = delete;
  device_buffer(device_buffer&& other) noexcept;
  device_buffer& operator=(device_buffer&& other) noexcept;
  status allocate(std::size_t bytes);
  void reset();
  void* data() const { return data_; }
  std::size_t size() const { return size_; }
 private:
  void* data_ = nullptr;
  std::size_t size_ = 0;
};
class host_buffer {
 public:
  host_buffer() = default;
  ~host_buffer();
  host_buffer(const host_buffer&) = delete;
  host_buffer& operator=(const host_buffer&) = delete;
  status allocate(std::size_t bytes);
  void reset();
  void* data() const { return data_; }
  std::size_t size() const { return size_; }
 private:
  void* data_ = nullptr;
  std::size_t size_ = 0;
};
}
