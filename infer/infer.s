package neurx.infer

use neurx.infer.cache
use neurx.infer.cache.paged_kv_cache
use neurx.infer.decode
use neurx.infer.sampling
use neurx.infer.serve
use neurx.infer.serve.continuous_batch
use neurx.infer.eval
use neurx.ops
use neurx.tensor.tensor

struct infer_pipeline_state {
    infer_request_state request
    infer_response_state response
    decode_state decode
    continuous_batch_state batch
    paged_kv_cache_state paged_kv
    infer_eval_state eval
}

func new_infer_pipeline_state(string request_id, string model, int input_tokens, int max_new_tokens, int layer_count, int max_seq_len) infer_pipeline_state {
    kv_cache_state cache = new_kv_cache_state(layer_count, max_seq_len)
    int block_size = 16
    int max_blocks = (max_seq_len + block_size - 1) / block_size
    if max_blocks <= 0 {
        max_blocks = 1
    }
    paged_kv_cache_state paged = new_paged_kv_cache_state(layer_count, block_size, max_blocks)
    sampling_state sampling = new_sampling_state()
    decode_state decode = new_decode_state(max_new_tokens, cache, sampling)
    continuous_batch_state batch = new_continuous_batch_state(8)
    batch = continuous_batch_enqueue_request(batch, input_tokens)
    paged = paged_kv_reserve_tokens(paged, input_tokens)
    infer_pipeline_state {
        request: new_infer_request_state(request_id, model, input_tokens, max_new_tokens),
        response: new_infer_response_state(request_id),
        decode: decode,
        batch: batch,
        paged_kv: paged,
        eval: new_infer_eval_state(),
    }
}

func infer_pipeline_step(infer_pipeline_state state, int next_token_id) infer_pipeline_state {
    decode_state next_decode = decode_step(state.decode, next_token_id)
    continuous_batch_state next_batch = continuous_batch_record_decode_step(state.batch, 1)
    paged_kv_cache_state next_paged = paged_kv_reserve_tokens(state.paged_kv, 1)
    if next_decode.finished {
        next_batch = continuous_batch_finish_request(next_batch)
        next_paged = paged_kv_release_tokens(next_paged, next_decode.step)
    }
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
        batch: next_batch,
        paged_kv: next_paged,
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
        batch: state.batch,
        paged_kv: state.paged_kv,
        eval: state.eval,
    }
}

func infer_pipeline_batch_active(infer_pipeline_state state) int {
    state.batch.active_requests
}

func infer_pipeline_paged_kv_blocks(infer_pipeline_state state) int {
    state.paged_kv.allocated_blocks
}

func infer_pipeline_state_dict(infer_pipeline_state state) infer_pipeline_state {
    state
}

func infer_pipeline_load_state_dict(infer_pipeline_state state, infer_pipeline_state other) infer_pipeline_state {
    other
}
