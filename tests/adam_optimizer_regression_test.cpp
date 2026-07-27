#include <cmath>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

struct adam_state_2 {
    std::vector<double> m;
    std::vector<double> v;
    int step = 0;
    double beta1_pow = 1.0;
    double beta2_pow = 1.0;
};

void require(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

void require_close(double actual, double expected, double tolerance,
                   const std::string& message) {
    require(std::abs(actual - expected) <= tolerance,
            message + " (actual=" + std::to_string(actual) +
                ", expected=" + std::to_string(expected) + ")");
}

std::vector<double> adam_step(const std::vector<double>& params,
                              const std::vector<double>& grads,
                              adam_state_2& state, double lr, double beta1,
                              double beta2, double eps,
                              double weight_decay = 0.0) {
    if (state.m.empty()) {
        state.m.assign(params.size(), 0.0);
        state.v.assign(params.size(), 0.0);
    }
    ++state.step;
    state.beta1_pow *= beta1;
    state.beta2_pow *= beta2;
    const double bias_c1 = 1.0 - state.beta1_pow;
    const double bias_c2 = 1.0 - state.beta2_pow;

    std::vector<double> out(params.size());
    for (std::size_t i = 0; i < params.size(); ++i) {
        const double g = grads[i];
        state.m[i] = beta1 * state.m[i] + (1.0 - beta1) * g;
        state.v[i] = beta2 * state.v[i] + (1.0 - beta2) * g * g;
        const double m_hat = state.m[i] / bias_c1;
        const double v_hat = state.v[i] / bias_c2;
        const double decayed = params[i] * (1.0 - lr * weight_decay);
        out[i] = decayed - lr * m_hat / (std::sqrt(v_hat) + eps);
    }
    return out;
}

std::string read_file(const std::string& path) {
    std::ifstream input(path);
    require(input.good(), "cannot read " + path);
    std::ostringstream contents;
    contents << input.rdbuf();
    return contents.str();
}

void test_adam_state_accumulates() {
    adam_state_2 state;
    std::vector<double> params{1.0};
    params = adam_step(params, {0.1}, state, 0.01, 0.9, 0.999, 1e-8);
    require_close(params[0], 0.990000001, 1e-9, "Adam first update");
    require_close(state.m[0], 0.01, 1e-12, "Adam first moment");
    require_close(state.v[0], 0.00001, 1e-12, "Adam second moment");

    params = adam_step(params, {-0.2}, state, 0.01, 0.9, 0.999, 1e-8);
    require(state.step == 2, "Adam parameter step persists");
    require_close(state.m[0], -0.011, 1e-12, "Adam accumulated first moment");
    require_close(state.v[0], 0.00004999, 1e-12,
                  "Adam accumulated second moment");
    require_close(params[0], 0.993661035, 1e-8, "Adam second update");
}

void test_adamw_is_decoupled() {
    adam_state_2 state;
    const std::vector<double> out =
        adam_step({2.0}, {0.0}, state, 0.1, 0.9, 0.999, 1e-8, 0.1);
    require_close(out[0], 1.98, 1e-12,
                  "adam_w zero-gradient update is only weight decay");
    require_close(state.m[0], 0.0, 0.0,
                  "adam_w weight decay does not enter first moment");
    require_close(state.v[0], 0.0, 0.0,
                  "adam_w weight decay does not enter second moment");
}

void test_state_resume_matches_continuous_run() {
    adam_state_2 continuous;
    std::vector<double> continuous_params{1.0, -2.0};
    continuous_params = adam_step(continuous_params, {0.2, -0.1}, continuous,
                                  0.001, 0.9, 0.999, 1e-8, 0.01);

    adam_state_2 resumed = continuous;
    std::vector<double> resumed_params = continuous_params;
    continuous_params = adam_step(continuous_params, {-0.4, 0.3}, continuous,
                                  0.001, 0.9, 0.999, 1e-8, 0.01);
    resumed_params = adam_step(resumed_params, {-0.4, 0.3}, resumed, 0.001,
                               0.9, 0.999, 1e-8, 0.01);

    for (std::size_t i = 0; i < continuous_params.size(); ++i) {
        require_close(resumed_params[i], continuous_params[i], 1e-15,
                      "resumed parameter matches continuous parameter");
        require_close(resumed.m[i], continuous.m[i], 1e-15,
                      "resumed first moment matches");
        require_close(resumed.v[i], continuous.v[i], 1e-15,
                      "resumed second moment matches");
    }
    require(resumed.step == continuous.step, "resumed step matches");
}

void test_s_implementation_wires_persistent_state() {
    const std::string optim = read_file("optimizer/optim.s");
    const std::string optimizer = read_file("optimizer/optimizer.s");
    require(optim.find("func adam_step_state") != std::string::npos,
            "state-returning Adam update is present");
    require(optim.find("float decayed_param = params.data[i] * "
                       "(1.0 - optimizer.lr * optimizer.weight_decay)") !=
                std::string::npos,
            "adam_w uses decoupled weight decay");
    require(optimizer.find("else if group.kind == \"adam\"") !=
                std::string::npos,
            "high-level Adam dispatch is present");
    require(optimizer.find("param_steps: copy_int(group.param_steps)") !=
                std::string::npos,
            "optimizer state dictionaries preserve parameter steps");
    require(optimizer.find("m: group.first_moments[i].data") !=
                std::string::npos,
            "saved first moments feed the next update");
}

}

int main() {
    test_adam_state_accumulates();
    test_adamw_is_decoupled();
    test_state_resume_matches_continuous_run();
    test_s_implementation_wires_persistent_state();
    std::cout << "Adam/adam_w optimizer regression tests passed\n";
    return 0;
}
