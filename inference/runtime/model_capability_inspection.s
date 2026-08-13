package neurx.inference.runtime.model_capability_inspection
func model_task_generate() int { 1 }

func model_task_pooling() int { 2 }

func model_task_embed() int { 4 }

func model_task_classify() int { 8 }

func model_task_reward() int { 16 }

func model_task_transcription() int { 32 }

struct model_capability_manifest {
    string architecture
    string model_family
    string quantization
    int task_mask
    int max_model_length
    int vocabulary_size
    int hidden_size
    int layer_count
    int attention_head_count
    int kv_head_count
    bool is_multimodal
    bool is_moe
    bool supports_lora
    bool supports_prefix_cache
}
struct model_inspection_request {
    int required_task
    int requested_context_length
    bool require_multimodal
    bool require_lora
    bool require_prefix_cache
}
struct model_inspection_result {
    bool supported
    int error_code
    int parameter_shape_score
    int effective_context_length
}
func model_task_supported(int task_mask, int task) bool {
    int quotient = task_mask / task
    quotient - (quotient / 2) * 2 == 1
}
func model_manifest_valid(model_capability_manifest manifest) bool {
    manifest.architecture != "" && manifest.model_family != "" && manifest.task_mask > 0 && manifest.max_model_length > 0 && manifest.vocabulary_size > 0 && manifest.hidden_size > 0 && manifest.layer_count > 0 && manifest.attention_head_count > 0 && manifest.kv_head_count > 0 && manifest.kv_head_count <= manifest.attention_head_count
}
func inspect_model_capability(model_capability_manifest manifest, model_inspection_request request) model_inspection_result {
    if !model_manifest_valid(manifest) { return model_inspection_result {supported: false, error_code: 1, parameter_shape_score: 0, effective_context_length: 0} }
    if !model_task_supported(manifest.task_mask, request.required_task) { return model_inspection_result {supported: false, error_code: 2, parameter_shape_score: 0, effective_context_length: manifest.max_model_length} }
    if request.requested_context_length > manifest.max_model_length { return model_inspection_result {supported: false, error_code: 3, parameter_shape_score: 0, effective_context_length: manifest.max_model_length} }
    if request.require_multimodal && !manifest.is_multimodal { return model_inspection_result {supported: false, error_code: 4, parameter_shape_score: 0, effective_context_length: manifest.max_model_length} }
    if request.require_lora && !manifest.supports_lora { return model_inspection_result {supported: false, error_code: 5, parameter_shape_score: 0, effective_context_length: manifest.max_model_length} }
    if request.require_prefix_cache && !manifest.supports_prefix_cache { return model_inspection_result {supported: false, error_code: 6, parameter_shape_score: 0, effective_context_length: manifest.max_model_length} }
    int shape_score = manifest.hidden_size * manifest.layer_count
    if manifest.is_moe { shape_score = shape_score * 2 }
    model_inspection_result {supported: true, error_code: 0, parameter_shape_score: shape_score, effective_context_length: request.requested_context_length}
}
