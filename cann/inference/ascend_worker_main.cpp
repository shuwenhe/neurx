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
#include <utility>
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

bool json_integer_arrays(const std::string& body, const char* name,
                         std::vector<std::vector<int32_t>>* values) {
  const std::string key = std::string("\"") + name + "\"";
  const std::size_t position = body.find(key);
  const std::size_t outer =
      position == std::string::npos ? std::string::npos : body.find('[', position);
  if (outer == std::string::npos) return false;
  values->clear();
  std::size_t cursor = outer + 1;
  while (cursor < body.size()) {
    while (cursor < body.size() &&
           (body[cursor] == ' ' || body[cursor] == '\t' ||
            body[cursor] == '\r' || body[cursor] == '\n' ||
            body[cursor] == ',')) {
      ++cursor;
    }
    if (cursor < body.size() && body[cursor] == ']') return !values->empty();
    if (cursor >= body.size() || body[cursor] != '[') return false;
    ++cursor;
    std::vector<int32_t> row;
    while (cursor < body.size()) {
      while (cursor < body.size() &&
             (body[cursor] == ' ' || body[cursor] == '\t' ||
              body[cursor] == '\r' || body[cursor] == '\n' ||
              body[cursor] == ',')) {
        ++cursor;
      }
      if (cursor < body.size() && body[cursor] == ']') {
        ++cursor;
        break;
      }
      char* end = nullptr;
      errno = 0;
      const long token = std::strtol(body.c_str() + cursor, &end, 10);
      if (errno != 0 || end == body.c_str() + cursor || token < 0 ||
          token > std::numeric_limits<int32_t>::max()) {
        return false;
      }
      row.push_back(static_cast<int32_t>(token));
      cursor = static_cast<std::size_t>(end - body.c_str());
    }
    if (row.empty()) return false;
    values->push_back(std::move(row));
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

std::string batch_tokens_json(
    const std::vector<std::vector<int32_t>>& tokens) {
  std::ostringstream output;
  std::size_t total = 0;
  output << "{\"object\":\"token_completion_batch\",\"token_ids\":[";
  for (std::size_t row = 0; row < tokens.size(); ++row) {
    if (row) output << ',';
    output << '[';
    for (std::size_t index = 0; index < tokens[row].size(); ++index) {
      if (index) output << ',';
      output << tokens[row][index];
    }
    output << ']';
    total += tokens[row].size();
  }
  output << "],\"requests\":" << tokens.size()
         << ",\"generated_tokens\":" << total << '}';
  return output.str();
}

std::string top_logits_json(const std::vector<float>& logits,
                            std::size_t requested) {
  std::vector<std::pair<float, int32_t>> ranked;
  ranked.reserve(logits.size());
  for (std::size_t token = 0; token < logits.size(); ++token) {
    ranked.emplace_back(logits[token], static_cast<int32_t>(token));
  }
  requested = std::min(requested, ranked.size());
  std::partial_sort(
      ranked.begin(), ranked.begin() + requested, ranked.end(),
      [](const auto& left, const auto& right) {
        return left.first > right.first;
      });
  std::ostringstream output;
  output.precision(9);
  output << "{\"top_logits\":[";
  for (std::size_t index = 0; index < requested; ++index) {
    if (index) output << ',';
    output << "{\"token_id\":" << ranked[index].second
           << ",\"logit\":" << ranked[index].first << '}';
  }
  output << "]}";
  return output.str();
}

struct request_release {
  neurx::inference::AscendWorker* worker;
  std::string id;
  ~request_release() {
    if (worker) worker->release_request(id);
  }
};

struct batch_request_release {
  neurx::inference::AscendWorker* worker;
  std::vector<std::string> ids;
  void release(std::size_t row) {
    if (worker && row < ids.size() && !ids[row].empty()) {
      worker->release_request(ids[row]);
      ids[row].clear();
    }
  }
  ~batch_request_release() {
    if (!worker) return;
    for (const std::string& id : ids) {
      if (!id.empty()) worker->release_request(id);
    }
  }
};

neurx::inference::adapter_status generate(
    neurx::inference::AscendWorker& worker, const std::string& request_id,
    const std::vector<int32_t>& prompt, int max_new_tokens,
    const neurx::inference::sampling_config_2& sampling,
    const std::vector<int32_t>& stop_tokens,
    std::vector<int32_t>* generated) {
  using namespace neurx::inference;
  if (prompt.empty() || max_new_tokens <= 0) {
    return adapter_status::failure(
        "input_ids must be non-empty and max_new_tokens must be positive");
  }
  const std::size_t maximum_sequence =
      worker.executor().model().metadata().max_sequence;
  if (prompt.size() > maximum_sequence ||
      static_cast<std::size_t>(max_new_tokens - 1) >
          maximum_sequence - prompt.size()) {
    return adapter_status::failure(
        "prompt and generated tokens exceed the model sequence limit");
  }
  request_release release{&worker, request_id};
  std::vector<int32_t> history = prompt;
  batch_2 batch;
  batch.phase = Phase::prefill;
  batch.key = {Backend::ascend, "fp16"};
  batch.items = {{request_id, static_cast<int>(prompt.size())}};
  batch.total_tokens = static_cast<int>(prompt.size());
  worker_batch_result result;
  sampling_config_2 step_sampling = sampling;
  adapter_status status =
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
  return adapter_status::success();
}

neurx::inference::adapter_status generate_batch(
    neurx::inference::AscendWorker& worker, const std::string& batch_id,
    const std::vector<std::vector<int32_t>>& prompts, int max_new_tokens,
    const neurx::inference::sampling_config_2& sampling,
    const std::vector<int32_t>& stop_tokens,
    std::vector<std::vector<int32_t>>* generated) {
  using namespace neurx::inference;
  if (prompts.empty() || max_new_tokens <= 0 || !generated) {
    return adapter_status::failure("batch generation arguments are invalid");
  }
  const std::size_t maximum_sequence =
      worker.executor().model().metadata().max_sequence;
  batch_request_release release{&worker, {}};
  batch_2 batch;
  batch.phase = Phase::prefill;
  batch.key = {Backend::ascend, "fp16"};
  std::vector<int32_t> input_tokens;
  std::vector<sampling_config_2> sampling_rows;
  std::vector<std::vector<int32_t>> histories = prompts;
  release.ids.reserve(prompts.size());
  batch.items.reserve(prompts.size());
  sampling_rows.reserve(prompts.size());
  for (std::size_t row = 0; row < prompts.size(); ++row) {
    if (prompts[row].empty() || prompts[row].size() > maximum_sequence ||
        static_cast<std::size_t>(max_new_tokens - 1) >
            maximum_sequence - prompts[row].size()) {
      return adapter_status::failure(
          "a batch prompt exceeds the model sequence limit");
    }
    const std::string id = batch_id + "-" + std::to_string(row);
    release.ids.push_back(id);
    batch.items.push_back({id, static_cast<int>(prompts[row].size())});
    batch.total_tokens += static_cast<int>(prompts[row].size());
    input_tokens.insert(input_tokens.end(), prompts[row].begin(),
                        prompts[row].end());
    sampling_config_2 row_sampling = sampling;
    row_sampling.seed += row;
    sampling_rows.push_back(row_sampling);
  }

  worker_batch_result result;
  adapter_status status =
      worker.execute(batch, input_tokens, sampling_rows, histories, &result);
  if (!status.ok) return status;
  generated->assign(prompts.size(), {});
  std::vector<std::size_t> active;
  active.reserve(prompts.size());
  for (std::size_t row = 0; row < prompts.size(); ++row) {
    const int32_t token = result.next_tokens[row];
    (*generated)[row].push_back(token);
    histories[row].push_back(token);
    const bool stopped =
        std::find(stop_tokens.begin(), stop_tokens.end(), token) !=
        stop_tokens.end();
    if (!stopped && max_new_tokens > 1) {
      active.push_back(row);
    } else {
      release.release(row);
    }
  }

  for (int step = 1; !active.empty() && step < max_new_tokens; ++step) {
    batch_2 decode;
    decode.phase = Phase::decode;
    decode.key = {Backend::ascend, "fp16"};
    decode.total_tokens = static_cast<int>(active.size());
    std::vector<int32_t> decode_tokens;
    std::vector<sampling_config_2> decode_sampling;
    std::vector<std::vector<int32_t>> decode_histories;
    decode.items.reserve(active.size());
    decode_tokens.reserve(active.size());
    decode_sampling.reserve(active.size());
    decode_histories.reserve(active.size());
    for (const std::size_t row : active) {
      decode.items.push_back({release.ids[row], 1});
      decode_tokens.push_back((*generated)[row].back());
      sampling_config_2 row_sampling = sampling;
      row_sampling.seed += static_cast<uint64_t>(step) * prompts.size() + row;
      decode_sampling.push_back(row_sampling);
      decode_histories.push_back(histories[row]);
    }
    status = worker.execute(decode, decode_tokens, decode_sampling,
                            decode_histories, &result);
    if (!status.ok) return status;
    std::vector<std::size_t> next_active;
    next_active.reserve(active.size());
    for (std::size_t local = 0; local < active.size(); ++local) {
      const std::size_t row = active[local];
      const int32_t token = result.next_tokens[local];
      (*generated)[row].push_back(token);
      histories[row].push_back(token);
      const bool stopped =
          std::find(stop_tokens.begin(), stop_tokens.end(), token) !=
          stop_tokens.end();
      if (!stopped && step + 1 < max_new_tokens) {
        next_active.push_back(row);
      } else {
        release.release(row);
      }
    }
    active.swap(next_active);
  }
  return adapter_status::success();
}

}

int main() {
  const std::string checkpoint = environment("NEURX_CHECKPOINT");
  const std::string operators = environment("NEURX_CANN_OPERATOR_LIBRARY");
  if (checkpoint.empty() || operators.empty()) {
    std::cerr << "NEURX_CHECKPOINT and NEURX_CANN_OPERATOR_LIBRARY are required\n";
    return 2;
  }

  neurx::cann::model_metadata metadata;
  neurx::cann::status inspected =
      neurx::cann::inspect_nxtrfmv2(checkpoint, &metadata);
  if (!inspected.ok) {
    std::cerr << inspected.message << '\n';
    return 2;
  }
  const long blocks = environment_long("NEURX_ASCEND_KV_BLOCKS", 512);
  const long block_tokens =
      environment_long("NEURX_ASCEND_KV_BLOCK_TOKENS", 16);
  const long prefix_entries =
      environment_long("NEURX_ASCEND_PREFIX_CACHE_ENTRIES", 256);
  const long prefix_blocks =
      environment_long("NEURX_ASCEND_PREFIX_CACHE_BLOCKS", 128);
  const long device = environment_long("NEURX_ASCEND_DEVICE_ID", 0);
  const long port = environment_long("NEURX_HTTP_PORT", 8080);
  const long http_max_batch =
      environment_long("NEURX_ASCEND_HTTP_MAX_BATCH", 64);
  const bool benchmark_api =
      environment_long("NEURX_ASCEND_ENABLE_BENCHMARK_API", 0) == 1;
  const std::string precision =
      environment("NEURX_ASCEND_PRECISION").empty()
          ? "fp16"
          : environment("NEURX_ASCEND_PRECISION");
  if (blocks <= 0 || block_tokens <= 0 || prefix_entries < 0 ||
      prefix_blocks < 0 || device < 0 || port <= 0 || port > 65535 ||
      http_max_batch <= 0 || http_max_batch > 2000) {
    std::cerr << "invalid Ascend worker environment configuration\n";
    return 2;
  }

  neurx::inference::ascend_executor_config config;
  config.operator_library = operators;
  config.checkpoint = checkpoint;
  if (precision == "fp16") {
    config.model.precision = neurx::cann::ModelPrecision::fp16;
  } else if (precision == "int8" || precision == "int8_weight_only") {
    config.model.precision =
        neurx::cann::ModelPrecision::int8_weight_only;
  } else {
    std::cerr << "NEURX_ASCEND_PRECISION must be fp16 or int8\n";
    return 2;
  }
  config.kv_cache = neurx::cann::kv_cache_config_2::fp16_310p(
      static_cast<std::size_t>(blocks), static_cast<std::size_t>(block_tokens),
      metadata.layers, metadata.attention_heads,
      metadata.hidden_size / metadata.attention_heads);
  neurx::cann::prefix_cache_config prefix_config;
  prefix_config.max_entries = static_cast<std::size_t>(prefix_entries);
  prefix_config.max_retained_blocks =
      static_cast<std::size_t>(prefix_blocks);
  neurx::inference::AscendWorker worker(std::move(config), prefix_config);
  neurx::inference::adapter_status initialized =
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
      respond(client, 400, "Bad request", "{\"error\":\"invalid request\"}");
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
      const neurx::cann::prefix_cache_stats prefix =
          worker.prefix_cache_stats();
      std::ostringstream metrics;
      metrics << "neurx_ascend_requests_total " << requests << '\n'
              << "neurx_ascend_failures_total " << failures << '\n'
              << "neurx_ascend_generated_tokens_total " << generated_total
              << '\n'
              << "neurx_ascend_prefix_cache_entries " << prefix.entries
              << '\n'
              << "neurx_ascend_prefix_cache_retained_blocks "
              << prefix.retained_blocks << '\n'
              << "neurx_ascend_prefix_cache_lookups_total " << prefix.lookups
              << '\n'
              << "neurx_ascend_prefix_cache_hits_total " << prefix.hits
              << '\n'
              << "neurx_ascend_prefix_cache_evictions_total "
              << prefix.evictions << '\n';
      respond(client, 200, "OK", metrics.str(), "text/plain");
    } else if (method == "POST" && path == "/admin/drain") {
      draining = true;
      respond(client, 200, "OK", "{\"status\":\"draining\"}");
    } else if (method == "POST" && path == "/v1/benchmark/logits" &&
               benchmark_api && !draining) {
      ++requests;
      std::vector<int32_t> prompt;
      double requested_top_k = 32;
      if (!json_integer_array(body, "input_ids", &prompt) ||
          !json_number(body, "top_k", 32, &requested_top_k) ||
          prompt.empty() || requested_top_k < 1 || requested_top_k > 128) {
        ++failures;
        respond(client, 400, "Bad request",
                "{\"error\":\"invalid benchmark request\"}");
      } else {
        const std::string id = "benchmark-" + std::to_string(requests);
        request_release release{&worker, id};
        neurx::inference::batch_2 batch;
        batch.phase = neurx::inference::Phase::prefill;
        batch.key = {neurx::inference::Backend::ascend, precision};
        batch.items = {{id, static_cast<int>(prompt.size())}};
        batch.total_tokens = static_cast<int>(prompt.size());
        neurx::inference::sampling_config_2 sampling;

        sampling.repetition_penalty = 1.000001F;
        neurx::inference::worker_batch_result result;
        const auto status =
            worker.execute(batch, prompt, {sampling}, {prompt}, &result);
        if (!status.ok) {
          ++failures;
          respond(client, 500, "Internal Server Error",
                  "{\"error\":\"" + status.message + "\"}");
        } else {
          respond(client, 200, "OK",
                  top_logits_json(
                      result.logits,
                      static_cast<std::size_t>(requested_top_k)));
        }
      }
    } else if (method == "POST" &&
               path == "/v1/batch-token-completions" && !draining) {
      ++requests;
      std::vector<std::vector<int32_t>> prompts;
      std::vector<int32_t> stop_tokens;
      std::vector<std::vector<int32_t>> generated;
      double max_new = 0, temperature = 1, top_k = 0, top_p = 1;
      double penalty = 1, seed = 0;
      const bool valid =
          json_integer_arrays(body, "input_ids", &prompts) &&
          json_number(body, "max_new_tokens", 16, &max_new) &&
          json_number(body, "temperature", 1, &temperature) &&
          json_number(body, "top_k", 0, &top_k) &&
          json_number(body, "top_p", 1, &top_p) &&
          json_number(body, "repetition_penalty", 1, &penalty) &&
          json_number(body, "seed", 0, &seed);
      if (body.find("\"stop_token_ids\"") != std::string::npos &&
          !json_integer_array(body, "stop_token_ids", &stop_tokens)) {
        ++failures;
        respond(client, 400, "Bad request",
                "{\"error\":\"invalid stop_token_ids\"}");
      } else if (!valid || prompts.size() >
                               static_cast<std::size_t>(http_max_batch) ||
                 max_new < 1 || max_new > 65536 ||
                 top_k < 0 || top_k > std::numeric_limits<int>::max() ||
                 seed < 0) {
        ++failures;
        respond(client, 400, "Bad request",
                "{\"error\":\"invalid batch generation parameters\"}");
      } else {
        neurx::inference::sampling_config_2 sampling;
        sampling.temperature = static_cast<float>(temperature);
        sampling.top_k = static_cast<int>(top_k);
        sampling.top_p = static_cast<float>(top_p);
        sampling.repetition_penalty = static_cast<float>(penalty);
        sampling.seed = static_cast<uint64_t>(seed);
        const std::string id = "ascend-batch-" + std::to_string(requests);
        const auto status = generate_batch(
            worker, id, prompts, static_cast<int>(max_new), sampling,
            stop_tokens, &generated);
        if (!status.ok) {
          ++failures;
          respond(client, 500, "Internal Server Error",
                  "{\"error\":\"" + status.message + "\"}");
        } else {
          std::size_t total = 0;
          for (const auto& row : generated) total += row.size();
          generated_total += total;
          respond(client, 200, "OK", batch_tokens_json(generated));
        }
      }
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
        respond(client, 400, "Bad request",
                "{\"error\":\"invalid stop_token_ids\"}");
      } else if (!valid || max_new < 1 || max_new > 65536 ||
                 top_k < 0 || top_k > std::numeric_limits<int>::max() ||
                 seed < 0) {
        ++failures;
        respond(client, 400, "Bad request",
                "{\"error\":\"invalid generation parameters\"}");
      } else {
        neurx::inference::sampling_config_2 sampling;
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
