#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>
namespace neurx_training {
enum class lr_schedule {
    constant,
    linear,
    cosine,
};
inline bool parse_lr_schedule(const std::string& name, lr_schedule& schedule) {
    if (name == "constant") {
        schedule = lr_schedule::constant;
        return true;
    }
    if (name == "linear") {
        schedule = lr_schedule::linear;
        return true;
    }
    if (name == "cosine") {
        schedule = lr_schedule::cosine;
        return true;
    }
    return false;
}
inline const char* lr_schedule_name(lr_schedule schedule) {
    switch (schedule) {
        case lr_schedule::constant:
            return "constant";
        case lr_schedule::linear:
            return "linear";
        case lr_schedule::cosine:
            return "cosine";
    }
    return "unknown";
}
struct lr_config {
    double peak_lr = 2e-4;
    double min_lr = 2e-5;
    std::uint64_t warmup_steps = 0;
    std::uint64_t total_steps = 1;
    lr_schedule schedule = lr_schedule::cosine;
};
inline double learning_rate(const lr_config& config,
                            std::uint64_t optimizer_step) {
    if (!(config.peak_lr >= 0.0) || !(config.min_lr >= 0.0) ||
        config.min_lr > config.peak_lr || config.total_steps == 0) {
        return 0.0;
    }
    if (config.warmup_steps > 0 &&
        optimizer_step <= config.warmup_steps) {
        return config.peak_lr *
               (static_cast<double>(optimizer_step) /
                static_cast<double>(config.warmup_steps));
    }
    if (config.schedule == lr_schedule::constant ||
        config.total_steps <= config.warmup_steps) {
        return config.peak_lr;
    }
    const std::uint64_t bounded_step =
        std::min(optimizer_step, config.total_steps);
    const double progress =
        static_cast<double>(bounded_step - config.warmup_steps) /
        static_cast<double>(config.total_steps - config.warmup_steps);
    double multiplier = 1.0;
    if (config.schedule == lr_schedule::linear) {
        multiplier = 1.0 - progress;
    } else if (config.schedule == lr_schedule::cosine) {
        constexpr double pi = 3.14159265358979323846;
        multiplier = 0.5 * (1.0 + std::cos(pi * progress));
    }
    return config.min_lr +
           (config.peak_lr - config.min_lr) * multiplier;
}
struct gradient_policy {
    double max_norm = 1.0;
    double epsilon = 1e-6;
};
struct gradient_decision {
    bool finite = false;
    bool clipped = false;
    double norm = 0.0;
    double scale = 0.0;
};
inline gradient_decision compute_gradient_decision(double squared_norm,
                                                   const gradient_policy& policy) {
    struct gradient_decision result;
    if (!std::isfinite(squared_norm) || squared_norm < 0.0 ||
        !std::isfinite(policy.max_norm) || policy.max_norm < 0.0) {
        return result;
    }
    result.norm = std::sqrt(squared_norm);
    result.finite = std::isfinite(result.norm);
    if (!result.finite) {
        result.scale = 0.0;
        return result;
    }
    if (policy.max_norm == 0.0 || result.norm <= policy.max_norm) {
        result.scale = 1.0;
        return result;
    }
    result.scale = policy.max_norm / (result.norm + policy.epsilon);
    result.clipped = true;
    return result;
}
}
