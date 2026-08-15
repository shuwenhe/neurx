package engine

import "core"
import "sync"

type async_request_callback func(output *request_output, err error)

type async_llm_engine struct {
    engine              *llm_engine
    request_callbacks   map[string]async_request_callback
    callback_lock       interface{}
    worker_channel      interface{}
    is_running          bool
    stop_signal         chan bool
    request_channel     chan *async_request
}

type async_request struct {
    request_id      string
    prompt          string
    sampling_params sampling_params
    callback        async_request_callback
}

func new_async_llm_engine(config engine_config) *async_llm_engine {
    engine := new_llm_engine(config)
    
    async_engine := &async_llm_engine{
        engine:            engine,
        request_callbacks: make(map[string]async_request_callback),
        is_running:        false,
        stop_signal:       make(chan bool, 1),
        request_channel:   make(chan *async_request, config.max_num_seqs),
    }
    
    return async_engine
}

func (ae *async_llm_engine) initialize() error {
    return ae.engine.initialize()
}

func (ae *async_llm_engine) start_worker() error {
    if ae.is_running {
        return core.Errorf("async engine worker already running")
    }
    
    ae.is_running = true
    
    go ae.worker_loop()
    
    core.Println("async_llm_engine worker started")
    return nil
}

func (ae *async_llm_engine) worker_loop() {
    for ae.is_running {
        select {
        case <-ae.stop_signal:
            ae.is_running = false
            return
        case async_req := <-ae.request_channel:
            if async_req != nil {
                ae.process_async_request(async_req)
            }
        default:
            _, _ = ae.engine.step()
            core.Sleep(1)
        }
    }
}

func (ae *async_llm_engine) process_async_request(async_req *async_request) {
    err := ae.engine.add_request(async_req.request_id, async_req.prompt, async_req.sampling_params)
    if err != nil {
        if async_req.callback != nil {
            async_req.callback(nil, err)
        }
        return
    }
    
    ae.request_callbacks[async_req.request_id] = async_req.callback
    
    core.Printf("async request added: %s\n", async_req.request_id)
}

func (ae *async_llm_engine) generate_completion_async(prompt string, sampling_params sampling_params, callback async_request_callback) (string, error) {
    if !ae.is_running {
        return "", core.Errorf("async engine worker not running")
    }
    
    request_id := core.GenerateId()
    
    async_req := &async_request{
        request_id:      request_id,
        prompt:          prompt,
        sampling_params: sampling_params,
        callback:        callback,
    }
    
    select {
    case ae.request_channel <- async_req:
        return request_id, nil
    default:
        return "", core.Errorf("request channel full")
    }
}

func (ae *async_llm_engine) poll_output(request_id string) (*request_output, error) {
    output := ae.engine.get_output(request_id)
    if output == nil {
        return nil, core.Errorf("output not found for request: %s", request_id)
    }
    return output, nil
}

func (ae *async_llm_engine) cancel_request(request_id string) error {
    req := ae.engine.get_request(request_id)
    if req == nil {
        return core.Errorf("request not found: %s", request_id)
    }
    
    req.status = request_status_cancelled
    delete(ae.request_callbacks, request_id)
    
    return ae.engine.request_queue.remove(request_id)
}

func (ae *async_llm_engine) abort_request(request_id string) error {
    return ae.cancel_request(request_id)
}

func (ae *async_llm_engine) get_num_unfinished_requests() int32 {
    return ae.engine.request_queue.size() + int32(len(ae.engine.running_requests))
}

func (ae *async_llm_engine) abort_all() error {
    queue_size := ae.engine.request_queue.size()
    
    for i := int32(0); i < queue_size; i++ {
        batch := ae.engine.request_queue.get_next_batch(1)
        if len(batch) > 0 {
            ae.cancel_request(batch[0].request_id)
        }
    }
    
    for request_id := range ae.engine.running_requests {
        ae.cancel_request(request_id)
    }
    
    ae.request_callbacks = make(map[string]async_request_callback)
    
    return nil
}

func (ae *async_llm_engine) stop_worker() error {
    if !ae.is_running {
        return core.Errorf("async engine worker not running")
    }
    
    ae.is_running = false
    ae.stop_signal <- true
    
    core.Println("async_llm_engine worker stopped")
    return nil
}

func (ae *async_llm_engine) shutdown() error {
    if ae.is_running {
        ae.stop_worker()
    }
    return ae.engine.shutdown()
}

func (ae *async_llm_engine) get_stats() map[string]interface{} {
    stats := ae.engine.get_stats()
    stats["unfinished_requests"] = ae.get_num_unfinished_requests()
    stats["callbacks_pending"] = int32(len(ae.request_callbacks))
    return stats
}
