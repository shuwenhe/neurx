#include "../cuda/training_policy.h"
#include "../cuda/token_stream.h"

#include <cmath>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>

namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

void require_close(double actual, double expected, double tolerance,
                   const std::string& message) {
    require(std::abs(actual - expected) <= tolerance,
            message + " actual=" + std::to_string(actual) +
                " expected=" + std::to_string(expected));
}

std::string read_file(const std::string& path) {
    std::ifstream input(path);
    require(input.good(), "cannot read " + path);
    std::ostringstream contents;
    contents << input.rdbuf();
    return contents.str();
}

void test_schedule_parsing() {
    neurx_training::LrSchedule schedule;
    require(neurx_training::parse_lr_schedule("constant", schedule),
            "constant schedule parses");
    require(schedule == neurx_training::LrSchedule::Constant,
            "constant schedule value");
    require(neurx_training::parse_lr_schedule("linear", schedule),
            "linear schedule parses");
    require(neurx_training::parse_lr_schedule("cosine", schedule),
            "cosine schedule parses");
    require(!neurx_training::parse_lr_schedule("mystery", schedule),
            "unknown schedule is rejected");
}

void test_warmup_and_cosine_decay() {
    neurx_training::LrConfig config;
    config.peak_lr = 1.0;
    config.min_lr = 0.1;
    config.warmup_steps = 10;
    config.total_steps = 100;
    config.schedule = neurx_training::LrSchedule::Cosine;

    require_close(neurx_training::learning_rate(config, 1), 0.1, 1e-12,
                  "warmup begins at one tenth");
    require_close(neurx_training::learning_rate(config, 5), 0.5, 1e-12,
                  "warmup midpoint");
    require_close(neurx_training::learning_rate(config, 10), 1.0, 1e-12,
                  "warmup reaches peak");
    require_close(neurx_training::learning_rate(config, 55), 0.55, 1e-12,
                  "cosine midpoint");
    require_close(neurx_training::learning_rate(config, 100), 0.1, 1e-12,
                  "cosine reaches minimum");
    require_close(neurx_training::learning_rate(config, 1000), 0.1, 1e-12,
                  "cosine clamps after training");
}

void test_linear_and_constant_decay() {
    neurx_training::LrConfig config;
    config.peak_lr = 2.0;
    config.min_lr = 0.0;
    config.total_steps = 10;
    config.schedule = neurx_training::LrSchedule::Linear;
    require_close(neurx_training::learning_rate(config, 5), 1.0, 1e-12,
                  "linear midpoint");
    require_close(neurx_training::learning_rate(config, 10), 0.0, 1e-12,
                  "linear endpoint");

    config.schedule = neurx_training::LrSchedule::Constant;
    require_close(neurx_training::learning_rate(config, 10), 2.0, 1e-12,
                  "constant schedule");
}

void test_gradient_policy() {
    neurx_training::GradientPolicy policy;
    policy.max_norm = 1.0;
    policy.epsilon = 1e-6;

    const auto unchanged = neurx_training::gradient_decision(0.25, policy);
    require(unchanged.finite, "finite small gradient");
    require(!unchanged.clipped, "small gradient is not clipped");
    require_close(unchanged.norm, 0.5, 1e-12, "small gradient norm");
    require_close(unchanged.scale, 1.0, 1e-12, "small gradient scale");

    const auto clipped = neurx_training::gradient_decision(4.0, policy);
    require(clipped.finite, "finite large gradient");
    require(clipped.clipped, "large gradient is clipped");
    require_close(clipped.norm, 2.0, 1e-12, "large gradient norm");
    require(clipped.scale < 0.5 && clipped.scale > 0.499999,
            "large gradient clipping scale");

    const auto invalid = neurx_training::gradient_decision(
        std::numeric_limits<double>::quiet_NaN(), policy);
    require(!invalid.finite, "NaN gradient is rejected");
    require_close(invalid.scale, 0.0, 0.0, "NaN gradient has zero scale");
}

void test_cuda_trainer_wiring() {
    const std::string trainer =
        read_file("cuda/neurx_transformer_train_v2.cu");
    const std::string makefile = read_file("Makefile");
    require(trainer.find("neurx_training::learning_rate") !=
                std::string::npos,
            "CUDA trainer uses tested learning-rate policy");
    require(trainer.find("neurx_training::gradient_decision") !=
                std::string::npos,
            "CUDA trainer uses tested gradient policy");
    require(trainer.find("run_manifest.json") != std::string::npos,
            "CUDA trainer emits run manifest");
    require(trainer.find("NEURX_FAIL_ON_NONFINITE") != std::string::npos,
            "CUDA trainer has non-finite failure policy");
    require(trainer.find("NEURX_PRETRAIN_VALIDATION_SHARD_LIST_FILE") !=
                std::string::npos,
            "CUDA trainer accepts a held-out validation shard list");
    require(trainer.find("std::exp(std::min(80.0,val_loss))") !=
                std::string::npos,
            "CUDA trainer reports true perplexity from validation NLL");
    require(trainer.find("out+\"/best\"") != std::string::npos,
            "CUDA trainer persists the best validation checkpoint");
    require(trainer.find("NXHASH01") != std::string::npos &&
                trainer.find("checkpoint checksum mismatch") !=
                    std::string::npos,
            "CUDA checkpoint save and restore include corruption detection");
    require(trainer.find("p->apply_weight_decay?weight_decay:0.0f") !=
                std::string::npos,
            "normalization parameters are excluded from weight decay");
    require(makefile.find("rank_checkpoint_dir=\"$${NEURX_PRETRAIN_OUTPUT_DIR}\"") !=
                std::string::npos,
            "single-rank launcher resumes from the unsharded checkpoint path");
    require(makefile.find("rank_checkpoint_dir=\"$${NEURX_PRETRAIN_OUTPUT_DIR}/rank_$${rank}\"") !=
                std::string::npos,
            "multi-rank launcher resumes each rank from its own checkpoint");
}

void test_document_packing_preserves_tails() {
    std::vector<int> pending;
    neurx_training::append_document_tokens(pending, {10, 11});
    neurx_training::append_document_tokens(pending, {20, 21, 22});
    require(pending == std::vector<int>({10, 11, 20, 21, 22}),
            "short document tail is retained when next document arrives");

    std::vector<int> window(4);
    require(neurx_training::take_training_window(pending, 3, window),
            "packed training window is available");
    require(window == std::vector<int>({10, 11, 20, 21}),
            "window spans document boundary without dropping tokens");
    require(pending == std::vector<int>({21, 22}),
            "last target is retained as next input");

    neurx_training::append_document_tokens(pending, {30, 31});
    require(neurx_training::take_training_window(pending, 3, window),
            "second packed training window is available");
    require(window == std::vector<int>({21, 22, 30, 31}),
            "second window continues exactly from retained target");
}

}

int main() {
    test_schedule_parsing();
    test_warmup_and_cosine_decay();
    test_linear_and_constant_decay();
    test_gradient_policy();
    test_document_packing_preserves_tails();
    test_cuda_trainer_wiring();
    std::cout << "Training policy regression tests passed\n";
    return 0;
}
