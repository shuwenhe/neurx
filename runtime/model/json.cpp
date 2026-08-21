#include "json.h"

#include <cmath>
#include <fstream>
#include <limits>
#include <sstream>
#include <stdexcept>

#include <nlohmann/json.hpp>

namespace neurx::runtime::model {
namespace {

json convert_json(const nlohmann::json& value) {
  if (value.is_null()) {
    return json();
  }
  if (value.is_boolean()) {
    return json(value.get<bool>());
  }
  if (value.is_number()) {
    return json(value.get<double>());
  }
  if (value.is_string()) {
    return json(value.get<std::string>());
  }
  if (value.is_array()) {
    json::array out;
    out.reserve(value.size());
    for (const auto& item : value) {
      out.push_back(convert_json(item));
    }
    return json(std::move(out));
  }
  json::object out;
  for (auto it = value.begin(); it != value.end(); ++it) {
    out.emplace(it.key(), convert_json(it.value()));
  }
  return json(std::move(out));
}

}  // namespace

json json::parse(const std::string& text) {
  try {
    return convert_json(nlohmann::json::parse(text));
  } catch (const nlohmann::json::exception& error) {
    throw std::runtime_error(std::string("JSON parse error: ") + error.what());
  }
}

json json::parse_file(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    throw std::runtime_error("cannot open JSON file: " + path);
  }
  std::ostringstream buffer;
  buffer << input.rdbuf();
  if (!input.good() && !input.eof()) {
    throw std::runtime_error("cannot read JSON file: " + path);
  }
  return parse(buffer.str());
}

bool json::is_null() const { return std::holds_alternative<std::monostate>(value_); }
bool json::is_bool() const { return std::holds_alternative<bool>(value_); }
bool json::is_number() const { return std::holds_alternative<double>(value_); }
bool json::is_string() const { return std::holds_alternative<std::string>(value_); }
bool json::is_array() const { return std::holds_alternative<array>(value_); }
bool json::is_object() const { return std::holds_alternative<object>(value_); }

bool json::as_bool() const {
  if (!is_bool()) throw std::runtime_error("JSON value is not a boolean");
  return std::get<bool>(value_);
}

double json::as_number() const {
  if (!is_number()) throw std::runtime_error("JSON value is not a number");
  return std::get<double>(value_);
}

int64_t json::as_int() const {
  const double value = as_number();
  if (!std::isfinite(value) || std::trunc(value) != value ||
      value < static_cast<double>(std::numeric_limits<int64_t>::min()) ||
      value > static_cast<double>(std::numeric_limits<int64_t>::max())) {
    throw std::runtime_error("JSON number is not an int64");
  }
  return static_cast<int64_t>(value);
}

const std::string& json::as_string() const {
  if (!is_string()) throw std::runtime_error("JSON value is not a string");
  return std::get<std::string>(value_);
}

const json::array& json::as_array() const {
  if (!is_array()) throw std::runtime_error("JSON value is not an array");
  return std::get<array>(value_);
}

const json::object& json::as_object() const {
  if (!is_object()) throw std::runtime_error("JSON value is not an object");
  return std::get<object>(value_);
}

bool json::contains(const std::string& key) const {
  if (!is_object()) return false;
  return std::get<object>(value_).find(key) != std::get<object>(value_).end();
}

const json& json::at(const std::string& key) const {
  const auto& object_value = as_object();
  const auto it = object_value.find(key);
  if (it == object_value.end()) {
    throw std::runtime_error("missing JSON field: " + key);
  }
  return it->second;
}

}  // namespace neurx::runtime::model
