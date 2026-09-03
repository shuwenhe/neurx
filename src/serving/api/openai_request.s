package openai_api
import "encoding/json"
import "time"
struct chat_message {
	string          role
	string          content
	string          name
	interface{}     tool_calls
}

struct chat_completion_request {
	string              model
	chat_message[]   messages
	float32             temperature
	float32             top_p
	int32               top_k
	float32             min_p
	int32               max_tokens
	float32             presence_penalty
	float32             frequency_penalty
	float32             repetition_penalty
	[]string         stop
	bool                stream
	interface{}         stream_options
	int32               seed
	interface{}         response_format
	interface{}[]    tools
	string              tool_choice
	int64               timeout_ms
	string              request_id
	string              user_id
	int64               created_at
}

struct completion_request {
	string          model
	string          prompt
	string          suffix
	int32           max_tokens
	float32         temperature
	float32         top_p
	int32           top_k
	float32         frequency_penalty
	float32         presence_penalty
	[]string     stop
	bool            stream
	int32           seed
	bool            echo
	int32           best_of
	int64           timeout_ms
	string          request_id
	string          user_id
	int64           created_at
}

struct embedding_request {
	string          model
	[]string     input
	string          encoding_format
	int64           timeout_ms
	string          request_id
	string          user_id
	int64           created_at
}
	ERR_MISSING_MODEL         = 0
	ERR_MISSING_MESSAGES      = 1
	ERR_INVALID_TEMPERATURE   = 2
	ERR_INVALID_TOP_P         = 3
	ERR_INVALID_TOP_K         = 4
	ERR_INVALID_MAX_TOKENS    = 5
	ERR_INVALID_PENALTY       = 6
	ERR_INVALID_REQUEST       = 7
	ERR_UNSUPPORTED_MODEL     = 8
}

struct request_validator {
	float32         min_temperature
	float32         max_temperature
	int32           max_tokens_limit
	int32           min_tokens_limit
	[]string     supported_models
}

func create_default_validator() request_validator {
	return request_validator{
		min_temperature:  0.0,
		max_temperature:  2.0,
		max_tokens_limit: 8192,
		min_tokens_limit: 1,
		supported_models: make([]string, 0),
	}
}

func (v request_validator*) add_supported_model(model string) {
	v.supported_models = append(v.supported_models, model)
}

func (v request_validator*) validate_chat_request(req chat_completion_request) (bool, validation_error) {
	if len(req.model) == 0 {
		return false, ERR_MISSING_MODEL
	}
	if len(req.messages) == 0 {
		return false, ERR_MISSING_MESSAGES
	}
	if req.temperature < v.min_temperature || req.temperature > v.max_temperature {
		return false, ERR_INVALID_TEMPERATURE
	}
	if req.top_p < 0.0 || req.top_p > 1.0 {
		return false, ERR_INVALID_TOP_P
	}
	if req.top_k < 0 {
		return false, ERR_INVALID_TOP_K
	}
	if req.max_tokens < v.min_tokens_limit || req.max_tokens > v.max_tokens_limit {
		return false, ERR_INVALID_MAX_TOKENS
	}
	if req.frequency_penalty < -2.0 || req.frequency_penalty > 2.0 {
		return false, ERR_INVALID_PENALTY
	}
	if req.presence_penalty < -2.0 || req.presence_penalty > 2.0 {
		return false, ERR_INVALID_PENALTY
	}
	if !v.is_model_supported(req.model) {
		return false, ERR_UNSUPPORTED_MODEL
	}
	return true, 0
}

func (v request_validator*) validate_completion_request(req completion_request) (bool, validation_error) {
	if len(req.model) == 0 {
		return false, ERR_MISSING_MODEL
	}
	if len(req.prompt) == 0 {
		return false, ERR_MISSING_MESSAGES
	}
	if req.temperature < v.min_temperature || req.temperature > v.max_temperature {
		return false, ERR_INVALID_TEMPERATURE
	}
	if req.top_p < 0.0 || req.top_p > 1.0 {
		return false, ERR_INVALID_TOP_P
	}
	if req.max_tokens < v.min_tokens_limit || req.max_tokens > v.max_tokens_limit {
		return false, ERR_INVALID_MAX_TOKENS
	}
	if !v.is_model_supported(req.model) {
		return false, ERR_UNSUPPORTED_MODEL
	}
	return true, 0
}

func (v request_validator*) validate_embedding_request(req embedding_request) (bool, validation_error) {
	if len(req.model) == 0 {
		return false, ERR_MISSING_MODEL
	}
	if len(req.input) == 0 {
		return false, ERR_INVALID_REQUEST
	}
	if !v.is_model_supported(req.model) {
		return false, ERR_UNSUPPORTED_MODEL
	}
	return true, 0
}

func (v request_validator*) is_model_supported(model string) bool {
	for supported := range v.supported_models {
		if supported == model {
			return true
		}
	}
	return len(v.supported_models) == 0
}

func create_chat_completion_request_from_json(data interface{}) (chat_completion_request, error) {
	req := chat_completion_request{
		temperature: 0.7,
		top_p:       1.0,
		top_k:       50,
		min_p:       0.0,
		max_tokens:  256,
		stream:      false,
		created_at:  time.Now().UnixNano(),
	}
	return req, nil
}

func create_completion_request_from_json(data interface{}) (completion_request, error) {
	req := completion_request{
		temperature: 0.7,
		top_p:       1.0,
		top_k:       50,
		max_tokens:  256,
		stream:      false,
		created_at:  time.Now().UnixNano(),
	}
	return req, nil
}

func create_embedding_request_from_json(data interface{}) (embedding_request, error) {
	req := embedding_request{
		encoding_format: "float",
		created_at:      time.Now().UnixNano(),
	}
	return req, nil
}

func (req chat_completion_request) to_json() string {
	data := map[string]interface{}{
		"model":             req.model,
		"messages":          req.messages,
		"temperature":       req.temperature,
		"top_p":             req.top_p,
		"top_k":             req.top_k,
		"max_tokens":        req.max_tokens,
		"presence_penalty":  req.presence_penalty,
		"frequency_penalty": req.frequency_penalty,
		"stream":            req.stream,
		"created_at":        req.created_at,
	}
	return json.Marshal(data)
}

func (req completion_request) to_json() string {
	data := map[string]interface{}{
		"model":             req.model,
		"prompt":            req.prompt,
		"temperature":       req.temperature,
		"top_p":             req.top_p,
		"max_tokens":        req.max_tokens,
		"frequency_penalty": req.frequency_penalty,
		"presence_penalty":  req.presence_penalty,
		"stream":            req.stream,
		"created_at":        req.created_at,
	}
	return json.Marshal(data)
}

func (req embedding_request) to_json() string {
	data := map[string]interface{}{
		"model":           req.model,
		"input":           req.input,
		"encoding_format": req.encoding_format,
		"created_at":      req.created_at,
	}
	return json.Marshal(data)
}

func validation_error_to_string(err validation_error) string {
	switch err {
	case ERR_MISSING_MODEL:
		return "missing required parameter: model"
	case ERR_MISSING_MESSAGES:
		return "missing required parameter: messages or prompt"
	case ERR_INVALID_TEMPERATURE:
		return "temperature must be between 0.0 and 2.0"
	case ERR_INVALID_TOP_P:
		return "top_p must be between 0.0 and 1.0"
	case ERR_INVALID_TOP_K:
		return "top_k must be non-negative"
	case ERR_INVALID_MAX_TOKENS:
		return "max_tokens out of valid range"
	case ERR_INVALID_PENALTY:
		return "penalty must be between -2.0 and 2.0"
	case ERR_INVALID_REQUEST:
		return "invalid request format"
	case ERR_UNSUPPORTED_MODEL:
		return "model not supported"
	default:
		return "unknown validation error"
	}
}
