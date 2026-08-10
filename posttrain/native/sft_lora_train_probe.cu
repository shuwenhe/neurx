#include "sft_example.h"
#include "../../cuda/hf_decoder_cuda.h"
#include "../../runtime/model/safetensors.h"

#include <cuda_runtime.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>
#include <system_error>
#include <vector>

namespace {

using neurx::cuda::lora_tensor_snapshot;
using neurx::cuda::lora_training_report;
using neurx::runtime::model::safe_tensor_file;

std::size_t element_count(const std::vector<int64_t>& shape) {
  std::size_t result = 1;
  for (const int64_t dimension : shape) {
    if (dimension < 0 || (dimension != 0 && result >
        std::numeric_limits<std::size_t>::max() / static_cast<std::size_t>(dimension))) {
      throw std::runtime_error("invalid adapter tensor shape");
    }
    result *= static_cast<std::size_t>(dimension);
  }
  return result;
}

std::string shape_json(const std::vector<int64_t>& shape) {
  std::string result = "[";
  for (std::size_t index = 0; index < shape.size(); ++index) {
    if (index) result += ",";
    result += std::to_string(shape[index]);
  }
  result += "]";
  return result;
}

void write_safetensors(const std::filesystem::path& path,
                       const std::vector<lora_tensor_snapshot>& tensors) {
  const uint16_t endian_probe = 1;
  if (*reinterpret_cast<const uint8_t*>(&endian_probe) != 1) {
    throw std::runtime_error("safetensors writer requires a little-endian host");
  }
  uint64_t offset = 0;
  std::string header = "{\"__metadata__\":{\"format\":\"pt\"}";
  for (const auto& tensor : tensors) {
    if (tensor.name.find_first_not_of(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._") !=
        std::string::npos) {
      throw std::runtime_error("adapter tensor name contains unsupported characters");
    }
    const std::size_t expected = element_count(tensor.shape);
    if (expected != tensor.values.size()) {
      throw std::runtime_error("adapter tensor value count does not match shape: " + tensor.name);
    }
    for (float value : tensor.values) {
      if (!std::isfinite(value)) {
        throw std::runtime_error("adapter tensor contains NaN or infinity: " + tensor.name);
      }
    }
    const uint64_t bytes = static_cast<uint64_t>(tensor.values.size()) * sizeof(float);
    header += ",\"" + tensor.name + "\":{\"dtype\":\"F32\",\"shape\":" +
              shape_json(tensor.shape) + ",\"data_offsets\":[" +
              std::to_string(offset) + "," + std::to_string(offset + bytes) + "]}";
    offset += bytes;
  }
  header += "}";
  while (header.size() % 8 != 0) header.push_back(' ');

  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) throw std::runtime_error("cannot create temporary adapter checkpoint");
  const uint64_t header_size = header.size();
  uint8_t length[8];
  for (int index = 0; index < 8; ++index) {
    length[index] = static_cast<uint8_t>((header_size >> (index * 8)) & 0xffU);
  }
  output.write(reinterpret_cast<const char*>(length), sizeof(length));
  output.write(header.data(), static_cast<std::streamsize>(header.size()));
  for (const auto& tensor : tensors) {
    output.write(reinterpret_cast<const char*>(tensor.values.data()),
                 static_cast<std::streamsize>(tensor.values.size() * sizeof(float)));
  }
  output.close();
  if (!output) throw std::runtime_error("failed while writing adapter checkpoint");
}

void verify_checkpoint(const std::filesystem::path& path,
                       const lora_training_report& report) {
  const safe_tensor_file checkpoint = safe_tensor_file::open(path.string());
  if (checkpoint.tensors().size() != report.tensors.size()) {
    throw std::runtime_error("reloaded adapter tensor count mismatch");
  }
  for (const auto& expected : report.tensors) {
    const auto found = checkpoint.tensors().find(expected.name);
    if (found == checkpoint.tensors().end()) {
      throw std::runtime_error("reloaded adapter is missing tensor: " + expected.name);
    }
    if (found->second.shape != expected.shape) {
      throw std::runtime_error("reloaded adapter tensor shape mismatch: " + expected.name);
    }
    auto loaded = checkpoint.load(expected.name);
    std::vector<float> values(expected.values.size());
    loaded.copy_to_host(values.data(), values.size() * sizeof(float));
    for (std::size_t index = 0; index < values.size(); ++index) {
      if (!std::isfinite(values[index]) || values[index] != expected.values[index]) {
        throw std::runtime_error("reloaded adapter tensor value mismatch: " + expected.name);
      }
    }
  }
  const std::string a_name = report.measured_tensor + ".lora_A.weight";
  const std::string b_name = report.measured_tensor + ".lora_B.weight";
  std::vector<float> a_values(element_count(checkpoint.tensors().at(a_name).shape));
  std::vector<float> b_values(element_count(checkpoint.tensors().at(b_name).shape));
  checkpoint.load(a_name).copy_to_host(a_values.data(), a_values.size() * sizeof(float));
  checkpoint.load(b_name).copy_to_host(b_values.data(), b_values.size() * sizeof(float));
  if (a_values.at(report.a_changed_index) != report.a_after ||
      b_values.at(report.b_changed_index) != report.b_after ||
      report.a_before == report.a_after || report.b_before == report.b_after) {
    throw std::runtime_error("reloaded measured LoRA values do not prove an optimizer update");
  }
}

void write_adapter_config(const std::filesystem::path& path,
                          const std::string& model_path, int rank, float alpha) {
  nlohmann::json config = {
      {"base_model_name_or_path", model_path},
      {"bias", "none"},
      {"inference_mode", false},
      {"lora_alpha", alpha},
      {"lora_dropout", 0.0},
      {"peft_type", "LORA"},
      {"r", rank},
      {"target_modules", {"q_proj", "k_proj", "v_proj", "o_proj"}},
      {"task_type", "CAUSAL_LM"}};
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) throw std::runtime_error("cannot create temporary adapter config");
  output << config.dump(2) << '\n';
  output.close();
  if (!output) throw std::runtime_error("failed while writing adapter config");
}

void publish_file(const std::filesystem::path& temporary,
                  const std::filesystem::path& destination) {
  std::error_code error;
  std::filesystem::rename(temporary, destination, error);
  if (error) {
    throw std::runtime_error("cannot publish " + destination.string() + ": " + error.message());
  }
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 8) {
    std::fprintf(stderr,
                 "usage: sft_lora_train_probe MODEL_DIR DATA_FILE MAX_LENGTH OUTPUT_DIR "
                 "RANK ALPHA LEARNING_RATE\n");
    return 2;
  }
  int devices = 0;
  if (cudaGetDeviceCount(&devices) != cudaSuccess || devices == 0) {
    std::fprintf(stderr, "LORA_BACKWARD_VALIDATION=FAIL: no CUDA device\n");
    return 1;
  }
  try {
    const int rank = std::stoi(argv[5]);
    const float alpha = std::stof(argv[6]);
    const float learning_rate = std::stof(argv[7]);
    const auto example = neurx::posttrain::native::load_sft_example(
        argv[1], argv[2], std::stoi(argv[3]));
    neurx::cuda::hf_decoder_cuda model(argv[1]);
    const lora_training_report report = model.train_lora_two_steps(
        example.input_ids, example.labels, rank, alpha, learning_rate);
    if (report.module_count != 96 || report.parameter_count != 1081344 ||
        report.tensors.size() != report.module_count * 2) {
      throw std::runtime_error("LoRA module, parameter, or tensor count is inconsistent");
    }

    const std::filesystem::path adapter_dir = std::filesystem::path(argv[4]) / "adapter";
    std::filesystem::create_directories(adapter_dir);
    const auto temporary_checkpoint = adapter_dir / "adapter_model.safetensors.validation.tmp";
    const auto final_checkpoint = adapter_dir / "adapter_model.safetensors";
    const auto temporary_config = adapter_dir / "adapter_config.json.validation.tmp";
    const auto final_config = adapter_dir / "adapter_config.json";
    write_safetensors(temporary_checkpoint, report.tensors);
    verify_checkpoint(temporary_checkpoint, report);
    write_adapter_config(temporary_config, argv[1], rank, alpha);
    publish_file(temporary_config, final_config);
    publish_file(temporary_checkpoint, final_checkpoint);
    verify_checkpoint(final_checkpoint, report);

    const auto& first = report.tensors.at(0);
    const auto& second = report.tensors.at(1);
    const std::uintmax_t checkpoint_bytes = std::filesystem::file_size(final_checkpoint);
    std::printf("[Training] validation_steps=2 batches=1 initial_loss=%.6f final_loss=%.6f\n",
                report.initial_loss, report.final_loss);
    std::printf("[Backward] modules=%zu parameters=%zu\n",
                report.module_count, report.parameter_count);
    std::printf("[Backward] %s.lora_A.weight grad_norm=%.9g (all_A=%.9g)\n",
                report.measured_tensor.c_str(), report.measured_a_grad_norm,
                report.lora_a_grad_norm);
    std::printf("[Backward] %s.lora_B.weight grad_norm=%.9g (all_B=%.9g)\n",
                report.measured_tensor.c_str(), report.measured_b_grad_norm,
                report.lora_b_grad_norm);
    std::printf("[Update] %s.lora_A.weight[%zu]: %.9g -> %.9g\n",
                report.measured_tensor.c_str(), report.a_changed_index,
                report.a_before, report.a_after);
    std::printf("[Update] %s.lora_B.weight[%zu]: %.9g -> %.9g\n",
                report.measured_tensor.c_str(), report.b_changed_index,
                report.b_before, report.b_after);
    std::printf("[Checkpoint] tensor[0]=%s shape=%s\n",
                first.name.c_str(), shape_json(first.shape).c_str());
    std::printf("[Checkpoint] tensor[1]=%s shape=%s\n",
                second.name.c_str(), shape_json(second.shape).c_str());
    std::printf("[Checkpoint] tensors=%zu parameters=%zu bytes=%ju reload=PASS\n",
                report.tensors.size(), report.parameter_count, checkpoint_bytes);
    std::printf("LORA_BACKWARD_VALIDATION=PASS\n");
    std::printf("LORA_UPDATE_VALIDATION=PASS\n");
    std::printf("CHECKPOINT_VALIDATION=PASS\n");
    return 0;
  } catch (const std::exception& error) {
    std::fprintf(stderr, "LORA_BACKWARD_VALIDATION=FAIL: %s\n", error.what());
    return 1;
  }
}
