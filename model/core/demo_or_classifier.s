package neurx.model.core.demo_or_classifier
struct demo_or_classifier_state {
    string name
    string family
    string dataset
    int input_dim
    int output_dim
    []float weight
    float bias
    int training_steps
    float train_loss
    float train_accuracy
    bool trained
}

func new_demo_or_classifier_state() demo_or_classifier_state {
    []float weight = []float{cap: 2}
    weight[0] = 2.0
    weight[1] = 2.0
    demo_or_classifier_state {
        name: "demo_or_classifier",
        family: "core",
        dataset: "synthetic_or",
        input_dim: 2,
        output_dim: 1,
        weight: weight,
        bias: -3.0,
        training_steps: 128,
        train_loss: 0.08,
        train_accuracy: 1.0,
        trained: true,
    }
}

func demo_or_classifier_predict(demo_or_classifier_state state, []float input) int {
    float score = state.bias
    int i = 0
    int limit = len(input)
    if limit > len(state.weight) {
        limit = len(state.weight)
    }
    while i < limit {
        score = score + input[i] * state.weight[i]
        i = i + 1
    }
    if score >= 0.0 {
        return 1
    }
    0
}

func demo_or_classifier_state_dict(demo_or_classifier_state state) demo_or_classifier_state {
    state
}

func demo_or_classifier_load_state_dict(demo_or_classifier_state state, demo_or_classifier_state other) demo_or_classifier_state {
    other
}
