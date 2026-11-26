#pragma once
#include <nlohmann/json.hpp>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <limits>
#include <set>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

namespace neurx::runtime::model::detail {
using model_json = nlohmann::json;
struct fd_owner {
  int value = -1;
  explicit fd_owner(int fd) : value(fd) {}
  ~fd_owner() { if (value >= 0) ::close(value); }
  fd_owner(const fd_owner&) = delete;
  fd_owner& operator=(const fd_owner&) = delete;
  int release() { int v=value; value=-1; return v; }
};
inline uint64_t checked_add(uint64_t a, uint64_t b) {
  if (b > UINT64_MAX-a) throw std::runtime_error("size addition overflow");
  return a+b;
}
inline uint64_t checked_mul(uint64_t a, uint64_t b) {
  if (a && b > UINT64_MAX/a) throw std::runtime_error("size multiplication overflow");
  return a*b;
}
inline uint64_t natural(const model_json& j) {
  if (!j.is_number_integer()) throw std::runtime_error("expected integral nonnegative dimension/offset");
  if (j.is_number_unsigned()) return j.get<uint64_t>();
  auto v=j.get<int64_t>();
  if (v<0) throw std::runtime_error("negative dimension/offset");
  return uint64_t(v);
}
inline model_json strict_parse(const std::string& text) {
  std::vector<std::set<std::string>> keys;
  auto callback=[&](int, model_json::parse_event_t event, model_json& parsed) {
    using E=model_json::parse_event_t;
    if (event==E::object_start) keys.emplace_back();
    else if (event==E::key) {
      if (!keys.back().insert(parsed.get<std::string>()).second)
        throw std::runtime_error("duplicate JSON object key: "+parsed.get<std::string>());
    } else if (event==E::object_end) keys.pop_back();
    return true;
  };
  return model_json::parse(text,callback);
}
inline void pread_exact(int fd, uint64_t offset, void* buffer, size_t size) {
  auto* p=static_cast<uint8_t*>(buffer);
  while (size) {
    if (offset>uint64_t(std::numeric_limits<off_t>::max())) throw std::runtime_error("file offset overflow");
    auto n=::pread(fd,p,std::min<size_t>(size,1ULL<<30),off_t(offset));
    if (n<0 && errno==EINTR) continue;
    if (n<=0) throw std::runtime_error("truncated/unreadable checkpoint: "+std::string(n<0?std::strerror(errno):"short read"));
    p+=n;size-=size_t(n);offset+=uint64_t(n);
  }
}
inline std::string read_small_file(const std::string& path, uint64_t limit=16ULL<<20) {
  fd_owner f(::open(path.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK));
  struct stat st{};
  if (f.value<0 || ::fstat(f.value,&st) || !S_ISREG(st.st_mode) || st.st_size<0 || uint64_t(st.st_size)>limit)
    throw std::runtime_error("cannot read bounded regular file: "+path);
  std::string text(size_t(st.st_size),'\0');
  pread_exact(f.value,0,text.data(),text.size()); return text;
}
}
