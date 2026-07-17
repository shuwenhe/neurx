#include "../cann/inference/logits_sampler.h"

#include <cassert>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <vector>

int main() {
  using neurx::inference::SamplingConfig;

  const float logits[] = {1.0F, 3.0F, 2.0F, -1.0F};
  int32_t token = -1;
  SamplingConfig greedy;
  greedy.temperature = 0.0F;
  assert(neurx::inference::sample_logits(logits, 4, greedy, {}, &token).ok);
  assert(token == 1);

  SamplingConfig top_k;
  top_k.top_k = 1;
  top_k.seed = 7;
  assert(neurx::inference::sample_logits(logits, 4, top_k, {}, &token).ok);
  assert(token == 1);

  SamplingConfig penalty;
  penalty.temperature = 0.0F;
  penalty.repetition_penalty = 4.0F;
  assert(neurx::inference::sample_logits(
             logits, 4, penalty, std::vector<int32_t>{1}, &token)
             .ok);
  assert(token == 2);

  SamplingConfig invalid;
  invalid.top_p = 0.0F;
  assert(!neurx::inference::sample_logits(logits, 4, invalid, {}, &token).ok);

  const float non_finite[] = {
      std::numeric_limits<float>::quiet_NaN(),
      -std::numeric_limits<float>::infinity()};
  assert(!neurx::inference::sample_logits(
              non_finite, 2, top_k, {}, &token)
              .ok);

  std::printf("cann-logits-sampler PASS\n");
  return 0;
}
