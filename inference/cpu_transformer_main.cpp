#include "cpu_transformer_inference.h"

#include <cstdlib>
#include <exception>
#include <iostream>
#include <string>

namespace {

std::string environment(const char* name, const std::string& fallback = {}) {
  const char* value = std::getenv(name);
  return value && *value ? value : fallback;
}

int integer_environment(const char* name, int fallback) {
  const std::string value = environment(name);
  return value.empty() ? fallback : std::stoi(value);
}

float float_environment(const char* name, float fallback) {
  const std::string value = environment(name);
  return value.empty() ? fallback : std::stof(value);
}

void usage(const char* program) {
  std::cerr
      << "Usage: " << program
      << " --checkpoint PATH [--vocab PATH --merges PATH] [--prompt TEXT]\n"
      << "Options: --max-new-tokens N --temperature F --top-k N --top-p F\n"
      << "         --repetition-penalty F --seed N --interactive --info\n";
}

}  // namespace

int main(int argc, char** argv) {
  std::string checkpoint =
      environment("NEURX_INFER_CHECKPOINT_PATH",
                  environment("NEURX_INFER_CHECKPOINT",
                              "checkpoint/NeurX-1.3/transformer_v2.ckpt"));
  std::string vocabulary =
      environment("NEURX_TOKENIZER_VOCAB", "data/corpus/vocab.json");
  std::string merges =
      environment("NEURX_TOKENIZER_MERGES", "data/corpus/merges.txt");
  std::string prompt =
      environment("NEURX_INFER_QUESTION",
                  environment("NEURX_INFER_PROMPT", "NeurX can"));
  neurx::inference::cpu::GenerationConfig config;
  config.max_new_tokens = integer_environment("NEURX_INFER_MAX_NEW_TOKENS", 64);
  config.temperature = float_environment("NEURX_INFER_TEMPERATURE", 0.0F);
  config.top_k = integer_environment("NEURX_INFER_TOP_K", 0);
  config.top_p = float_environment("NEURX_INFER_TOP_P", 1.0F);
  config.repetition_penalty =
      float_environment("NEURX_INFER_REPETITION_PENALTY", 1.0F);
  config.seed = static_cast<uint64_t>(
      integer_environment("NEURX_INFER_SEED", 1337));
  bool interactive = false;
  bool info_only = false;

  try {
    for (int index = 1; index < argc; ++index) {
      const std::string argument = argv[index];
      const auto next = [&]() -> std::string {
        if (index + 1 >= argc) throw std::invalid_argument("missing value for " + argument);
        return argv[++index];
      };
      if (argument == "--checkpoint") checkpoint = next();
      else if (argument == "--vocab") vocabulary = next();
      else if (argument == "--merges") merges = next();
      else if (argument == "--prompt") prompt = next();
      else if (argument == "--max-new-tokens") config.max_new_tokens = std::stoi(next());
      else if (argument == "--temperature") config.temperature = std::stof(next());
      else if (argument == "--top-k") config.top_k = std::stoi(next());
      else if (argument == "--top-p") config.top_p = std::stof(next());
      else if (argument == "--repetition-penalty") config.repetition_penalty = std::stof(next());
      else if (argument == "--seed") config.seed = std::stoull(next());
      else if (argument == "--interactive") interactive = true;
      else if (argument == "--info") info_only = true;
      else if (argument == "--help" || argument == "-h") {
        usage(argv[0]);
        return 0;
      } else {
        throw std::invalid_argument("unknown argument: " + argument);
      }
    }

    neurx::inference::cpu::Transformer model;
    std::string error;
    if (!model.load(checkpoint, vocabulary, merges, &error)) {
      std::cerr << "inference error: " << error << '\n';
      return 2;
    }
    const auto& info = model.info();
    std::cerr << "NeurX NXTRFMV2 CPU inference ready"
              << " (step=" << info.step << ", layers=" << info.layers
              << ", hidden=" << info.hidden_size
              << ", context=" << info.context_length << ")\n";
    if (info_only) return 0;

    if (!interactive) {
      std::cout << model.generate(prompt, config) << '\n';
      return 0;
    }
    std::string line;
    while (true) {
      std::cout << "You: " << std::flush;
      if (!std::getline(std::cin, line) || line == "quit" || line == "exit" ||
          line == "bye" || line == "退出") {
        break;
      }
      if (line.empty()) continue;
      std::cout << "NeurX: "
                << model.generate("User: " + line + "\nAssistant:", config)
                << "\n\n";
    }
    return 0;
  } catch (const std::exception& exception) {
    std::cerr << "inference error: " << exception.what() << '\n';
    usage(argv[0]);
    return 2;
  }
}
