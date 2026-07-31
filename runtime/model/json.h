#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <variant>
#include <vector>
namespace neurx::runtime::model {
class Json {
 public:
  using Array = std::vector<Json>;
  using Object = std::map<std::string, Json>;
  Json() = default;
  explicit Json(bool value) : value_(value) {}
  explicit Json(double value) : value_(value) {}
  explicit Json(std::string value) : value_(std::move(value)) {}
  explicit Json(Array value) : value_(std::move(value)) {}
  explicit Json(Object value) : value_(std::move(value)) {}
  static Json parse(const std::string& text);
  static Json parse_file(const std::string& path);
  bool is_null() const;
  bool is_bool() const;
  bool is_number() const;
  bool is_string() const;
  bool is_array() const;
  bool is_object() const;
  bool as_bool() const;
  double as_number() const;
  int64_t as_int() const;
  const std::string& as_string() const;
  const Array& as_array() const;
  const Object& as_object() const;
  bool contains(const std::string& key) const;
  const Json& at(const std::string& key) const;
 private:
  using Value = std::variant<std::monostate, bool, double, std::string, Array, Object>;
  Value value_;
};
}
