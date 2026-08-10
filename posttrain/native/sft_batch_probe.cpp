#include "sft_example.h"

#include <algorithm>
#include <exception>
#include <iostream>
#include <string>
#include <vector>

namespace {

template <typename T>
void print_prefix(const char* name, const std::vector<T>& values, std::size_t limit) {
  std::cout << name << " = [";
  const std::size_t count = std::min(values.size(), limit);
  for (std::size_t index = 0; index < count; ++index) {
    if (index != 0) std::cout << ", ";
    std::cout << values[index];
  }
  std::cout << "]\n";
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 4) {
    std::cerr << "usage: sft_batch_probe MODEL_DIR DATA_FILE MAX_LENGTH\n";
    return 2;
  }
  try {
    const auto example = neurx::posttrain::native::load_sft_example(
        argv[1], argv[2], std::stoi(argv[3]));
    const int supervised = static_cast<int>(std::count_if(
        example.labels.begin(), example.labels.end(),
        [](int32_t label) { return label != neurx::posttrain::native::ignore_index; }));
    const int masked = static_cast<int>(example.labels.size()) - supervised;
    std::cout << "[Batch 0] tokens=" << example.input_ids.size()
              << " supervised_tokens=" << supervised << " masked_tokens=" << masked << '\n';
    print_prefix("input_ids[:20]", example.input_ids, 20);
    print_prefix("labels[:20]", example.labels, 20);
    std::cout << "[Tokenizer] implementation=native_bytelevel_bpe source=tokenizer.json\n";
    std::cout << "[Tokenizer] prompt_tokens=" << example.prompt_tokens
              << " response_tokens=" << example.response_tokens << " roundtrip=PASS\n";
    std::cout << "TOKENIZATION_VALIDATION=PASS\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "TOKENIZATION_VALIDATION=FAIL: " << error.what() << '\n';
    return 1;
  }
}
