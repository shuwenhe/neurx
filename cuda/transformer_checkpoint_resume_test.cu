#define NEURX_TRANSFORMER_NO_MAIN
#include "neurx_transformer_train_v2.cu"
#include <cstdio>
namespace {
bool train_fixed_steps(model &model, train_cache &cache, int steps, uint64_t &optimizer_step) {
  const int ids[] = {1, 2, 3, 4};
  const int targets[] = {2, 3, 4, 5};
  for (int step = 0; step < steps; ++step) {
    zero_grads(model);
    for (int i = 0; i < model.seq; ++i) {
      cache.ids[i] = ids[i % 4];
      cache.targets[i] = targets[i % 4];
    }
    if (!forward_backward(model, cache)) return false;
    optimizer_step(model, static_cast<int>(++optimizer_step), 2e-4f, 1.0f);
  }
  return true;
}
float max_state_difference(model &a, model &b) {
  float maximum = 0.0f;
  auto left = a.params(), right = b.params();
  if (left.size() != right.size()) return INFINITY;
  for (size_t p = 0; p < left.size(); ++p) {
    if (left[p]->n != right[p]->n) return INFINITY;
    for (int64_t i = 0; i < left[p]->n; ++i) {
      maximum = std::max(maximum, std::abs(left[p]->v[i] - right[p]->v[i]));
      maximum = std::max(maximum, std::abs(left[p]->m[i] - right[p]->m[i]));
      maximum = std::max(maximum, std::abs(left[p]->s[i] - right[p]->s[i]));
    }
  }
  return maximum;
}
}
int main() {
  constexpr int k_total_steps = 6, k_checkpoint_step = 2;
  const std::string directory = "artifacts/build/transformer_cuda/checkpoint_resume";
  std::filesystem::remove_all(directory);
  tokenizer tokenizer;
  model uninterrupted(256, 4, 8, 2, 16, 1);
  train_cache uninterrupted_cache(uninterrupted);
  uint64_t uninterrupted_opt = 0;
  if (!train_fixed_steps(uninterrupted, uninterrupted_cache, k_total_steps, uninterrupted_opt)) return 1;
  model interrupted(256, 4, 8, 2, 16, 1);
  train_cache interrupted_cache(interrupted);
  uint64_t interrupted_opt = 0;
  if (!train_fixed_steps(interrupted, interrupted_cache, k_checkpoint_step, interrupted_opt)) return 1;
  jsonl_stream save_reader;
  save_reader.tok = &tokenizer;
  if (!save_v2(interrupted, tokenizer, save_reader, directory, k_checkpoint_step,
               interrupted_opt, 0, 1, 1, 4 * k_checkpoint_step)) return 1;
  model resumed(256, 4, 8, 2, 16, 1);
  train_cache resumed_cache(resumed);
  jsonl_stream restored_reader;
  restored_reader.tok = &tokenizer;
  uint64_t restored_step = 0, restored_opt = 0, restored_micro = 0, restored_tokens = 0;
  const std::string checkpoint = directory + "/transformer_v2.ckpt";
  if (!load_v2(resumed, tokenizer, restored_reader, checkpoint, restored_step, restored_opt,
               restored_micro, restored_tokens, 1, 1)) return 1;
  if (restored_step != k_checkpoint_step || restored_opt != k_checkpoint_step ||
      restored_micro != 0 || restored_tokens != 4 * k_checkpoint_step) return 1;
  if (!train_fixed_steps(resumed, resumed_cache, k_total_steps - int(restored_step), restored_opt)) return 1;
  const float max_difference = max_state_difference(uninterrupted, resumed);
  const bool exact = max_difference == 0.0f && restored_opt == k_total_steps;
  std::printf("transformer-checkpoint-resume %s restored_step=%llu optimizer_step=%llu max_state_difference=%.9g\n",
              exact ? "PASS" : "FAIL", static_cast<unsigned long long>(restored_step),
              static_cast<unsigned long long>(restored_opt), max_difference);
  std::filesystem::remove_all(directory);
  if (blas) cublas_destroy(blas);
  return exact ? 0 : 1;
}
