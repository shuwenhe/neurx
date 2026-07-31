package neurx.inference.serve
struct infer_request_state {
    string request_id
    string model
    int input_tokens
    int max_new_tokens
}

struct infer_response_state {
    string request_id
    int output_tokens
    bool finished
    int status
}
func new_infer_request_state(string request_id, string model, int input_tokens, int max_new_tokens) infer_request_state {
    infer_request_state {
        request_id: request_id,
        model: model,
        input_tokens: input_tokens,
        max_new_tokens: max_new_tokens,
    }
}

func new_infer_response_state(string request_id) infer_response_state {
    infer_response_state {
        request_id: request_id,
        output_tokens: 0,
        finished: false,
        status: 200,
    }
}

func infer_response_update(infer_response_state state, int output_tokens, bool finished, int status) infer_response_state {
    infer_response_state {
        request_id: state.request_id,
        output_tokens: output_tokens,
        finished: finished,
        status: status,
    }
}

func infer_request_state_dict(infer_request_state state) infer_request_state {
    state
}

func infer_request_load_state_dict(infer_request_state state, infer_request_state other) infer_request_state {
    other
}

func infer_response_state_dict(infer_response_state state) infer_response_state {
    state
}

func infer_response_load_state_dict(infer_response_state state, infer_response_state other) infer_response_state {
    other
}
