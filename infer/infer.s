package neurx.infer

use neurx.infer.cache
use neurx.infer.decode
use neurx.infer.sampling
use neurx.infer.serve
use neurx.infer.eval
use neurx.ops
use neurx.tensor.tensor

struct infer_pipeline_state {
    infer_request_state request
    infer_response_state response
    decode_state decode
    infer_eval_state eval
}

func new_infer_pipeline_state(string request_id, string model, int input_tokens, int max_new_tokens, int layer_count, int max_seq_len) infer_pipeline_state {
    kv_cache_state cache = new_kv_cache_state(layer_count, max_seq_len)
    sampling_state sampling = new_sampling_state()
    decode_state decode = new_decode_state(max_new_tokens, cache, sampling)
    infer_pipeline_state {
        request: new_infer_request_state(request_id, model, input_tokens, max_new_tokens),
        response: new_infer_response_state(request_id),
        decode: decode,
        eval: new_infer_eval_state(),
    }
}

func infer_pipeline_step(infer_pipeline_state state, int next_token_id) infer_pipeline_state {
    decode_state next_decode = decode_step(state.decode, next_token_id)
    infer_response_state next_response = infer_response_update(
        state.response,
        next_decode.step,
        next_decode.finished,
        200,
    )
    infer_pipeline_state {
        request: state.request,
        response: next_response,
        decode: next_decode,
        eval: state.eval,
    }
}

func infer_pipeline_sample_logits(infer_pipeline_state state, tensor logits, tensor token_ids) tensor {
    sampling_state sample = state.decode.sampling
    ops.sampling_top_k_top_p(
        logits,
        token_ids,
        sample.temperature,
        sample.top_k,
        sample.top_p,
        sample.repetition_penalty,
    )
}

func infer_pipeline_step_from_logits(infer_pipeline_state state, tensor logits, tensor token_ids) infer_pipeline_state {
    sampling_state sample = state.decode.sampling
    int next_token_id = ops.generation_step(
        logits,
        token_ids,
        sample.temperature,
        sample.top_k,
        sample.top_p,
        sample.repetition_penalty,
    )
    infer_pipeline_step(state, next_token_id)
}

func infer_pipeline_set_sampling(infer_pipeline_state state, sampling_state sample) infer_pipeline_state {
    infer_pipeline_state {
        request: state.request,
        response: state.response,
        decode: decode_state {
            step: state.decode.step,
            max_new_tokens: state.decode.max_new_tokens,
            last_token_id: state.decode.last_token_id,
            finished: state.decode.finished,
            cache: state.decode.cache,
            sampling: sample,
        },
        eval: state.eval,
    }
}

func infer_pipeline_state_dict(infer_pipeline_state state) infer_pipeline_state {
    state
}

func infer_pipeline_load_state_dict(infer_pipeline_state state, infer_pipeline_state other) infer_pipeline_state {
    other
}
