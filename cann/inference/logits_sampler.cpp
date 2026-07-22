#include "logits_sampler.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <random>
#include <string>

namespace neurx::inference {

bool supports_atb_device_sampling(const SamplingConfig& config,
                                  std::size_t vocabulary) {
  return vocabulary > 0 &&
         vocabulary <=
             static_cast<std::size_t>(std::numeric_limits<int32_t>::max()) &&
         std::isfinite(config.temperature) &&
         (config.temperature == 0.0F || config.temperature == 1.0F) &&
         config.top_k >= 0 &&
         (config.top_k == 0 ||
          static_cast<std::size_t>(config.top_k) <= vocabulary) &&
         std::isfinite(config.top_p) && config.top_p > 0.0F &&
         config.top_p <= 1.0F && config.repetition_penalty == 1.0F &&
         config.seed <= std::numeric_limits<uint32_t>::max();
}

AdapterStatus sample_logits(const float* logits, std::size_t vocabulary,
                            const SamplingConfig& config,
                            const std::vector<int32_t>& token_history,
                            int32_t* token) {
  if (!logits || !token || vocabulary == 0 ||
      vocabulary > static_cast<std::size_t>(
                       std::numeric_limits<int32_t>::max())) {
    return AdapterStatus::failure("sampler received invalid logits");
  }
  if (!std::isfinite(config.temperature) || config.temperature < 0.0F ||
      config.top_k < 0 || !std::isfinite(config.top_p) ||
      config.top_p <= 0.0F || config.top_p > 1.0F ||
      !std::isfinite(config.repetition_penalty) ||
      config.repetition_penalty <= 0.0F) {
    return AdapterStatus::failure("sampling parameters are invalid");
  }

  std::vector<float> scores(logits, logits + vocabulary);
  if (config.repetition_penalty != 1.0F) {
    std::vector<unsigned char> penalized(vocabulary, 0);
    for (const int32_t id : token_history) {
      if (id < 0 || static_cast<std::size_t>(id) >= vocabulary ||
          penalized[static_cast<std::size_t>(id)]) {
        continue;
      }
      penalized[static_cast<std::size_t>(id)] = 1;
      float& score = scores[static_cast<std::size_t>(id)];
      score = score < 0.0F ? score * config.repetition_penalty
                           : score / config.repetition_penalty;
    }
  }

  const auto finite_score = [&](std::size_t index) {
    return std::isfinite(scores[index])
               ? scores[index]
               : -std::numeric_limits<float>::infinity();
  };
  if (config.temperature == 0.0F) {
    std::size_t best = 0;
    for (std::size_t index = 1; index < vocabulary; ++index) {
      if (finite_score(index) > finite_score(best)) best = index;
    }
    *token = static_cast<int32_t>(best);
    return AdapterStatus::success();
  }

  std::vector<std::size_t> candidates(vocabulary);
  std::iota(candidates.begin(), candidates.end(), 0);
  std::sort(candidates.begin(), candidates.end(),
            [&](std::size_t left, std::size_t right) {
              const float a = finite_score(left);
              const float b = finite_score(right);
              return a == b ? left < right : a > b;
            });
  if (config.top_k > 0 &&
      static_cast<std::size_t>(config.top_k) < candidates.size()) {
    candidates.resize(static_cast<std::size_t>(config.top_k));
  }
  if (candidates.empty() || !std::isfinite(finite_score(candidates.front()))) {
    return AdapterStatus::failure("sampler received no finite logits");
  }

  const float maximum = finite_score(candidates.front());
  std::vector<double> weights;
  weights.reserve(candidates.size());
  double total = 0.0;
  for (const std::size_t index : candidates) {
    const double weight = std::exp(
        static_cast<double>((finite_score(index) - maximum) /
                            config.temperature));
    weights.push_back(weight);
    total += weight;
  }
  if (!(total > 0.0) || !std::isfinite(total)) {
    return AdapterStatus::failure("sampler probability normalization failed");
  }

  if (config.top_p < 1.0F) {
    double cumulative = 0.0;
    std::size_t keep = 0;
    do {
      cumulative += weights[keep] / total;
      ++keep;
    } while (keep < weights.size() &&
             cumulative < static_cast<double>(config.top_p));
    candidates.resize(keep);
    weights.resize(keep);
  }

  std::mt19937_64 generator(config.seed);
  std::discrete_distribution<std::size_t> distribution(weights.begin(),
                                                        weights.end());
  *token = static_cast<int32_t>(candidates[distribution(generator)]);
  return AdapterStatus::success();
}

}
