#include "ascend_worker.h"
#include "../model/nxtrfmv2_loader.h"
#include "../../serving/native/serving_socket.h"

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::atomic<bool> running{true};

void stop_server(int) { running = false; }

std::string environment(const char* name, const char* fallback = "") {
  const char* value = std::getenv(name);
  return value && *value ? value : fallback;
}

long environment_long(const char* name, long fallback) {
  const std::string value = environment(name);
  if (value.empty()) return fallback;
  char* end = nullptr;
  errno = 0;
  const long parsed = std::strtol(value.c_str(), &end, 10);
  return errno == 0 && end && *end == '\0' ? parsed : fallback;
}

bool write_all(int fd, const std::string& value) {
  std::size_t offset = 0;
  while (offset < value.size()) {
    const long long written =
        neurx_net_write(fd, value.data() + offset, value.size() - offset);
    if (written > 0) {
      offset += static_cast<std::size_t>(written);
      continue;
    }
    if (written == -EAGAIN || written == -EWOULDBLOCK) {
      if (neurx_net_poll(fd, NEURX_POLL_WRITE, 30000) <= 0) return false;
      continue;
    }
    return false;
  }
  return true;
}

void respond(int fd, int code, const char* status, const std::string& body,
             const char* content_type = "application/json") {
  std::ostringstream response;
  response << "HTTP/1.1 " << code << ' ' << status << "\r\n"
           << "Content-Type: " << content_type << "\r\n"
           << "Content-Length: " << body.size() << "\r\n"
           << "Connection: close\r\n\r\n"
           << body;
  write_all(fd, response.str());
}

std::size_t content_length(const std::string& headers) {
  const std::string key = "Content-Length:";
  const std::size_t position = headers.find(key);
  if (position == std::string::npos) return 0;
  const char* begin = headers.c_str() + position + key.size();
  char* end = nullptr;
  const unsigned long long length = std::strtoull(begin, &end, 10);
  return end == begin || length > (1U << 20)
             ? std::numeric_limits<std::size_t>::max()
             : static_cast<std::size_t>(length);
}

bool read_request(int fd, std::string* method, std::string* path,
                  std::string* body) {
  std::string request;
  request.reserve(4096);
  std::size_t expected = std::numeric_limits<std::size_t>::max();
  while (request.size() <= (1U << 20)) {
    const std::size_t separator = request.find("\r\n\r\n");
    if (separator != std::string::npos) {
      const std::size_t length = content_length(request.substr(0, separator));
      if (length == std::numeric_limits<std::size_t>::max()) return false;
      expected = separator + 4 + length;
      if (request.size() >= expected) break;
    }
    char buffer[8192];
    const long long count = neurx_net_read(fd, buffer, sizeof(buffer));
    if (count > 0) {
      request.append(buffer, static_cast<std::size_t>(count));
      continue;
    }
    if (count == -EAGAIN || count == -EWOULDBLOCK) {
      if (neurx_net_poll(fd, NEURX_POLL_READ, 30000) <= 0) return false;
      continue;
    }
    return false;
  }
  if (expected == std::numeric_limits<std::size_t>::max()) return false;
  const std::size_t first_space = request.find(' ');
  const std::size_t second_space =
      first_space == std::string::npos
          ? std::string::npos
          : request.find(' ', first_space + 1);
  const std::size_t separator = request.find("\r\n\r\n");
  if (first_space == std::string::npos || second_space == std::string::npos ||
      separator == std::string::npos) {
    return false;
  }
  *method = request.substr(0, first_space);
  *path = request.substr(first_space + 1, second_space - first_space - 1);
  *body = request.substr(separator + 4, expected - separator - 4);
  return true;
}

bool json_number(const std::string& body, const char* name, double fallback,
                 double* output) {
  const std::string key = std::string("\"") + name + "\"";
  const std::size_t position = body.find(key);
  if (position == std::string::npos) {
    *output = fallback;
    return true;
  }
  const std::size_t colon = body.find(':', position + key.size());
  if (colon == std::string::npos) return false;
  char* end = nullptr;
  errno = 0;
  const double value = std::strtod(body.c_str() + colon + 1, &end);
  if (errno != 0 || end == body.c_str() + colon + 1) return false;
  *output = value;
  return true;
}

bool json_integer_array(const std::string& body, const char* name,
                        std::vector<int32_t>* values) {
  const std::string key = std::string("\"") + name + "\"";
  const std::size_t position = body.find(key);
  const std::size_t open =
      position == std::string::npos ? std::string::npos : body.find('[', position);
  if (open == std::string::npos) return false;
  values->clear();
  std::size_t cursor = open + 1;
  while (cursor < body.size()) {
    while (cursor < body.size() &&
           (body[cursor] == ' ' || body[cursor] == '\t' ||
            body[cursor] == '\r' || body[cursor] == '\n' ||
            body[cursor] == ',')) {
      ++cursor;
    }
    if (cursor < body.size() && body[cursor] == ']') return true;
    char* end = nullptr;
    errno = 0;
    const long value = std::strtol(body.c_str() + cursor, &end, 10);
    if (errno != 0 || end == body.c_str() + cursor || value < 0 ||
        value > std::numeric_limits<int32_t>::max()) {
      return false;
    }
    values->push_back(static_cast<int32_t>(value));
    cursor = static_cast<std::size_t>(end - body.c_str());
  }
  return false;
}

std::string tokens_json(const std::vector<int32_t>& tokens) {
  std::ostringstream output;
  output << "{\"object\":\"token_completion\",\"token_ids\":[";
  for (std::size_t index = 0; index < tokens.size(); ++index) {
    if (index) output << ',';
    output << tokens[index];
  }
  output << "],\"generated_tokens\":" << tokens.size() << '}';
  return output.str();
}

struct RequestRelease {
  neurx::inference::AscendWorker* worker;
  std::string id;
  ~RequestRelease() {
    if (worker) worker->release_request(id);
  }
};

neurx::inference::AdapterStatus generate(
    neurx::inference::AscendWorker& worker, const std::string& request_id,
    const std::vector<int32_t>& prompt, int max_new_tokens,
    const neurx::inference::SamplingConfig& sampling,
    const std::vector<int32_t>& stop_tokens,
    std::vector<int32_t>* generated) {
  using namespace neurx::inference;
  if (prompt.empty() || max_new_tokens <= 0) {
    return AdapterStatus::failure(
        "input_ids must be non-empty and max_new_tokens must be positive");
  }
  const std::size_t maximum_sequence =
      worker.executor().model().metadata().max_sequence;
  if (prompt.size() > maximum_sequence ||
      static_cast<std::size_t>(max_new_tokens - 1) >
          maximum_sequence - prompt.size()) {
    return AdapterStatus::failure(
        "prompt and generated tokens exceed the model sequence limit");
  }
  RequestRelease release{&worker, request_id};
  std::vector<int32_t> history = prompt;
  Batch batch;
  batch.phase = Phase::prefill;
  batch.key = {Backend::ascend, "fp16"};
  batch.items = {{request_id, static_cast<int>(prompt.size())}};
  batch.total_tokens = static_cast<int>(prompt.size());
  WorkerBatchResult result;
  SamplingConfig step_sampling = sampling;
  AdapterStatus status =
      worker.execute(batch, prompt, {step_sampling}, {history}, &result);
  if (!status.ok) return status;

  generated->clear();
  int32_t token = result.next_tokens.front();
  for (int index = 0; index < max_new_tokens; ++index) {
    generated->push_back(token);
    if (std::find(stop_tokens.begin(), stop_tokens.end(), token) !=
        stop_tokens.end()) {
      break;
    }
    if (index + 1 >= max_new_tokens) break;
    history.push_back(token);
    batch.phase = Phase::decode;
    batch.items.front().token_count = 1;
    batch.total_tokens = 1;
    step_sampling.seed = sampling.seed + static_cast<uint64_t>(index + 1);
    status =
        worker.execute(batch, {token}, {step_sampling}, {history}, &result);
    if (!status.ok) return status;
    token = result.next_tokens.front();
  }
  return AdapterStatus::success();
}

}  // namespace

int main() {
  const std::string checkpoint = environment("NEURX_CHECKPOINT");
  const std::string operators = environment("NEURX_CANN_OPERATOR_LIBRARY");
  if (checkpoint.empty() || operators.empty()) {
    std::cerr << "NEURX_CHECKPOINT and NEURX_CANN_OPERATOR_LIBRARY are required\n";
    return 2;
  }

  neurx::cann::ModelMetadata metadata;
  neurx::cann::Status inspected =
      neurx::cann::inspect_nxtrfmv2(checkpoint, &metadata);
  if (!inspected.ok) {
    std::cerr << inspected.message << '\n';
    return 2;
  }
  const long blocks = environment_long("NEURX_ASCEND_KV_BLOCKS", 512);
  const long block_tokens =
      environment_long("NEURX_ASCEND_KV_BLOCK_TOKENS", 16);
  const long device = environment_long("NEURX_ASCEND_DEVICE_ID", 0);
  const long port = environment_long("NEURX_HTTP_PORT", 8080);
  if (blocks <= 0 || block_tokens <= 0 || device < 0 || port <= 0 ||
      port > 65535) {
    std::cerr << "invalid Ascend worker environment configuration\n";
    return 2;
  }

  neurx::inference::AscendExecutorConfig config;
  config.operator_library = operators;
  config.checkpoint = checkpoint;
  config.kv_cache = neurx::cann::KvCacheConfig::fp16_310p(
      static_cast<std::size_t>(blocks), static_cast<std::size_t>(block_tokens),
      metadata.layers, metadata.attention_heads,
      metadata.hidden_size / metadata.attention_heads);
  neurx::inference::AscendWorker worker(std::move(config));
  neurx::inference::AdapterStatus initialized =
      worker.initialize(static_cast<int>(device));
  if (!initialized.ok) {
    std::cerr << initialized.message << '\n';
    return 1;
  }

  const int listener = neurx_net_listen("0.0.0.0", static_cast<int>(port), 128);
  if (listener < 0) {
    std::cerr << "cannot listen on port " << port << ": " << listener << '\n';
    return 1;
  }
  std::signal(SIGINT, stop_server);
  std::signal(SIGTERM, stop_server);
  bool draining = false;
  uint64_t requests = 0;
  uint64_t failures = 0;
  uint64_t generated_total = 0;
  std::cerr << "NeurX Ascend worker ready on port " << port << '\n';

  while (running) {
    const int ready = neurx_net_poll(listener, NEURX_POLL_READ, 1000);
    if (ready <= 0) continue;
    const int client = neurx_net_accept(listener);
    if (client < 0) continue;
    std::string method, path, body;
    if (!read_request(client, &method, &path, &body)) {
      respond(client, 400, "Bad Request", "{\"error\":\"invalid request\"}");
      neurx_net_close(client);
      continue;
    }
    if (method == "GET" &&
        (path == "/health/live" || path == "/health/ready" ||
         path == "/health")) {
      const bool healthy = path != "/health/ready" || !draining;
      respond(client, healthy ? 200 : 503,
              healthy ? "OK" : "Service Unavailable",
              healthy ? "{\"status\":\"ok\"}"
                      : "{\"status\":\"draining\"}");
    } else if (method == "GET" && path == "/metrics") {
      std::ostringstream metrics;
      metrics << "neurx_ascend_requests_total " << requests << '\n'
              << "neurx_ascend_failures_total " << failures << '\n'
              << "neurx_ascend_generated_tokens_total " << generated_total
              << '\n';
      respond(client, 200, "OK", metrics.str(), "text/plain");
    } else if (method == "POST" && path == "/admin/drain") {
      draining = true;
      respond(client, 200, "OK", "{\"status\":\"draining\"}");
    } else if (method == "POST" && path == "/v1/token-completions" &&
               !draining) {
      ++requests;
      std::vector<int32_t> prompt, stop_tokens, generated;
      double max_new = 0, temperature = 1, top_k = 0, top_p = 1;
      double penalty = 1, seed = 0;
      const bool valid =
          json_integer_array(body, "input_ids", &prompt) &&
          json_number(body, "max_new_tokens", 16, &max_new) &&
          json_number(body, "temperature", 1, &temperature) &&
          json_number(body, "top_k", 0, &top_k) &&
          json_number(body, "top_p", 1, &top_p) &&
          json_number(body, "repetition_penalty", 1, &penalty) &&
          json_number(body, "seed", 0, &seed);
      if (body.find("\"stop_token_ids\"") != std::string::npos &&
          !json_integer_array(body, "stop_token_ids", &stop_tokens)) {
        ++failures;
        respond(client, 400, "Bad Request",
                "{\"error\":\"invalid stop_token_ids\"}");
      } else if (!valid || max_new < 1 || max_new > 65536 ||
                 top_k < 0 || top_k > std::numeric_limits<int>::max() ||
                 seed < 0) {
        ++failures;
        respond(client, 400, "Bad Request",
                "{\"error\":\"invalid generation parameters\"}");
      } else {
        neurx::inference::SamplingConfig sampling;
        sampling.temperature = static_cast<float>(temperature);
        sampling.top_k = static_cast<int>(top_k);
        sampling.top_p = static_cast<float>(top_p);
        sampling.repetition_penalty = static_cast<float>(penalty);
        sampling.seed = static_cast<uint64_t>(seed);
        const std::string id = "ascend-" + std::to_string(requests);
        const auto status =
            generate(worker, id, prompt, static_cast<int>(max_new), sampling,
                     stop_tokens, &generated);
        if (!status.ok) {
          ++failures;
          respond(client, 500, "Internal Server Error",
                  "{\"error\":\"" + status.message + "\"}");
        } else {
          generated_total += generated.size();
          respond(client, 200, "OK", tokens_json(generated));
        }
      }
    } else {
      respond(client, draining ? 503 : 404,
              draining ? "Service Unavailable" : "Not Found",
              draining ? "{\"error\":\"worker is draining\"}"
                       : "{\"error\":\"route not found\"}");
    }
    neurx_net_close(client);
  }
  neurx_net_close(listener);
  return 0;
}
