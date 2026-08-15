package engine

import "core"
import "tensor"
import "models"
import "tensor"

type request_status int32

const (
    request_status_pending request_status = iota
    request_status_running
    request_status_completed
    request_status_failed
    request_status_cancelled
)

type engine_config struct {
    model_path              string
    model_name              string
    tensor_parallel_size    int32
    pipeline_parallel_size  int32
    max_batch_size          int32
    max_num_seqs            int32
    max_num_tokens          int32
    enable_prefix           bool
    enable_prefix_cache     bool
    disable_log_probs       bool
    encoded_token_ids       []int32
    max_log_probs           int32
    gpu_memory_utilization  float32
    device_type             string
    cpu_offload_gb          int32
}

type sampling_params struct {
    temperature             float32
    top_p                   float32
    top_k                   int32
    max_tokens              int32
    min_tokens              int32
    repetition_penalty      float32
    frequency_penalty       float32
    presence_penalty        float32
    length_penalty          float32
    early_stop              bool
    stop                    []string
    skip_special_tokens     bool
    spaces_between_special  bool
}

type request_output struct {
    request_id      string
    text            []string
    token_ids       [][]int32
    cumulative      bool
    finish_reason   string
    lm_probs        []interface{}
}

type request struct {
    request_id      string
    prompt          string
    tokens          []int32
    sampling_params sampling_params
    priority        int32
    status          request_status
    arrival_time    int64
    created_time    int64
    updated_time    int64
    output_tokens   []int32
    finished_time   int64
    abort_time      int64
}

type request_queue struct {
    requests map[string]*request
    queue    []*request
    lock     interface{}
    max_size int32
}

type llm_engine struct {
    config              engine_config
    model               interface{}
    scheduler           interface{}
    kv_cache_manager    interface{}
    device_manager      interface{}
    request_queue       *request_queue
    running_requests    map[string]*request
    outputs             map[string]*request_output
    total_requests      int64
    total_tokens        int64
    avg_latency_ms      float32
    throughput_tps      float32
    is_initialized      bool
    paused              bool
}

func new_engine_config() engine_config {
    return engine_config{
        ModelPath:            "",
        ModelName:            "",
        TensorParallelSize:   1,
        PipelineParallelSize: 1,
        MaxBatchSize:         256,
        MaxNumSeqs:           256,
        MaxNumTokens:         8192,
        EnablePrefix:         false,
        EnablePrefixCache:    false,
        DisableLogProbs:      false,
        MaxLogProbs:          0,
        GpuMemoryUtilization: 0.9,
        DeviceType:           "cuda",
        CpuOffloadGB:         0,
    }
}

func new_request_queue(max_size int32) *request_queue {
    return &request_queue{
        requests: make(map[string]*Request),
        queue:    make([]*Request, 0, maxSize),
        maxSize:  maxSize,
    }
}

func (q *request_queue) add(req *request) error {
    if int32(len(q.queue)) >= q.maxSize {
        return core.Errorf("request queue is full")
    }
    q.requests[req.RequestId] = req
    q.queue = append(q.queue, req)
    return nil
}

func (q *request_queue) get(request_id string) *request {
    return q.requests[requestId]
}

func (q *request_queue) remove(request_id string) error {
    if _, exists := q.requests[requestId]; !exists {
        return core.Errorf("request not found: %s", requestId)
    }
    delete(q.requests, requestId)
    for i, req := range q.queue {
        if req.RequestId == requestId {
            q.queue = append(q.queue[:i], q.queue[i+1:]...)
            break
        }
    }
    return nil
}

func (q *request_queue) get_next_batch(batch_size int32) []*request {
    if int32(len(q.queue)) == 0 {
        return make([]*Request, 0)
    }
    
    size := batchSize
    if int32(len(q.queue)) < batchSize {
        size = int32(len(q.queue))
    }
    
    batch := make([]*Request, size)
    for i := int32(0); i < size; i++ {
        batch[i] = q.queue[i]
    }
    return batch
}

func (q *request_queue) size() int32 {
    return int32(len(q.queue))
}

func new_llm_engine(config engine_config) *llm_engine {
    engine := &llm_engine{
        config:          config,
        request_queue:    new_request_queue(config.max_num_seqs),
        running_requests: make(map[string]*request),
        outputs:          make(map[string]*request_output),
        isInitialized:   false,
        paused:          false,
    }
    return engine
}

func (e *llm_engine) initialize() error {
    if e.isInitialized {
        return nil
    }
    
    if e.config.ModelPath == "" {
        return core.Errorf("ModelPath not specified")
    }
    
    core.Println("LLMEngine initializing...")
    core.Printf("  Model: %s\n", e.config.ModelPath)
    core.Printf("  Max batch size: %d\n", e.config.MaxBatchSize)
    core.Printf("  Max num seqs: %d\n", e.config.MaxNumSeqs)
    core.Printf("  Tensor parallel: %d\n", e.config.TensorParallelSize)
    core.Printf("  Pipeline parallel: %d\n", e.config.PipelineParallelSize)
    
    e.isInitialized = true
    core.Println("LLMEngine initialized successfully")
    return nil
}

func (e *llm_engine) add_request(request_id string, prompt string, sampling_params sampling_params) error {
    if !e.isInitialized {
        return core.Errorf("engine not initialized")
    }
    
    if e.requestQueue.Size() >= e.config.MaxNumSeqs {
        return core.Errorf("request queue full, cannot add more requests")
    }
    
    req := &Request{
        RequestId:      requestId,
        Prompt:         prompt,
        SamplingParams: samplingParams,
        Status:         RequestStatusPending,
        ArrivalTime:    core.CurrentTimeMs(),
        CreatedTime:    core.CurrentTimeMs(),
    }
    
    return e.requestQueue.Add(req)
}

func (e *llm_engine) get_request(request_id string) *request {
    if req, exists := e.runningRequests[requestId]; exists {
        return req
    }
    return e.requestQueue.Get(requestId)
}

func (e *llm_engine) step() (bool, error) {
    if !e.isInitialized || e.paused {
        return false, nil
    }
    
    batch := e.requestQueue.GetNextBatch(e.config.MaxBatchSize)
    if len(batch) == 0 {
        return false, nil
    }
    
    for _, req := range batch {
        req.Status = RequestStatusRunning
        req.UpdatedTime = core.CurrentTimeMs()
        e.runningRequests[req.RequestId] = req
    }
    
    core.Printf("Processing batch of %d requests\n", len(batch))
    
    return true, nil
}

func (e *llm_engine) generate_completion(prompt string, sampling_params sampling_params) (string, error) {
    if !e.isInitialized {
        return "", core.Errorf("engine not initialized")
    }
    
    requestId := core.GenerateId()
    
    err := e.AddRequest(requestId, prompt, samplingParams)
    if err != nil {
        return "", err
    }
    
    maxIterations := int32(1000)
    for i := int32(0); i < maxIterations; i++ {
        hasRunning, _ := e.Step()
        
        if !hasRunning {
            break
        }
        
        output := e.GetOutput(requestId)
        if output != nil && output.FinishReason != "" {
            if len(output.Text) > 0 {
                return output.Text[0], nil
            }
        }
    }
    
    return "", core.Errorf("failed to generate completion")
}

func (e *llm_engine) get_output(request_id string) *request_output {
    return e.outputs[requestId]
}

func (e *llm_engine) get_stats() map[string]interface{} {
    stats := make(map[string]interface{})
    stats["total_requests"] = e.totalRequests
    stats["total_tokens"] = e.totalTokens
    stats["avg_latency_ms"] = e.avgLatencyMs
    stats["throughput_tps"] = e.throughputTps
    stats["queue_size"] = e.requestQueue.Size()
    stats["running_requests"] = int32(len(e.runningRequests))
    return stats
}

func (e *llm_engine) pause() {
    e.paused = true
}

func (e *llm_engine) resume() {
    e.paused = false
}

func (e *llm_engine) shutdown() error {
    e.isInitialized = false
    e.paused = true
    
    for requestId, req := range e.runningRequests {
        req.Status = RequestStatusCancelled
        delete(e.runningRequests, requestId)
    }
    
    core.Println("LLMEngine shutdown complete")
    return nil
}
