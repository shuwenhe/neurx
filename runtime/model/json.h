#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <variant>
#include <vector>
namespace neurx::runtime::model {
class json {
 public:
  using array = std::vector<json>;
  using object = std::map<std::string, json>;
  json() = default;
  explicit json(bool value) : value_(value) {}
  explicit json(double value) : value_(value) {}
  explicit json(std::string value) : value_(std::move(value)) {}
  explicit json(array value) : value_(std::move(value)) {}
  explicit json(object value) : value_(std::move(value)) {}
  static json parse(const std::string& text);
  static json parse_file(const std::string& path);
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
  const array& as_array() const;
  const object& as_object() const;
  bool contains(const std::string& key) const;
  const json& at(const std::string& key) const;
 private:
  using value = std::variant<std::monostate, bool, double, std::string, array, object>;
  value value_;
};
}
