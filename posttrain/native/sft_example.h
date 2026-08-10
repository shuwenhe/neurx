#pragma once

#include "../../runtime/model/bpe_tokenizer.h"

#include <algorithm>
#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace neurx::posttrain::native {

constexpr int32_t ignore_index = -100;
constexpr int32_t model_vocab_size = 151936;

struct sft_example {
  std::vector<int32_t> input_ids;
  std::vector<int32_t> labels;
  std::size_t prompt_tokens = 0;
  std::size_t response_tokens = 0;
};

inline std::string first_jsonl_record(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error("cannot open dataset: " + path);
  std::string line;
  while (std::getline(input, line)) {
    if (line.find_first_not_of(" \t\r\n") != std::string::npos) return line;
  }
  throw std::runtime_error("dataset has no records: " + path);
}

inline std::string string_field(const nlohmann::json& record, const char* name) {
  const auto it = record.find(name);
  if (it == record.end() || it->is_null()) return {};
  if (!it->is_string()) throw std::runtime_error(std::string("dataset field is not a string: ") + name);
  return it->get<std::string>();
}

inline std::string prompt_for(const nlohmann::json& record) {
  const std::string question = string_field(record, "question");
  if (question.empty()) throw std::runtime_error("dataset question is empty");
  std::string prompt = "Question: " + question + "\n\nOptions:\n";
  prompt += "A. " + string_field(record, "opa") + "\n";
  prompt += "B. " + string_field(record, "opb") + "\n";
  prompt += "C. " + string_field(record, "opc") + "\n";
  prompt += "D. " + string_field(record, "opd");
  return prompt;
}

inline std::string answer_for(const nlohmann::json& record) {
  const std::vector<std::string> choices = {
      string_field(record, "opa"), string_field(record, "opb"),
      string_field(record, "opc"), string_field(record, "opd")};
  const auto cop = record.find("cop");
  if (cop == record.end() || !cop->is_number_integer()) {
    throw std::runtime_error("dataset record has no integer cop field");
  }
  const int answer_index = cop->get<int>() - 1;
  if (answer_index < 0 || answer_index >= static_cast<int>(choices.size())) {
    throw std::runtime_error("dataset cop must be in [1, 4]");
  }
  std::string answer(1, static_cast<char>('A' + answer_index));
  answer += ". " + choices[static_cast<std::size_t>(answer_index)];
  const std::string explanation = string_field(record, "exp");
  if (!explanation.empty()) answer += "\n\nExplanation: " + explanation;
  return answer;
}

inline sft_example load_sft_example(const std::string& model_dir, const std::string& data_file,
                                    int max_length) {
  if (max_length < 2) throw std::runtime_error("max length must be at least 2");
  const nlohmann::json record = nlohmann::json::parse(first_jsonl_record(data_file));
  const auto tokenizer = runtime::model::bpe_tokenizer::from_directory(model_dir);
  const std::string system =
      "<|im_start|>system\nYou are a helpful assistant. Answer medical questions accurately.\n"
      "<|im_end|>\n";
  const std::string user = "<|im_start|>user\n" + prompt_for(record) + "<|im_end|>\n";
  const std::string assistant_prefix = "<|im_start|>assistant\n";
  const std::string response = answer_for(record) + "<|im_end|>\n";
  const std::string prompt_text = system + user + assistant_prefix;
  const std::string full_text = prompt_text + response;
  const std::vector<int32_t> prompt_ids = tokenizer.encode(prompt_text, true);
  const std::vector<int32_t> response_ids = tokenizer.encode(response, true);
  sft_example example;
  example.prompt_tokens = prompt_ids.size();
  example.response_tokens = response_ids.size();
  example.input_ids = prompt_ids;
  example.input_ids.insert(example.input_ids.end(), response_ids.begin(), response_ids.end());
  if (example.input_ids != tokenizer.encode(full_text, true)) {
    throw std::runtime_error("prompt/response token boundary does not match full encoding");
  }
  if (tokenizer.decode(example.input_ids, false) != full_text) {
    throw std::runtime_error("tokenizer round-trip mismatch");
  }
  example.labels.assign(prompt_ids.size(), ignore_index);
  example.labels.insert(example.labels.end(), response_ids.begin(), response_ids.end());
  if (example.input_ids.size() > static_cast<std::size_t>(max_length)) {
    const std::size_t drop = example.input_ids.size() - static_cast<std::size_t>(max_length);
    example.input_ids.erase(example.input_ids.begin(), example.input_ids.begin() + drop);
    example.labels.erase(example.labels.begin(), example.labels.begin() + drop);
  }
  int supervised = 0;
  int masked = 0;
  for (std::size_t index = 0; index < example.input_ids.size(); ++index) {
    if (example.input_ids[index] < 0 || example.input_ids[index] >= model_vocab_size) {
      throw std::runtime_error("input token id is outside model vocab_size=" + std::to_string(model_vocab_size));
    }
    if (example.labels[index] == ignore_index) {
      ++masked;
    } else {
      if (example.labels[index] != example.input_ids[index]) {
        throw std::runtime_error("supervised label differs from input id");
      }
      ++supervised;
    }
  }
  if (supervised < 2) throw std::runtime_error("batch has fewer than two supervised tokens");
  if (masked == 0) throw std::runtime_error("batch has no masked prompt tokens");
  return example;
}

}  // namespace neurx::posttrain::native
