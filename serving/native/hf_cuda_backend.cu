#include "../../cuda/hf_decoder_cuda.h"
#include "../../runtime/model/bpe_tokenizer.h"
#include "../../runtime/model/json.h"
#include "serving_socket.h"
#include <algorithm>
#include <cmath>
#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <limits>
#include <random>
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
      if (marker == std::string::npos) {
        expected = separator + 4;
      } else {
        char* end = nullptr;
        const unsigned long long length = std::strtoull(request.c_str() + marker + 15, &end, 10);
        if (end == request.c_str() + marker + 15 || length > (4U << 20)) return false;
        expected = separator + 4 + static_cast<std::size_t>(length);
      }
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

std::string json_escape(const std::string& value) {
  std::string output;
  output.reserve(value.size() + 16);
  for (const unsigned char ch : value) {
    switch (ch) {
      case '"': output += "\\\""; break;
      case '\\': output += "\\\\"; break;
      case '\b': output += "\\b"; break;
      case '\f': output += "\\f"; break;
      case '\n': output += "\\n"; break;
      case '\r': output += "\\r"; break;
      case '\t': output += "\\t"; break;
      default:
        if (ch < 0x20) {
          static constexpr char hex[] = "0123456789abcdef";
          output += "\\u00";
          output.push_back(hex[ch >> 4]);
          output.push_back(hex[ch & 0x0f]);
        } else {
          output.push_back(static_cast<char>(ch));
        }
    }
  }
  return output;
}

int32_t sample_token(std::vector<float> logits, const std::vector<int32_t>& generated,
                     std::mt19937* random) {
  constexpr float repetition_penalty = 1.1F;
  constexpr float temperature = 0.7F;
  constexpr float top_p = 0.8F;
  constexpr std::size_t top_k = 20;
  for (const int32_t token : generated) {
    if (token < 0 || static_cast<std::size_t>(token) >= logits.size()) continue;
    float& value = logits[static_cast<std::size_t>(token)];
    value = value < 0.0F ? value * repetition_penalty : value / repetition_penalty;
  }
  std::vector<int32_t> candidates(logits.size());
  for (std::size_t index = 0; index < candidates.size(); ++index) {
    candidates[index] = static_cast<int32_t>(index);
  }
  const std::size_t count = std::min(top_k, candidates.size());
  std::partial_sort(candidates.begin(), candidates.begin() + count, candidates.end(),
                    [&](int32_t left, int32_t right) { return logits[left] > logits[right]; });
  candidates.resize(count);
  const float maximum = logits[candidates.front()];
  std::vector<double> weights;
  weights.reserve(count);
  double total = 0.0;
  for (const int32_t token : candidates) {
    const double weight = std::exp((logits[token] - maximum) / temperature);
    weights.push_back(weight);
    total += weight;
  }
  double cumulative = 0.0;
  std::size_t nucleus = 0;
  while (nucleus < weights.size()) {
    cumulative += weights[nucleus];
    ++nucleus;
    if (cumulative / total >= top_p) break;
  }
  candidates.resize(nucleus);
  weights.resize(nucleus);
  std::discrete_distribution<std::size_t> distribution(weights.begin(), weights.end());
  return candidates[distribution(*random)];
}

std::string generate_text(neurx::cuda::hf_decoder_cuda* model,
                          const neurx::runtime::model::bpe_tokenizer& tokenizer,
                          const std::vector<int32_t>& stop_tokens, const std::string& prompt,
                          int maximum, std::mt19937* random) {
  std::vector<int32_t> input = tokenizer.encode(prompt, true);
  if (input.empty()) throw std::runtime_error("prompt tokenization produced no tokens");
  const std::size_t context = static_cast<std::size_t>(model->config().max_position_embeddings);
  const std::size_t reserve = std::min<std::size_t>(static_cast<std::size_t>(maximum), context - 1);
  if (input.size() + reserve > context) {
    input.erase(input.begin(), input.begin() + (input.size() + reserve - context));
  }
  neurx::cuda::hf_cuda_kv_cache cache;
  std::vector<float> logits = model->prefill(input, &cache);
  std::vector<int32_t> generated;
  generated.reserve(static_cast<std::size_t>(maximum));
  for (int index = 0; index < maximum; ++index) {
    const int32_t token = sample_token(std::move(logits), generated, random);
    if (contains(stop_tokens, token)) break;
    generated.push_back(token);
    if (index + 1 < maximum) logits = model->decode(token, &cache);
  }
  return tokenizer.decode(generated, true);
}
}
int main() {
  try {
    const std::string directory = environment("NEURX_MODEL_DIR", "");
    if (directory.empty()) throw std::runtime_error("NEURX_MODEL_DIR is required");
    neurx::cuda::hf_decoder_cuda model(directory, environment_int("NEURX_CUDA_DEVICE", 0));
    const neurx::runtime::model::bpe_tokenizer tokenizer =
        neurx::runtime::model::bpe_tokenizer::from_directory(directory);
    const std::vector<int32_t> stop_tokens = eos_tokens(directory);
    std::mt19937 random(static_cast<std::mt19937::result_type>(std::random_device{}()));
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
        } else if (method == "POST" && path == "/v1/generate") {
          const json request = json::parse(body);
          const std::string prompt = request.at("prompt").as_string();
          int maximum = 128;
          if (request.contains("max_new_tokens")) {
            maximum = static_cast<int>(request.at("max_new_tokens").as_int());
          }
          maximum = std::clamp(maximum, 1, 2048);
          const std::string output =
              generate_text(&model, tokenizer, stop_tokens, prompt, maximum, &random);
          respond(client, 200, "OK",
                  "{\"status\":\"ok\",\"output\":\"" + json_escape(output) +
                      "\",\"backend\":\"neurx-hf-cuda\"}");
        } else if (method == "POST" && path == "/reset") {
          respond(client, 200, "OK", "{\"status\":\"ok\"}");
        } else {
          respond(client, 404, "Not Found", "{\"error\":\"route not found\"}");
        }
      } catch (const std::exception& error) {
        respond(client, 500, "Internal Server Error",
                "{\"error\":\"" + json_escape(error.what()) + "\"}");
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
