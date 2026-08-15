package v1

import "core"
import "engine"

type v1_request struct {
    request_id         string
    model             string
    messages          []interface{}
    max_tokens         int32
    temperature       float32
    top_p              float32
    top_k              int32
    frequency_penalty  float32
    presence_penalty   float32
    stream            bool
    stop              []string
    tools             []interface{}
    tool_choice        interface{}
}

type v1_response struct {
    id                string
    object            string
    created           int64
    model             string
    content           []map[string]interface{}
    stop_reason        string
    usage             map[string]int32
}

type v1_stream_response struct {
    id                string
    object            string
    created           int64
    model             string
    choices           []map[string]interface{}
    usage             map[string]int32
}

type request_pool struct {
    max_size           int32
    requests          []*v1_request
    indices           map[string]int32
}

type v1_engine struct {
    engine            *engine.llm_engine
    async_engine       *engine.async_llm_engine
    request_pool       *request_pool
    is_initialized     bool
}

func new_request_pool(max_size int32) *request_pool {
    return &request_pool{
        max_size:  max_size,
        requests: make([]*v1_request, 0, max_size),
        indices:  make(map[string]int32),
    }
}

func (rp *request_pool) add(req *v1_request) error {
    if int32(len(rp.requests)) >= rp.max_size {
        return core.Errorf("request pool full")
    }
    
    rp.indices[req.request_id] = int32(len(rp.requests))
    rp.requests = append(rp.requests, req)
    
    return nil
}

func (rp *request_pool) get(request_id string) *v1_request {
    if idx, exists := rp.indices[request_id]; exists {
        if idx >= 0 && idx < int32(len(rp.requests)) {
            return rp.requests[idx]
        }
    }
    return nil
}

func (rp *request_pool) remove(request_id string) {
    if idx, exists := rp.indices[request_id]; exists {
        if idx >= 0 && idx < int32(len(rp.requests)) {
            rp.requests = append(rp.requests[:idx], rp.requests[idx+1:]...)
        }
        delete(rp.indices, request_id)
    }
}

func (rp *request_pool) size() int32 {
    return int32(len(rp.requests))
}

func new_v1_engine(eng *engine.llm_engine) *v1_engine {
    return &v1_engine{
        engine:        eng,
        request_pool:   new_request_pool(256),
        is_initialized: false,
    }
}

func (ve *v1_engine) set_async_engine(async_eng *engine.async_llm_engine) {
    ve.async_engine = async_eng
}

func (ve *v1_engine) initialize() error {
    if ve.engine == nil {
        return core.Errorf("base engine not set")
    }
    
    ve.is_initialized = true
    core.Println("V1Engine initialized")
    
    return nil
}

func (ve *v1_engine) prepare_request(req *v1_request) error {
    if !ve.is_initialized {
        return core.Errorf("engine not initialized")
    }
    
    if req.request_id == "" {
        req.request_id = core.GenerateId()
    }
    
    if req.max_tokens <= 0 {
        req.max_tokens = 1024
    }
    
    if req.temperature < 0 || req.temperature > 2.0 {
        req.temperature = 0.7
    }
    
    if req.top_p < 0 || req.top_p > 1.0 {
        req.top_p = 1.0
    }
    
    return ve.request_pool.add(req)
}

func (ve *v1_engine) execute(req *v1_request) (*v1_response, error) {
    if !ve.is_initialized {
        return nil, core.Errorf("engine not initialized")
    }
    
    prompt := ""
    if len(req.messages) > 0 {
        for _, msg := range req.messages {
            msg_map := msg.(map[string]interface{})
            role := msg_map["role"].(string)
            content := msg_map["content"].(string)
            
            if role == "user" {
                prompt = prompt + "User: " + content + "\n"
            } else if role == "assistant" {
                prompt = prompt + "Assistant: " + content + "\n"
            } else if role == "system" {
                prompt = content + "\n" + prompt
            }
        }
    }
    
    sampling_params := engine.sampling_params{
        temperature:      req.temperature,
        top_p:            req.top_p,
        top_k:            req.top_k,
        max_tokens:       req.max_tokens,
        frequency_penalty: req.frequency_penalty,
        presence_penalty:  req.presence_penalty,
        stop:            req.stop,
    }
    
    generated_text, err := ve.engine.generate_completion(prompt, sampling_params)
    if err != nil {
        return nil, err
    }
    
    response := &v1_response{
        id:      req.request_id,
        object:  "chat.completion",
        created: core.CurrentTimeMs(),
        model:   req.model,
        content: []map[string]interface{}{
            {
                "type": "text",
                "text": generated_text,
            },
        },
        stop_reason: "stop",
        usage: map[string]int32{
            "prompt_tokens":     0,
            "completion_tokens": 0,
            "total_tokens":      0,
        },
    }
    
    ve.request_pool.remove(req.request_id)
    
    return response, nil
}

func (ve *v1_engine) execute_stream(req *v1_request) (chan *v1_stream_response, error) {
    if !ve.is_initialized {
        resp_chan := make(chan *v1_stream_response)
        close(resp_chan)
        return resp_chan, core.Errorf("engine not initialized")
    }
    
    resp_chan := make(chan *v1_stream_response, 100)
    
    go func() {
        defer close(resp_chan)
        defer ve.request_pool.remove(req.request_id)
        
        prompt := ""
        if len(req.messages) > 0 {
            for _, msg := range req.messages {
                msg_map := msg.(map[string]interface{})
                role := msg_map["role"].(string)
                content := msg_map["content"].(string)
                
                if role == "user" {
                    prompt = prompt + "User: " + content + "\n"
                } else if role == "assistant" {
                    prompt = prompt + "Assistant: " + content + "\n"
                }
            }
        }
        
        sampling_params := engine.sampling_params{
            temperature:      req.temperature,
            top_p:            req.top_p,
            top_k:            req.top_k,
            max_tokens:       req.max_tokens,
            frequency_penalty: req.frequency_penalty,
            presence_penalty:  req.presence_penalty,
            stop:            req.stop,
        }
        
        output, _ := ve.engine.get_output(req.request_id)
        
        if output != nil && len(output.text) > 0 {
            text := output.text[0]
            
            resp_chan <- &v1_stream_response{
                id:      req.request_id,
                object:  "chat.completion.chunk",
                created: core.CurrentTimeMs(),
                model:   req.model,
                choices: []map[string]interface{}{
                    {
                        "index": 0,
                        "delta": map[string]interface{}{
                            "role":    "assistant",
                            "content": "",
                        },
                    },
                },
            }
            
            for i := 0; i < len(text); i++ {
                token := string(text[i])
                
                resp_chan <- &v1_stream_response{
                    id:      req.request_id,
                    object:  "chat.completion.chunk",
                    created: core.CurrentTimeMs(),
                    model:   req.model,
                    choices: []map[string]interface{}{
                        {
                            "index": 0,
                            "delta": map[string]interface{}{
                                "content": token,
                            },
                        },
                    },
                }
            }
            
            resp_chan <- &v1_stream_response{
                id:      req.request_id,
                object:  "chat.completion.chunk",
                created: core.CurrentTimeMs(),
                model:   req.model,
                choices: []map[string]interface{}{
                    {
                        "index":        0,
                        "delta":        map[string]interface{}{},
                        "finish_reason": "stop",
                    },
                },
                usage: map[string]int32{
                    "prompt_tokens":     0,
                    "completion_tokens": 0,
                    "total_tokens":      0,
                },
            }
        }
    }()
    
    return resp_chan, nil
}

func (ve *v1_engine) execute_async(req *v1_request, callback func(*v1_response, error)) error {
    if !ve.is_initialized {
        return core.Errorf("engine not initialized")
    }
    
    if ve.async_engine == nil {
        return core.Errorf("async engine not set")
    }
    
    prompt := ""
    if len(req.messages) > 0 {
        for _, msg := range req.messages {
            msg_map := msg.(map[string]interface{})
            role := msg_map["role"].(string)
            content := msg_map["content"].(string)
            
            if role == "user" {
                prompt = prompt + "User: " + content + "\n"
            }
        }
    }
    
    sampling_params := engine.sampling_params{
        temperature:      req.temperature,
        top_p:            req.top_p,
        top_k:            req.top_k,
        max_tokens:       req.max_tokens,
        frequency_penalty: req.frequency_penalty,
        presence_penalty:  req.presence_penalty,
        stop:            req.stop,
    }
    
    async_callback := func(output *engine.request_output, err error) {
        if err != nil {
            callback(nil, err)
            ve.request_pool.remove(req.request_id)
            return
        }
        
        resp := &v1_response{
            id:      req.request_id,
            object:  "chat.completion",
            created: core.CurrentTimeMs(),
            model:   req.model,
            usage: map[string]int32{
                "prompt_tokens":     0,
                "completion_tokens": 0,
                "total_tokens":      0,
            },
        }
        
        if output != nil && len(output.text) > 0 {
            resp.content = []map[string]interface{}{
                {
                    "type": "text",
                    "text": output.text[0],
                },
            }
        }
        
        callback(resp, nil)
        ve.request_pool.remove(req.request_id)
    }
    
    _, err := ve.async_engine.generate_completion_async(prompt, sampling_params, async_callback)
    
    return err
}

func (ve *v1_engine) get_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    
    if ve.engine != nil {
        engine_stats := ve.engine.get_stats()
        for key, value := range engine_stats {
            stats[key] = value
        }
    }
    
    stats["request_pool_size"] = ve.request_pool.size()
    
    return stats
}
