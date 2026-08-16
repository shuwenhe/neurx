package engine

import "core"
import "tensor"
import "models"

type request_status int32

const (
    request_status_pending   request_status = iota
    request_status_running
    request_status_completed
    request_status_failed
    request_status_cancelled
    request_status_aborted
)

type finish_reason string

const (
    finish_reason_length    finish_reason = "length"
    finish_reason_stop      finish_reason = "stop"
    finish_reason_error     finish_reason = "error"
    finish_reason_abort     finish_reason = "abort"
    finish_reason_prefix    finish_reason = "prefix"
)

struct engine_config {
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
    trust_remote_code       bool
    dtype                   string
    quantization            string
    kv_cache_dtype          string
}

struct sampling_params {
    temperature             float32
    top_p                   float32
    top_k                   int32
    top_n_tokens            int32
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
    seed                    int64
}

struct request_output {
    request_id      string
    prompt          string
    text            []string
    token_ids       [][]int32
    cumulative      bool
    finish_reason   finish_reason
    error_message   string
    output_tokens   int32
    total_tokens    int32
    lm_probs        []interface{}
    created_time    int64
}

struct request_metadata {
    request_id          string
    prompt_tokens       int32
    total_tokens        int32
    estimated_time_ms   float32
}

struct request {
    request_id              string
    prompt                  string
    tokens                  []int32
    sampling_params         sampling_params
    priority                int32
    status                  request_status
    arrival_time            int64
    start_time              int64
    created_time            int64
    updated_time            int64
    output_tokens           []int32
    finished_time           int64
    abort_time              int64
    error                   error
    num_scheduled_tokens    int32
    num_computed_tokens     int32
    lora_request            interface{}
    guided_decode_params    interface{}
}

struct request_queue {
    requests         map[string]*request
    queue            []*request
    priority_queue   []*request
    max_size         int32
    lock             interface{}
}

struct scheduler_output {
    scheduled_requests []*request
    running_requests   []*request
    finished_requests  []*request
}

struct execution_config {
    num_layers              int32
    hidden_size             int32
    num_attention_heads     int32
    num_kv_heads            int32
    vocab_size              int32
    max_seq_len             int32
    device_type             string
    enable_prefix_cache     bool
}

struct llm_engine {
    config                  engine_config
    execution_config        execution_config
    model                   interface{}
    scheduler               interface{}
    kv_cache_manager        interface{}
    device_manager          interface{}
    request_queue           *request_queue
    running_requests        map[string]*request
    outputs                 map[string]*request_output
    request_metadata        map[string]*request_metadata

    total_requests          int64
    total_tokens            int64
    total_output_tokens     int64
    avg_latency_ms          float32
    min_latency_ms          float32
    max_latency_ms          float32
    throughput_tps          float32

    is_initialized          bool
    paused                  bool
    engine_start_time       int64
    num_iterations          int64

    stream_output_callbacks map[string]interface{}
}

struct llm_engine_stats {
    total_requests          int64
    total_tokens            int64
    total_output_tokens     int64
    avg_latency_ms          float32
    min_latency_ms          float32
    max_latency_ms          float32
    throughput_tps          float32
    queue_size              int32
    running_requests        int32
    num_iterations          int64
}

func new_engine_config() engine_config {
    return engine_config{
        model_path:             "",
        model_name:             "",
        tensor_parallel_size:   1,
        pipeline_parallel_size: 1,
        max_batch_size:         256,
        max_num_seqs:           256,
        max_num_tokens:         8192,
        enable_prefix:          false,
        enable_prefix_cache:    false,
        disable_log_probs:      false,
        max_log_probs:          0,
        gpu_memory_utilization: 0.9,
        device_type:            "cuda",
        cpu_offload_gb:         0,
        trust_remote_code:      false,
        dtype:                  "auto",
        quantization:           "none",
        kv_cache_dtype:         "auto",
    }
}

func new_request_queue(max_size int32) *request_queue {
    return &request_queue{
        requests:       make(map[string]*request),
        queue:          make([]*request, 0, max_size),
        priority_queue: make([]*request, 0, max_size),
        max_size:       max_size,
    }
}

func (request_queue* q) add(request* req) error {
    if int32(len(q.queue)) >= q.max_size {
        return core.Errorf("request queue is full (size=%d)", q.max_size)
    }

    q.requests[req.request_id] = req

    if req.priority > 0 {
        q.priority_queue = append(q.priority_queue, req)
    } else {
        q.queue = append(q.queue, req)
    }

    return nil
}

func (request_queue* q) get(request_id string) *request {
    return q.requests[request_id]
}

func (request_queue* q) remove(request_id string) error {
    if _, exists := q.requests[request_id]; !exists {
        return core.Errorf("request not found: %s", request_id)
    }

    delete(q.requests, request_id)

    for i, req := range q.queue {
        if req.request_id == request_id {
            q.queue = append(q.queue[:i], q.queue[i+1:]...)
            return nil
        }
    }

    for i, req := range q.priority_queue {
        if req.request_id == request_id {
            q.priority_queue = append(q.priority_queue[:i], q.priority_queue[i+1:]...)
            return nil
        }
    }

    return nil
}

func (request_queue* q) get_next_batch(batch_size int32) []*request {
    batch := make([]*request, 0, batch_size)

    for len(batch) < int(batch_size) && len(q.priority_queue) > 0 {
        batch = append(batch, q.priority_queue[0])
        q.priority_queue = q.priority_queue[1:]
    }

    for len(batch) < int(batch_size) && len(q.queue) > 0 {
        batch = append(batch, q.queue[0])
        q.queue = q.queue[1:]
    }

    return batch
}

func (request_queue* q) size() int32 {
    return int32(len(q.queue) + len(q.priority_queue))
}

func new_llm_engine(config engine_config) *llm_engine {
    engine := &llm_engine{
        config:                  config,
        request_queue:           new_request_queue(config.max_num_seqs),
        running_requests:        make(map[string]*request),
        outputs:                 make(map[string]*request_output),
        request_metadata:        make(map[string]*request_metadata),
        stream_output_callbacks: make(map[string]interface{}),
        is_initialized:          false,
        paused:                  false,
        min_latency_ms:          1e9,
        max_latency_ms:          0,
        engine_start_time:       core.CurrentTimeMs(),
    }

    return engine
}

func (llm_engine* e) initialize() error {
    if e.is_initialized {
        return nil
    }

    if e.config.model_path == "" {
        return core.Errorf("model_path not specified")
    }

    core.Println("========================")
    core.Println("llm_engine initializing...")
    core.Println("========================")
    core.Printf("  Model: %s\n", e.config.model_path)
    core.Printf("  Dtype: %s\n", e.config.dtype)
    core.Printf("  Quantization: %s\n", e.config.quantization)
    core.Printf("  Max batch size: %d\n", e.config.max_batch_size)
    core.Printf("  Max num seqs: %d\n", e.config.max_num_seqs)
    core.Printf("  Max num tokens: %d\n", e.config.max_num_tokens)
    core.Printf("  Tensor parallel size: %d\n", e.config.tensor_parallel_size)
    core.Printf("  Pipeline parallel size: %d\n", e.config.pipeline_parallel_size)
    core.Printf("  GPU memory utilization: %.2f\n", e.config.gpu_memory_utilization)
    core.Printf("  Device type: %s\n", e.config.device_type)

    e.is_initialized = true
    e.engine_start_time = core.CurrentTimeMs()

    core.Println("llm_engine initialized successfully")
    core.Println("========================")

    return nil
}

func (llm_engine* e) add_request(request_id string, prompt string, sampling_params sampling_params) error {
    if !e.is_initialized {
        return core.Errorf("engine not initialized")
    }

    if e.request_queue.size() >= e.config.max_num_seqs {
        return core.Errorf("request queue full, cannot add more requests (queue_size=%d, max=%d)",
            e.request_queue.size(), e.config.max_num_seqs)
    }

    if request_id == "" {
        request_id = core.GenerateId()
    }

    req := &request{
        request_id:      request_id,
        prompt:          prompt,
        sampling_params: sampling_params,
        status:          request_status_pending,
        arrival_time:    core.CurrentTimeMs(),
        created_time:    core.CurrentTimeMs(),
        priority:        0,
    }

    err := e.request_queue.add(req)
    if err != nil {
        return err
    }

    core.Printf("Request added: %s (prompt_length=%d)\n", request_id, len(prompt))

    return nil
}

func (llm_engine* e) get_request(request_id string) *request {
    if req, exists := e.running_requests[request_id]; exists {
        return req
    }
    return e.request_queue.get(request_id)
}

func (llm_engine* e) step() (bool, error) {
    if !e.is_initialized || e.paused {
        return false, nil
    }

    e.num_iterations++

    batch := e.request_queue.get_next_batch(e.config.max_batch_size)
    if len(batch) == 0 {
        return false, nil
    }

    start_time := core.CurrentTimeMs()

    for _, req := range batch {
        req.status = request_status_running
        req.start_time = start_time
        req.updated_time = start_time
        e.running_requests[req.request_id] = req
    }

    core.Printf("[Iteration %d] Processing batch of %d requests\n", e.num_iterations, len(batch))

    for i, req := range batch {
        req.num_scheduled_tokens = 1
        req.num_computed_tokens = 1

        output := &request_output{
            request_id:    req.request_id,
            prompt:        req.prompt,
            cumulative:    false,
            finish_reason: finish_reason_length,
            created_time:  core.CurrentTimeMs(),
            output_tokens: 10,
            total_tokens:  len(req.prompt) + 10,
            text:          []string{"sample output token " + core.IntToString(i)},
        }

        e.outputs[req.request_id] = output
        req.output_tokens = []int32{1, 2, 3, 4, 5}
        req.status = request_status_completed
        req.finished_time = core.CurrentTimeMs()

        latency_ms := float32(req.finished_time - req.arrival_time)
        e.update_latency_stats(latency_ms)
    }

    for _, req := range batch {
        delete(e.running_requests, req.request_id)
    }

    e.total_requests += int64(len(batch))

    return true, nil
}

func (llm_engine* e) update_latency_stats(latency_ms float32) {
    if latency_ms < e.min_latency_ms {
        e.min_latency_ms = latency_ms
    }
    if latency_ms > e.max_latency_ms {
        e.max_latency_ms = latency_ms
    }

    if e.total_requests > 0 {
        e.avg_latency_ms = (e.avg_latency_ms*float32(e.total_requests-1) + latency_ms) / float32(e.total_requests)
    }
}

func (llm_engine* e) generate_completion(prompt string, sampling_params sampling_params) (string, error) {
    if !e.is_initialized {
        return "", core.Errorf("engine not initialized")
    }

    request_id := core.GenerateId()

    err := e.add_request(request_id, prompt, sampling_params)
    if err != nil {
        return "", err
    }

    max_iterations := int32(100)
    for i := int32(0); i < max_iterations; i++ {
        has_running, err := e.step()
        if err != nil {
            return "", err
        }

        if !has_running {
            break
        }

        output := e.get_output(request_id)
        if output != nil && output.finish_reason != "" && output.finish_reason != "prefix" {
            if len(output.text) > 0 {
                return output.text[0], nil
            }
        }
    }

    output := e.get_output(request_id)
    if output != nil && len(output.text) > 0 {
        return output.text[0], nil
    }

    return "", core.Errorf("failed to generate completion for request: %s", request_id)
}

func (llm_engine* e) get_output(request_id string) *request_output {
    return e.outputs[request_id]
}

func (llm_engine* e) register_stream_callback(request_id string, callback interface{}) {
    e.stream_output_callbacks[request_id] = callback
}

func (llm_engine* e) abort_request(request_id string) error {
    req := e.get_request(request_id)
    if req == nil {
        return core.Errorf("request not found: %s", request_id)
    }

    req.status = request_status_aborted
    req.abort_time = core.CurrentTimeMs()

    delete(e.stream_output_callbacks, request_id)

    return e.request_queue.remove(request_id)
}

func (llm_engine* e) get_num_unfinished_requests() int32 {
    return e.request_queue.size() + int32(len(e.running_requests))
}

func (llm_engine* e) get_stats() llm_engine_stats {
    return llm_engine_stats{
        total_requests:     e.total_requests,
        total_tokens:       e.total_tokens,
        total_output_tokens: e.total_output_tokens,
        avg_latency_ms:     e.avg_latency_ms,
        min_latency_ms:     e.min_latency_ms,
        max_latency_ms:     e.max_latency_ms,
        throughput_tps:     e.throughput_tps,
        queue_size:         e.request_queue.size(),
        running_requests:   int32(len(e.running_requests)),
        num_iterations:     e.num_iterations,
    }
}

func (llm_engine* e) print_stats() {
    stats := e.get_stats()
    core.Println("\n" + "="*60)
    core.Println("llm_engine Statistics")
    core.Println("="*60)
    core.Printf("Total requests processed: %d\n", stats.total_requests)
    core.Printf("Total tokens generated: %d\n", stats.total_tokens)
    core.Printf("Total output tokens: %d\n", stats.total_output_tokens)
    core.Printf("Avg latency: %.2f ms\n", stats.avg_latency_ms)
    core.Printf("Min latency: %.2f ms\n", stats.min_latency_ms)
    core.Printf("Max latency: %.2f ms\n", stats.max_latency_ms)
    core.Printf("Throughput: %.2f tokens/s\n", stats.throughput_tps)
    core.Printf("Queue size: %d\n", stats.queue_size)
    core.Printf("Running requests: %d\n", stats.running_requests)
    core.Printf("Total iterations: %d\n", stats.num_iterations)
    core.Println("="*60 + "\n")
}

func (llm_engine* e) pause() {
    e.paused = true
    core.Println("llm_engine paused")
}

func (llm_engine* e) resume() {
    e.paused = false
    core.Println("llm_engine resumed")
}

func (llm_engine* e) shutdown() error {
    if !e.is_initialized {
        return core.Errorf("engine not initialized")
    }

    e.is_initialized = false
    e.paused = true

    for request_id, req := range e.running_requests {
        req.status = request_status_cancelled
        delete(e.running_requests, request_id)
    }

    e.print_stats()
    core.Println("llm_engine shutdown complete")

    return nil
}

func (llm_engine* e) get_configuration() map[string]interface{} {
    config_map := make(map[string]interface{})
    config_map["model_path"] = e.config.model_path
    config_map["model_name"] = e.config.model_name
    config_map["dtype"] = e.config.dtype
    config_map["quantization"] = e.config.quantization
    config_map["tensor_parallel_size"] = e.config.tensor_parallel_size
    config_map["pipeline_parallel_size"] = e.config.pipeline_parallel_size
    config_map["max_batch_size"] = e.config.max_batch_size
    config_map["max_num_seqs"] = e.config.max_num_seqs
    config_map["max_num_tokens"] = e.config.max_num_tokens
    config_map["enable_prefix_cache"] = e.config.enable_prefix_cache
    config_map["device_type"] = e.config.device_type
    config_map["gpu_memory_utilization"] = e.config.gpu_memory_utilization
    return config_map
}

func (llm_engine* e) warmup() error {
    core.Println("Warming up llm_engine...")

    for i := 0; i < 3; i++ {
        req_id := core.GenerateId()
        err := e.add_request(req_id, "warm up request "+core.IntToString(i), new_default_sampling_params())
        if err != nil {
            return err
        }
    }

    for i := 0; i < 10; i++ {
        has_running, err := e.step()
        if err != nil {
            return err
        }
        if !has_running {
            break
        }
    }

    core.Println("Warmup complete")
    return nil
}

func new_default_sampling_params() sampling_params {
    return sampling_params{
        temperature:        0.7,
        top_p:             0.9,
        top_k:             50,
        top_n_tokens:      5,
        max_tokens:        1024,
        min_tokens:        1,
        repetition_penalty: 1.0,
        frequency_penalty: 0.0,
        presence_penalty:  0.0,
        length_penalty:    1.0,
        early_stop:        false,
        skip_special_tokens: true,
        seed:              -1,
    }
}
