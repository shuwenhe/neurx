#include "../inference/cpu_transformer_inference.h"

#include <cassert>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

#pragma pack(push, 1)
struct HeaderV2 {
  char magic[8];
  uint32_t version, header_bytes;
  uint64_t step, optimizer_step, micro_step, shard, line, docs, tokens;
  uint32_t vocab, seq, dim, heads, ffn, layers, micro_batch, grad_accum;
  uint32_t tokenizer_kind, vocab_path_bytes, merges_path_bytes;
  uint64_t tokenizer_hash, pending_count, param_count;
};
#pragma pack(pop)

void write_parameter(std::ofstream& output, const std::vector<float>& values) {
  const uint64_t count = values.size();
  output.write(reinterpret_cast<const char*>(&count), sizeof(count));
  output.write(reinterpret_cast<const char*>(values.data()),
               static_cast<std::streamsize>(values.size() * sizeof(float)));
  std::vector<float> optimizer(values.size() * 3, 0.0F);
  output.write(reinterpret_cast<const char*>(optimizer.data()),
               static_cast<std::streamsize>(optimizer.size() * sizeof(float)));
}

std::string write_fixture() {
  const std::filesystem::path path =
      std::filesystem::temp_directory_path() / "neurx_cpu_inference_test.ckpt";
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  HeaderV2 header{};
  std::memcpy(header.magic, "NXTRFMV2", 8);
  header.version = 2;
  header.header_bytes = sizeof(header);
  header.step = 42;
  header.vocab = 256;
  header.seq = 16;
  header.dim = 4;
  header.heads = 2;
  header.ffn = 8;
  header.layers = 1;
  header.micro_batch = 1;
  header.grad_accum = 1;
  header.param_count = 11;
  output.write(reinterpret_cast<const char*>(&header), sizeof(header));

  write_parameter(output, std::vector<float>(256 * 4, 1.0F));
  write_parameter(output, std::vector<float>(4, 1.0F));
  for (int index = 0; index < 4; ++index) {
    write_parameter(output, std::vector<float>(4 * 4, 0.0F));
  }
  write_parameter(output, std::vector<float>(4, 1.0F));
  write_parameter(output, std::vector<float>(4 * 8, 0.0F));
  write_parameter(output, std::vector<float>(4 * 8, 0.0F));
  write_parameter(output, std::vector<float>(8 * 4, 0.0F));
  std::vector<float> lm_head(4 * 256, 0.0F);
  for (int dimension = 0; dimension < 4; ++dimension) {
    lm_head[static_cast<std::size_t>(dimension) * 256 + 'A'] = 1.0F;
  }
  write_parameter(output, lm_head);
  output.close();
  assert(output);
  return path.string();
}

}

int main() {
  const std::string checkpoint = write_fixture();
  neurx::inference::cpu::Transformer model;
  std::string error;
  assert(model.load(checkpoint, "", "", &error));
  assert(error.empty());
  assert(model.info().step == 42);
  assert(model.info().layers == 1);
  assert(model.encode("x") == std::vector<int>{'x'});

  neurx::inference::cpu::GenerationConfig config;
  config.max_new_tokens = 3;
  const std::vector<int> generated = model.generate_ids({'x'}, config);
  assert((generated == std::vector<int>{'A', 'A', 'A'}));
  assert(model.decode(generated) == "AAA");
  assert(model.generate("x", config) == "AAA");

  std::filesystem::remove(checkpoint);
  std::cout << "cpu-transformer-inference PASS generated=AAA\n";
  return 0;
}
