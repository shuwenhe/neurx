#include "../runtime/model/bpe_tokenizer.h"

#include <cstdio>
#include <exception>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "usage: tokenizer_parity_probe MODEL_DIR [TEXT]\n";
    return 2;
  }
  std::string text;
  if (argc >= 3) {
    text = argv[2];
    for (int i = 3; i < argc; ++i) text += " " + std::string(argv[i]);
  } else {
    text = "Hello, world!";
  }
  try {
    const auto tokenizer = neurx::runtime::model::bpe_tokenizer::from_directory(argv[1]);
    const auto ids = tokenizer.encode(text, true);
    std::cout << "ids";
    for (const auto id : ids) std::cout << ' ' << id;
    std::cout << "\nhex ";
    const std::string decoded = tokenizer.decode(ids, false);
    for (const unsigned char byte : decoded) {
      std::cout << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(byte);
    }
    std::cout << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
