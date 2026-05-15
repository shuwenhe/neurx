package neurx.infer

use neurx.infer.cache
use neurx.infer.cache.paged_kv_cache
use neurx.infer.cache.prefix_cache
use neurx.infer.decode
use neurx.infer.sampling
use neurx.infer.serve
use neurx.infer.serve.continuous_batch
use neurx.infer.serve.admission_control
use neurx.infer.vllm.vllm
use neurx.infer.eval
use neurx.ops
use neurx.tensor.tensor

struct infer_pipeline_state {
    infer_request_state request
    infer_response_state response
    decode_state decode
    continuous_batch_state batch
    paged_kv_cache_state paged_kv
    prefix_cache_state prefix_cache
    admission_control_state admission
    vllm_runtime_state vllm
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
    prefix_cache_state prefix_cache = new_prefix_cache_state(256, max_seq_len * 8)
    sampling_state sampling = new_sampling_state()
    decode_state decode = new_decode_state(max_new_tokens, cache, sampling)
    continuous_batch_state batch = new_continuous_batch_state(8)
    admission_control_state admission = new_admission_control_state_with_policy(batch.capacity, max_seq_len * 2, "srpt")
    bool accepted = admission_can_enqueue_with_remaining(admission, batch.active_requests, input_tokens, max_new_tokens)
    admission = admission_on_enqueue_with_remaining(admission, input_tokens, max_new_tokens, accepted)

    vllm_runtime_state vllm = new_vllm_runtime_state(
        layer_count,
        block_size,
        max_blocks,
        prefix_cache.max_entries,
        prefix_cache.max_tokens,
        admission.policy,
    )
    vllm = vllm_runtime_enqueue_request(vllm, request_id, input_tokens, max_new_tokens, accepted)

    prefix_cache = prefix_cache_lookup_with_key(prefix_cache, request_id, input_tokens)
    if accepted {
        prefix_cache = prefix_cache_insert_with_key(prefix_cache, request_id, input_tokens)
        batch = continuous_batch_enqueue_request(batch, input_tokens)
        paged = paged_kv_reserve_tokens(paged, input_tokens)
    }

    infer_response_state response = new_infer_response_state(request_id)
    if !accepted {
        response = infer_response_update(response, 0, true, 429)
    }

    infer_pipeline_state {
        request: new_infer_request_state(request_id, model, input_tokens, max_new_tokens),
        response: response,
        decode: decode,
        batch: batch,
        paged_kv: paged,
        prefix_cache: prefix_cache,
        admission: admission,
        vllm: vllm,
        eval: new_infer_eval_state(),
    }
}

func infer_pipeline_step(infer_pipeline_state state, int next_token_id) infer_pipeline_state {
    if state.response.finished {
        return state
    }
    decode_state next_decode = decode_step(state.decode, next_token_id)
    continuous_batch_state next_batch = continuous_batch_record_decode_step(state.batch, 1)
    paged_kv_cache_state next_paged = paged_kv_reserve_tokens(state.paged_kv, 1)
    admission_control_state next_admission = admission_on_decode_step(state.admission, 1)
    vllm_runtime_state next_vllm = vllm_runtime_record_decode(state.vllm, 1)
    if next_decode.finished {
        next_batch = continuous_batch_finish_request(next_batch)
        next_paged = paged_kv_release_tokens(next_paged, next_decode.step)
        next_admission = admission_on_finish(next_admission, state.request.input_tokens)
        next_vllm = vllm_runtime_finish_request(next_vllm, state.request.input_tokens)
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
        prefix_cache: state.prefix_cache,
        admission: next_admission,
        vllm: next_vllm,
        eval: state.eval,
    }
}

func infer_pipeline_enqueue_request(infer_pipeline_state state, string request_id, int input_tokens, int remaining_tokens) infer_pipeline_state {
    int prefill_tokens = input_tokens
    if prefill_tokens < 0 {
        prefill_tokens = 0
    }
    int decode_remaining = remaining_tokens
    if decode_remaining < 0 {
        decode_remaining = 0
    }

    bool accepted = admission_can_enqueue_with_remaining(state.admission, state.batch.active_requests, prefill_tokens, decode_remaining)
    admission_control_state next_admission = admission_on_enqueue_with_remaining(state.admission, prefill_tokens, decode_remaining, accepted)
    vllm_runtime_state next_vllm = vllm_runtime_enqueue_request(state.vllm, request_id, prefill_tokens, decode_remaining, accepted)

    prefix_cache_state next_prefix = next_vllm.prefix_cache.cache
    continuous_batch_state next_batch = state.batch
    paged_kv_cache_state next_paged = next_vllm.paged_attention.kv
    if accepted {
        next_batch = continuous_batch_enqueue_request(next_batch, prefill_tokens)
    }

    infer_pipeline_state {
        request: state.request,
        response: state.response,
        decode: state.decode,
        batch: next_batch,
        paged_kv: next_paged,
        prefix_cache: next_prefix,
        admission: next_admission,
        vllm: next_vllm,
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
    if state.response.finished {
        return state
    }

    if vllm_runtime_queue_depth(state.vllm) > 0 {
        vllm_runtime_step_result scheduled = vllm_runtime_schedule_next(state.vllm)
        if scheduled.selected {
            infer_pipeline_state scheduled_state = infer_pipeline_state {
                request: state.request,
                response: state.response,
                decode: state.decode,
                batch: state.batch,
                paged_kv: scheduled.state.paged_attention.kv,
                prefix_cache: scheduled.state.prefix_cache.cache,
                admission: state.admission,
                vllm: scheduled.state,
                eval: state.eval,
            }

            sampling_state scheduled_sample = scheduled_state.decode.sampling
            int next_token_id = ops.generation_step(
                logits,
                token_ids,
                scheduled_sample.temperature,
                scheduled_sample.top_k,
                scheduled_sample.top_p,
                scheduled_sample.repetition_penalty,
            )
            return infer_pipeline_step(scheduled_state, next_token_id)
        }
    }

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
        prefix_cache: state.prefix_cache,
        admission: state.admission,
        vllm: state.vllm,
        eval: state.eval,
    }
}

func infer_pipeline_batch_active(infer_pipeline_state state) int {
    state.batch.active_requests
}

func infer_pipeline_paged_kv_blocks(infer_pipeline_state state) int {
    state.paged_kv.allocated_blocks
}

func infer_pipeline_prefix_cache_hits(infer_pipeline_state state) int {
    state.prefix_cache.hits
}

func infer_pipeline_admission_rejected(infer_pipeline_state state) int {
    state.admission.rejected
}

func infer_pipeline_queue_depth(infer_pipeline_state state) int {
    vllm_runtime_queue_depth(state.vllm)
}

func infer_pipeline_state_dict(infer_pipeline_state state) infer_pipeline_state {
    state
}

func infer_pipeline_load_state_dict(infer_pipeline_state state, infer_pipeline_state other) infer_pipeline_state {
    other
}

func infer_pipeline_to_vllm_runtime(infer_pipeline_state state) vllm_runtime_state {
    state.vllm
}

func infer_pipeline_vllm_schedule_next(infer_pipeline_state state) vllm_runtime_step_result {
    vllm_runtime_schedule_next(state.vllm)
}
