package openai_api

import "encoding/json"
import "time"

struct choice {
	int32           index
	chat_message    message
	interface{}     delta
	string          finish_reason
	interface{}     logprobs
}

struct completion_choice {
	int32           index
	string          text
	string          finish_reason
	interface{}     logprobs
}

struct usage {
	int32   prompt_tokens
	int32   completion_tokens
	int32   total_tokens
	int32   cache_read_tokens
	int32   cache_creation_tokens
}

struct chat_completion_response {
	string              id
	string              object
	int64               created
	string              model
	vec[choice]         choices
	usage               usage
	string              system_fingerprint
	
	string              request_id
	int64               response_ms
}

struct completion_response {
	string              id
	string              object
	int64               created
	string              model
	vec[completion_choice] choices
	usage               usage
	string              system_fingerprint
}

struct embedding_data {
	string          object
	int32           index
	vec[float32]    embedding
}

struct embedding_response {
	string          object
	vec[embedding_data] data
	string          model
	usage           usage
	
	int64           created
}

struct model_info {
	string          id
	string          object
	int64           created
	string          owned_by
	vec[interface{}] permission
	string          root
	string          parent
}

struct model_list_response {
	string          object
	vec[model_info] data
}

struct error_detail {
	string  type
	string  message
	string  code
	string  param
}

struct error_response {
	error struct {
		string          message
		string          type
		string          param
		string          code
		int32           status
		error_detail    detail
	}
}

func create_chat_completion_response(
	request_id string,
	model string,
	choices vec[choice],
	usage_data usage,
) chat_completion_response {
	return chat_completion_response{
		id:                generate_response_id(),
		object:            "chat.completion",
		created:           time.Now().Unix(),
		model:             model,
		choices:           choices,
		usage:             usage_data,
		system_fingerprint: "fp_default",
		request_id:        request_id,
	}
}

func create_completion_response(
	model string,
	choices vec[completion_choice],
	usage_data usage,
) completion_response {
	return completion_response{
		id:                generate_response_id(),
		object:            "text_completion",
		created:           time.Now().Unix(),
		model:             model,
		choices:           choices,
		usage:             usage_data,
		system_fingerprint: "fp_default",
	}
}

func create_embedding_response(
	model string,
	embeddings vec[vec[float32]],
	usage_data usage,
) embedding_response {
	data := make(vec[embedding_data], 0, len(embeddings))
	
	for i := int32(0); i < int32(len(embeddings)); i++ {
		data = append(data, embedding_data{
			object:    "embedding",
			index:     i,
			embedding: embeddings[i],
		})
	}
	
	return embedding_response{
		object:  "list",
		data:    data,
		model:   model,
		usage:   usage_data,
		created: time.Now().Unix(),
	}
}

func create_model_list_response(models vec[string]) model_list_response {
	data := make(vec[model_info], 0, len(models))
	
	for model := range models {
		data = append(data, model_info{
			id:       model,
			object:   "model",
			created:  time.Now().Unix(),
			owned_by: "neurx",
		})
	}
	
	return model_list_response{
		object: "list",
		data:   data,
	}
}

func create_error_response(status_code int32, message string, error_type string) error_response {
	return error_response{
		error: struct {
			message string
			type_   string
			code    string
			status  int32
		}{
			message: message,
			type_:   error_type,
			code:    error_code_from_status(status_code),
			status:  status_code,
		},
	}
}

func (resp chat_completion_response) to_json() string {
	data := map[string]interface{}{
		"id":      resp.id,
		"object": resp.object,
		"created": resp.created,
		"model":   resp.model,
		"choices": resp.choices,
		"usage": map[string]interface{}{
			"prompt_tokens":     resp.usage.prompt_tokens,
			"completion_tokens": resp.usage.completion_tokens,
			"total_tokens":      resp.usage.total_tokens,
		},
		"system_fingerprint": resp.system_fingerprint,
	}
	
	return json.Marshal(data)
}

func (resp completion_response) to_json() string {
	data := map[string]interface{}{
		"id":      resp.id,
		"object": resp.object,
		"created": resp.created,
		"model":   resp.model,
		"choices": resp.choices,
		"usage": map[string]interface{}{
			"prompt_tokens":     resp.usage.prompt_tokens,
			"completion_tokens": resp.usage.completion_tokens,
			"total_tokens":      resp.usage.total_tokens,
		},
		"system_fingerprint": resp.system_fingerprint,
	}
	
	return json.Marshal(data)
}

func (resp embedding_response) to_json() string {
	data := map[string]interface{}{
		"object": resp.object,
		"data":   resp.data,
		"model":  resp.model,
		"usage": map[string]interface{}{
			"prompt_tokens":     resp.usage.prompt_tokens,
			"total_tokens":      resp.usage.total_tokens,
		},
		"created": resp.created,
	}
	
	return json.Marshal(data)
}

func (resp model_list_response) to_json() string {
	data := map[string]interface{}{
		"object": resp.object,
		"data":   resp.data,
	}
	
	return json.Marshal(data)
}

func (resp error_response) to_json() string {
	return json.Marshal(resp)
}

func create_stream_choice(index int32, delta interface{}, finish_reason string) choice {
	return choice{
		index:        index,
		delta:        delta,
		finish_reason: finish_reason,
	}
}

func create_stream_event(
	request_id string,
	model string,
	choice choice,
) chat_completion_response {
	return chat_completion_response{
		id:      generate_response_id(),
		object:  "chat.completion.chunk",
		created: time.Now().Unix(),
		model:   model,
		choices: make(vec[choice], 1),
		request_id: request_id,
	}
}

func create_completion_choice(index int32, text string, finish_reason string) completion_choice {
	return completion_choice{
		index:        index,
		text:         text,
		finish_reason: finish_reason,
	}
}

func generate_response_id() string {
	return format("chatcmpl-%d", time.Now().UnixNano())
}

func error_code_from_status(status int32) string {
	switch status {
	case 400:
		return "invalid_request_error"
	case 401:
		return "authentication_error"
	case 403:
		return "permission_error"
	case 404:
		return "not_found_error"
	case 429:
		return "rate_limit_error"
	case 500:
		return "server_error"
	case 503:
		return "service_unavailable_error"
	default:
		return "internal_error"
	}
}

func http_status_from_error_code(code string) int32 {
	switch code {
	case "invalid_request_error":
		return 400
	case "authentication_error":
		return 401
	case "permission_error":
		return 403
	case "not_found_error":
		return 404
	case "rate_limit_error":
		return 429
	case "server_error":
		return 500
	case "service_unavailable_error":
		return 503
	default:
		return 500
	}
}

struct response_formatter {
	stream_format        bool
	include_usage        bool
	include_logprobs     bool
	decimal_precision    int32
}

func create_default_formatter() response_formatter {
	return response_formatter{
		stream_format:     false,
		include_usage:     true,
		include_logprobs:  false,
		decimal_precision: 4,
	}
}

func (f response_formatter*) set_stream_format(stream bool) {
	f.stream_format = stream
}

func (f response_formatter*) set_include_usage(include bool) {
	f.include_usage = include
}

func (f response_formatter*) set_include_logprobs(include bool) {
	f.include_logprobs = include
}

func format_choice_for_streaming(choice choice) string {
	data := map[string]interface{}{
		"index": choice.index,
		"delta": choice.delta,
		"finish_reason": choice.finish_reason,
	}
	
	return json.Marshal(data)
}

func format_chunk_response(chunk_id string, model string, choice choice) string {
	data := map[string]interface{}{
		"id":      chunk_id,
		"object": "chat.completion.chunk",
		"created": time.Now().Unix(),
		"model":   model,
		"choices": []interface{}{
			map[string]interface{}{
				"index": choice.index,
				"delta": choice.delta,
				"finish_reason": choice.finish_reason,
			},
		},
	}
	
	return json.Marshal(data)
}
