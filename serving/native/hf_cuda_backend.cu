#include "../../cuda/hf_decoder_cuda.h"
#include "../../runtime/model/json.h"
#include "serving_socket.h"
#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>
namespace {
using neurx::runtime::model::json;
volatile std::sig_atomic_t running = 1;
void stop(int) { running = 0; }
std::string environment(const char* name, const char* fallback) {
  const char* value = std::getenv(name);
  return value && *value ? value : fallback;
}
int environment_int(const char* name, int fallback) {
  const std::string value = environment(name, "");
  if (value.empty()) return fallback;
  char* end = nullptr;
  const long parsed = std::strtol(value.c_str(), &end, 10);
  return end != value.c_str() && *end == '\0' && parsed >= 0 &&
                 parsed <= std::numeric_limits<int>::max()
             ? static_cast<int>(parsed)
             : fallback;
}
bool write_all(int fd, const std::string& value) {
  std::size_t offset = 0;
  while (offset < value.size()) {
    const long long count = neurx_net_write(fd, value.data() + offset, value.size() - offset);
    if (count > 0) { offset += static_cast<std::size_t>(count); continue; }
    if ((count == -EAGAIN || count == -EWOULDBLOCK) &&
        neurx_net_poll(fd, NEURX_POLL_WRITE, 30000) > 0) continue;
    return false;
  }
  return true;
}
bool read_request(int fd, std::string* method, std::string* path, std::string* body) {
  std::string request;
  std::size_t expected = std::numeric_limits<std::size_t>::max();
  while (request.size() <= (4U << 20)) {
    const std::size_t separator = request.find("\r\n\r\n");
    if (separator != std::string::npos) {
      const std::size_t marker = request.find("Content-Length:");
      if (marker == std::string::npos) return false;
      char* end = nullptr;
      const unsigned long long length = std::strtoull(request.c_str() + marker + 15, &end, 10);
      if (end == request.c_str() + marker + 15 || length > (4U << 20)) return false;
      expected = separator + 4 + static_cast<std::size_t>(length);
      if (request.size() >= expected) break;
    }
    char buffer[8192];
    const long long count = neurx_net_read(fd, buffer, sizeof(buffer));
    if (count > 0) { request.append(buffer, static_cast<std::size_t>(count)); continue; }
    if ((count == -EAGAIN || count == -EWOULDBLOCK) &&
        neurx_net_poll(fd, NEURX_POLL_READ, 30000) > 0) continue;
    return false;
  }
  const std::size_t first = request.find(' ');
  const std::size_t second = first == std::string::npos ? first : request.find(' ', first + 1);
  const std::size_t separator = request.find("\r\n\r\n");
  if (expected == std::numeric_limits<std::size_t>::max() || first == std::string::npos ||
      second == std::string::npos || separator == std::string::npos) return false;
  *method = request.substr(0, first);
  *path = request.substr(first + 1, second - first - 1);
  *body = request.substr(separator + 4, expected - separator - 4);
  return true;
}
void respond(int fd, int code, const char* status, const std::string& body) {
  write_all(fd, "HTTP/1.1 " + std::to_string(code) + " " + status +
                    "\r\nContent-Type: application/json\r\nContent-Length: " +
                    std::to_string(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
}
std::vector<int32_t> eos_tokens(const std::string& directory) {
  const std::filesystem::path path = std::filesystem::path(directory) / "generation_config.json";
  if (!std::filesystem::exists(path)) return {};
  const json root = json::parse_file(path.string());
  if (!root.contains("eos_token_id")) return {};
  const json& value = root.at("eos_token_id");
  std::vector<int32_t> result;
  if (value.is_array()) {
    for (const json& item : value.as_array()) result.push_back(static_cast<int32_t>(item.as_int()));
  } else if (value.is_number()) {
    result.push_back(static_cast<int32_t>(value.as_int()));
  }
  return result;
}
bool contains(const std::vector<int32_t>& values, int32_t value) {
  for (int32_t candidate : values) if (candidate == value) return true;
  return false;
}
}
int main() {
  try {
    const std::string directory = environment("NEURX_MODEL_DIR", "");
    if (directory.empty()) throw std::runtime_error("NEURX_MODEL_DIR is required");
    neurx::cuda::hf_decoder_cuda model(directory, environment_int("NEURX_CUDA_DEVICE", 0));
    const std::vector<int32_t> stop_tokens = eos_tokens(directory);
    const std::string host = environment("NEURX_HF_CUDA_HOST", "127.0.0.1");
    const int port = environment_int("NEURX_HF_CUDA_PORT", 18081);
    const int listener = neurx_net_listen(host.c_str(), port, 128);
    if (listener < 0) throw std::runtime_error("cannot listen for HF CUDA token requests");
    std::signal(SIGINT, stop);
    std::signal(SIGTERM, stop);
    while (running) {
      if (neurx_net_poll(listener, NEURX_POLL_READ, 1000) <= 0) continue;
      const int client = neurx_net_accept(listener);
      if (client < 0) continue;
      try {
        std::string method, path, body;
        if (!read_request(client, &method, &path, &body)) {
          respond(client, 400, "Bad Request", "{\"error\":\"invalid request\"}");
        } else if (method == "GET" && path == "/health") {
          respond(client, 200, "OK", "{\"status\":\"ok\",\"backend\":\"hf-cuda\"}");
        } else if (method == "POST" && path == "/v1/token-stream") {
          const json request = json::parse(body);
          std::vector<int32_t> ids;
          for (const json& item : request.at("input_ids").as_array()) {
            ids.push_back(static_cast<int32_t>(item.as_int()));
          }
          const int maximum = static_cast<int>(request.at("max_new_tokens").as_int());
          if (ids.empty() || maximum <= 0) throw std::runtime_error("invalid generation dimensions");
          if (!write_all(client, "HTTP/1.1 200 OK\r\nContent-Type: application/x-ndjson\r\n"
                                 "Cache-Control: no-cache\r\nConnection: close\r\n\r\n")) {
            throw std::runtime_error("token stream header write failed");
          }
          neurx::cuda::hf_cuda_kv_cache cache;
          std::vector<float> logits = model.prefill(ids, &cache);
          for (int index = 0; index < maximum; ++index) {
            const int32_t token = neurx::cuda::hf_decoder_cuda::greedy(logits);
            const bool finished = contains(stop_tokens, token) || index + 1 == maximum;
            if (!write_all(client, "{\"token\":" + std::to_string(token) +
                                       ",\"finish\":" + (finished ? "true" : "false") + "}\n")) {
              throw std::runtime_error("token stream write failed");
            }
            if (finished) break;
            logits = model.decode(token, &cache);
          }
        } else {
          respond(client, 404, "Not Found", "{\"error\":\"route not found\"}");
        }
      } catch (const std::exception& error) {
        respond(client, 500, "Internal Server Error",
                "{\"error\":\"" + std::string(error.what()) + "\"}");
      }
      neurx_net_close(client);
    }
    neurx_net_close(listener);
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "%s\n", error.what());
    return 1;
  }
}
