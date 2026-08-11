package neurx.enterprise.speculative_inference

use neurx.backends.cuda_core
use neurx.inference.speculative.speculative_decode_core
use neurx.inference.speculative.draft_model_executor
use neurx.inference.speculative.speculative_verifier
use neurx.inference.speculative.speculative_runtime

struct speculative_inference_config {
    enable_speculative_decode: bool
    num_draft_tokens: int
    draft_model_scale: float
    draft_model_path: string
    acceptance_threshold: float
    adaptive_num_tokens: bool
    max_speculative_length: int
}

struct speculative_inference_system {
    draft_executor: draft_model_executor.draft_model_executor
    verifier_executor: speculative_verifier.verifier_executor
    decode_config: speculative_decode_core.speculative_decode_config
    runtime: speculative_runtime.speculative_decode_runtime
    system_config: speculative_inference_config
    statistics: speculative_decode_core.speculative_statistics
    is_initialized: bool
}

func new_speculative_inference_config() speculative_inference_config {
    cfg := speculative_inference_config{
        enable_speculative_decode: true,
        num_draft_tokens: 4,
        draft_model_scale: 0.3,
        draft_model_path: "./models/draft_model",
        acceptance_threshold: 0.75,
        adaptive_num_tokens: true,
        max_speculative_length: 16,
    }
    cfg
}

func init_speculative_inference_system(spec_cfg: speculative_inference_config) speculative_inference_system {
    draft_model_cfg := draft_model_executor.new_draft_model_config(
        "small",
        12,
        768,
        32000,
    )
    draft_executor := draft_model_executor.new_draft_model_executor(draft_model_cfg)
    draft_executor = draft_model_executor.initialize_draft_embeddings(draft_executor, 32000, 768)
    draft_executor = draft_model_executor.initialize_draft_layers(draft_executor, 12, 768)

    verifier_cfg := speculative_verifier.new_verifier_config(32000, spec_cfg.acceptance_threshold)
    verifier_executor := speculative_verifier.new_verifier_executor(verifier_cfg)
    verifier_executor = speculative_verifier.initialize_verifier_embeddings(verifier_executor, 32000, 768)

    decode_cfg := speculative_decode_core.new_speculative_config(
        spec_cfg.num_draft_tokens,
        spec_cfg.draft_model_scale,
        0.7,
    )

    runtime := speculative_runtime.new_speculative_decode_runtime(
        draft_executor,
        verifier_executor,
        decode_cfg,
    )

    sys := speculative_inference_system{
        draft_executor: draft_executor,
        verifier_executor: verifier_executor,
        decode_config: decode_cfg,
        runtime: runtime,
        system_config: spec_cfg,
        statistics: speculative_decode_core.new_speculative_statistics(),
        is_initialized: true,
    }

    sys
}

func speculative_inference_single(
    sys: speculative_inference_system,
    input_ids: []int,
    max_tokens: int,
) (speculative_inference_system, []int) {
    updated_sys := sys

    request := speculative_runtime.new_generation_request(1, input_ids, max_tokens)
    updated_runtime, output_tokens := speculative_runtime.generate_with_speculative_decoding(
        updated_sys.runtime,
        request,
    )

    updated_sys.runtime = updated_runtime
    updated_sys.statistics = updated_runtime.statistics

    (updated_sys, output_tokens)
}

func speculative_inference_batch(
    sys: speculative_inference_system,
    batch_input_ids: [][]int,
    max_tokens: int,
) (speculative_inference_system, [][]int) {
    updated_sys := sys
    batch_outputs := [][]int{}

    batch := speculative_runtime.new_generation_batch()

    i := 0
    while i < batch_input_ids.len {
        request := speculative_runtime.new_generation_request(i, batch_input_ids[i], max_tokens)
        batch.batch_requests = append(batch.batch_requests, request)
        i = i + 1
    }

    updated_runtime, updated_batch := speculative_runtime.process_speculative_batch(
        updated_sys.runtime,
        batch,
    )

    updated_sys.runtime = updated_runtime
    updated_sys.statistics = updated_runtime.statistics
    batch_outputs = updated_batch.final_outputs

    (updated_sys, batch_outputs)
}

func update_speculative_config(
    sys: speculative_inference_system,
    new_num_draft: int,
    new_threshold: float,
) speculative_inference_system {
    updated_sys := sys
    updated_sys.decode_config.num_draft_tokens = new_num_draft
    updated_sys.verifier_executor.config.acceptance_threshold = new_threshold
    updated_sys
}

func adaptive_update_speculative_params(sys: speculative_inference_system) speculative_inference_system {
    updated_sys := sys

    current_acceptance := speculative_decode_core.get_acceptance_rate(updated_sys.statistics)

    if updated_sys.system_config.adaptive_num_tokens {
        if current_acceptance > 0.9 {
            if updated_sys.decode_config.num_draft_tokens < updated_sys.system_config.max_speculative_length {
                updated_sys.decode_config.num_draft_tokens = updated_sys.decode_config.num_draft_tokens + 1
            }
        } else if current_acceptance < 0.7 {
            if updated_sys.decode_config.num_draft_tokens > 1 {
                updated_sys.decode_config.num_draft_tokens = updated_sys.decode_config.num_draft_tokens - 1
            }
        }
    }

    updated_sys.verifier_executor = speculative_verifier.adaptive_threshold_adjustment(
        updated_sys.verifier_executor,
        current_acceptance,
    )

    updated_sys
}

func get_speculative_performance_stats(sys: speculative_inference_system) string {
    result := "Speculative Inference Performance:"
    result = result + "\n  Total Generated: " + (sys.statistics.total_tokens_generated as string)
    result = result + "\n  Total Draft: " + (sys.statistics.total_draft_tokens as string)
    result = result + "\n  Total Verified: " + (sys.statistics.total_verified_tokens as string)
    result = result + "\n  Total Accepted: " + (sys.statistics.total_accepted_tokens as string)
    result = result + "\n  Total Rejected: " + (sys.statistics.total_rejected_tokens as string)

    acceptance_rate := speculative_decode_core.get_acceptance_rate(sys.statistics)
    result = result + "\n  Acceptance Rate: " + (acceptance_rate as string)

    speedup := speculative_decode_core.get_speedup_factor(sys.statistics)
    result = result + "\n  Speedup Factor: " + (speedup as string) + "x"
    result = result + "\n  Current Draft Tokens: " + (sys.decode_config.num_draft_tokens as string)
    result = result + "\n  Acceptance Threshold: " + (sys.verifier_executor.config.acceptance_threshold as string)

    result
}

func reset_speculative_statistics(sys: speculative_inference_system) speculative_inference_system {
    updated_sys := sys
    updated_sys.statistics = speculative_decode_core.new_speculative_statistics()
    updated_sys.runtime = speculative_runtime.reset_runtime_statistics(updated_sys.runtime)
    updated_sys
}

func should_use_speculative_decoding(sys: speculative_inference_system) bool {
    sys.system_config.enable_speculative_decode && sys.is_initialized
}
