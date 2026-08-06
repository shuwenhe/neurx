# NeurX Production Inference Framework - 6-Phase Roadmap

## Overview

Comprehensive plan to develop an Ollama-equivalent production inference system with concurrent request handling, dynamic batching, and multi-model support. Estimated timeline: 4 months (80 days full-time development).

**Current Status**: Phase 1 Complete ✅ | Phase 2 In Progress 🔄

---

## Phase 1: HTTP API Layer & Service Infrastructure (COMPLETE ✅)

**Duration**: 2-3 weeks  
**Status**: ✅ IMPLEMENTED (Commit c0f931f6)  
**Lines of Code**: 1,169 lines (pure S)

### Modules Delivered
- **http_server.s** (449 lines) - HTTP protocol implementation, socket management
- **rest_api.s** (280 lines) - RESTful endpoint routing, JSON parsing
- **server.s** (110 lines) - Production server entry point with CLI
- **request_queue.s** (330 lines) - Queue management with priority & retry logic

### Endpoints Implemented
- `POST /api/generate` - Text generation with parameters
- `POST /api/chat/completions` - OpenAI-compatible chat API
- `GET /api/health` - Server health check
- `GET /api/models` - Available models list
- `POST /api/embeddings` - Embedding generation (placeholder)

### Key Features
- Non-blocking socket I/O with system intrinsics
- JSON request/response parsing
- Request queue with priority scheduling
- Timeout handling and automatic retry (max 3 attempts)
- Batch request grouping for parallel processing
- Server status monitoring and metrics collection

### Architecture
```
HTTP Socket → HTTP Parser → REST Router → Request Queue → Inference Engine
                                            ↓
                                         Priority Sort
                                            ↓
                                         Batch Group
```

---

## Phase 2: Concurrent Inference Framework (3-4 weeks)

**Duration**: 3-4 weeks  
**Target Completion**: Week 7 of project  
**Estimated Lines**: 1,200-1,500 lines (pure S)

### Module 1: Concurrency Manager
**File**: `inference/runtime/concurrency_manager.s` (400+ lines)

```s
struct worker {
    int worker_id
    bool is_available
    int processed_requests
    int64 last_active_ms
}

struct thread_pool {
    int num_workers
    []worker workers
    request_queue task_queue
    int total_processed
    bool running
}

func create_thread_pool(int num_workers) thread_pool
func submit_task(thread_pool pool, request_item item) bool
func get_available_worker(thread_pool pool) worker
func mark_worker_busy(thread_pool pool, int worker_id)
func mark_worker_available(thread_pool pool, int worker_id)
func shutdown_thread_pool(thread_pool pool)
func get_pool_stats(thread_pool pool) pool_stats
```

**Key Features**:
- Dynamic worker pool with configurable size (default: 4-8)
- Worker availability tracking
- Load balancing across workers
- Per-worker request metrics
- Graceful shutdown with request draining

### Module 2: Batch Processing Engine
**File**: `inference/runtime/batch_engine.s` (500+ lines)

```s
struct batch_request {
    []string prompts
    []int max_tokens
    []float temperatures
    string batch_id
    int64 created_at_ms
    int batch_size
}

struct batch_engine {
    batch_request current_batch
    int max_batch_size
    int64 batch_timeout_ms
    float dynamic_batch_factor
    bool batching_enabled
}

func create_batch_engine(int max_size, int timeout_ms) batch_engine
func add_to_batch(batch_engine engine, request_item item) batch_request
func should_flush_batch(batch_engine engine, int64 current_ms) bool
func flush_batch(batch_engine engine) batch_request
func process_batch(batch_request batch) []string
func get_engine_stats(batch_engine engine) engine_stats
```

**Key Features**:
- Dynamic batch accumulation with configurable timeout
- Automatic flushing when batch full or timeout reached
- Continuous batching support (new requests arrive while processing)
- Per-request parameter variation within batch
- Batch-level efficiency metrics
- KV cache sharing across batch items (prepared for Phase 3)

### Module 3: Context Manager
**File**: `inference/runtime/context_manager.s` (300+ lines)

```s
struct dialog_turn {
    string role
    string content
    int64 timestamp_ms
}

struct session_context {
    string session_id
    []dialog_turn history
    int total_tokens_generated
    int total_tokens_processed
    int64 created_at_ms
    int64 last_accessed_ms
    string model_name
}

struct context_manager {
    []session_context sessions
    int max_sessions
    int64 session_timeout_ms
    int64 last_cleanup_ms
}

func create_context_manager(int max_sessions) context_manager
func create_session(context_manager manager, string session_id) session_context
func add_turn(context_manager manager, string session_id, dialog_turn turn)
func get_session(context_manager manager, string session_id) session_context
func cleanup_expired_sessions(context_manager manager, int64 current_ms)
func get_session_history(context_manager manager, string session_id) []dialog_turn
func session_exists(context_manager manager, string session_id) bool
func delete_session(context_manager manager, string session_id)
```

**Key Features**:
- Multi-turn dialog history preservation
- Automatic session timeout and cleanup
- Per-session token accounting
- Dialog role tracking (user/assistant)
- Session metadata (creation time, last access)
- Configurable retention policy

### Integration Points

#### 1. Request Queue → Thread Pool
```
request_queue.dequeue() → thread_pool.submit_task()
  → worker becomes unavailable
  → task moved to batch_engine
```

#### 2. Batch Engine → Inference Pipeline
```
batch_engine.flush_batch() 
  → inference/step1_tokenizer.s (batch of prompts)
  → inference/step3_transformer.s (parallel inference)
  → inference/step5_sampling_step6_decode.s (batch decode)
  → collect results[]
```

#### 3. Context Manager → REST API
```
rest_api.handle_generate()
  1. Extract session_id from request headers
  2. Get or create context from context_manager
  3. Add user query to session history
  4. Queue request with session context
  5. When response ready, add assistant turn
  6. Return response with session metadata
```

### Success Criteria
- ✅ Support 100+ concurrent connections
- ✅ Maintain <50ms queue latency (p95)
- ✅ Achieve 50+ tokens/second throughput
- ✅ Preserve dialog context across requests
- ✅ Automatic session cleanup after 1 hour inactivity

### Testing Strategy
1. Unit tests for each module
2. Integration tests with Phase 1 APIs
3. Load testing with simulated concurrent connections
4. Memory profiling for session retention

---

## Phase 3: Performance Optimization (2-3 weeks)

**Duration**: 2-3 weeks  
**Target Completion**: Week 10 of project

### Performance Targets
- First token latency: <100ms
- Throughput: 100+ tokens/second
- Batch efficiency: 85%+ GPU utilization
- Memory footprint: <2GB

### Modules

#### 1. BLAS Backend Integration
**File**: `inference/backends/blas_backend_v2.s`

- Integrate with system BLAS libraries (OpenBLAS, MKL)
- Fallback to CPU-native implementations
- Provider auto-detection
- Performance profiling per operation

#### 2. Cache Optimization
**File**: `inference/cache/optimized_kv_cache.s`

- Persistent KV cache for multi-turn inference
- Reuse cache across batch items
- Eviction policy for cache memory management
- Cache hit metrics

#### 3. SIMD Kernels
**File**: `inference/simd/simd_ops.s`

- AVX-512 / AVX-2 optimized matrix operations
- NEON for ARM platforms
- Fallback to scalar implementations
- Kernel selection at runtime based on CPU capabilities

#### 4. Quantization Support
**File**: `inference/quantization/int8_ops.s`

- INT8 weight quantization
- Dynamic activation quantization
- Dequantization in forward pass
- 4x memory reduction, ~20% speed loss

### Integration
- Swap native_backend calls to blas_backend
- Enable KV cache in transformer layers
- Profile and identify hotspots
- Apply SIMD kernels to top 20% of compute time

---

## Phase 4: Configuration & Model Management (1-2 weeks)

**Duration**: 1-2 weeks  
**Target Completion**: Week 12 of project

### Modules

#### 1. Model Manager
**File**: `inference/model/model_manager.s`

```s
struct model_config {
    string model_path
    string model_name
    int hidden_dim
    int num_layers
    int vocab_size
    string quantization_type
}

func load_model(string path) model_config
func list_available_models() []string
func switch_active_model(string model_name) bool
func get_model_stats() model_stats
```

#### 2. YAML Configuration Parser
**File**: `inference/config/yaml_parser.s`

```
inference:
  host: "0.0.0.0"
  port: 8000
  num_workers: 8
  max_batch_size: 32
  batch_timeout_ms: 100

model:
  base_path: "/home/shuwen/shuwen/posttrain"
  quantization: "none"

sampling:
  temperature: 0.7
  top_p: 0.95
  top_k: 50
```

#### 3. Advanced Sampling Strategies
**File**: `inference/sampling/advanced_sampling.s`

- Nucleus sampling (top-p)
- Top-k sampling
- Temperature scaling
- Beam search (multi-beam decoding)
- Penalty for repeated tokens

#### 4. Logging & Tracing
**File**: `inference/observability/structured_logging.s`

- Structured log output (JSON)
- Log levels: DEBUG, INFO, WARN, ERROR
- Request tracing with unique IDs
- Performance timing for each stage

---

## Phase 5: Monitoring & Diagnostics (1-2 weeks)

**Duration**: 1-2 weeks  
**Target Completion**: Week 14 of project

### Modules

#### 1. Metrics Collection
**File**: `inference/monitoring/metrics_collector.s`

- Per-request latency distribution (p50, p95, p99)
- Throughput (tokens/sec, requests/sec)
- Queue depth over time
- Worker utilization histogram
- Cache hit rate
- Error rates by type

#### 2. Health Check System
**File**: `inference/monitoring/health_checker.s`

```s
struct health_status {
    bool memory_ok
    bool disk_ok
    bool gpu_ok
    bool model_loaded
    bool api_responding
    string overall_status
}

func check_system_health() health_status
```

#### 3. Profiler
**File**: `inference/profiling/profiler.s`

- Per-stage timing breakdown
- Memory allocation tracking
- Hotspot identification
- Comparative profiling (Phase 2 vs Phase 3)

#### 4. Alert System
**File**: `inference/monitoring/alerting.s`

- CPU/Memory threshold alerts
- Queue depth warnings
- Error rate anomalies
- Model inference failures

---

## Phase 6: Advanced Features (2-3 weeks)

**Duration**: 2-3 weeks  
**Target Completion**: Week 18 of project

### 1. Long Context Support
- Sliding window attention
- Recurrent attention mechanisms
- Context compression (summary + recent window)
- Maximum context: 4K → 32K tokens

### 2. Adaptive Inference
- Dynamic batch sizing based on latency targets
- Automatic precision reduction under load
- Request prioritization based on deadline

### 3. Multi-Model Serving
- Load multiple models concurrently
- Model-specific routing rules
- Shared resource management

### 4. Distributed Inference
- Tensor parallelism across multiple machines
- Sequence parallelism for long contexts
- Pipeline parallelism for model stages

### 5. Model Optimization Pipeline
- Automatic knowledge distillation
- Layer pruning with fine-tuning
- Operator fusion for compiled inference

---

## Implementation Timeline

```
Week 1-3:   Phase 1 (API Layer) ✅ COMPLETE
Week 4-7:   Phase 2 (Concurrency)
Week 8-10:  Phase 3 (Performance)
Week 11-12: Phase 4 (Configuration)
Week 13-14: Phase 5 (Monitoring)
Week 15-18: Phase 6 (Advanced)
```

## Git Commit Strategy

All development on **main** branch. No feature branches.

Commit pattern:
```
feat: Phase X - <specific module>
Implemented <module name> with <key features>
- Feature 1
- Feature 2
- Feature 3

Lines: XXX
Status: Testing | Ready for integration | Production
```

## Success Metrics (Final System)

| Metric | Target | Verification |
|--------|--------|--------------|
| Concurrent connections | 1000+ | Load test with concurrent clients |
| First token latency | <100ms | Measure in production workload |
| Throughput | 100+ tok/s | Benchmark on reference hardware |
| P95 queue latency | <50ms | Request queue statistics |
| API availability | 99.5%+ | Health check monitoring |
| Memory footprint | <2GB | System profiler |
| Inference accuracy | >99% | Compare outputs with reference |

## Technology Stack

- **Language**: Pure S (no Python, no Shell)
- **Networking**: System socket APIs (`__sys_*` intrinsics)
- **Concurrency**: User-space thread pool (cooperative scheduling)
- **Data Format**: SafeTensors for model weights
- **Protocol**: HTTP/1.1 for API
- **Storage**: File-based model loading and session persistence
- **Monitoring**: In-process metrics collection (no external deps)

## Next Steps

1. ✅ Complete Phase 1 (HTTP API) - DONE
2. 🔄 Start Phase 2 (Concurrency) - IN PROGRESS
   - Create concurrency_manager.s
   - Create batch_engine.s
   - Create context_manager.s
   - Integrate with rest_api.s and inference pipeline
3. Schedule Phase 3 for Week 8
4. Weekly progress reviews

---

**Last Updated**: 2026-08-06  
**Author**: NeurX Development Team  
**Status**: Phase 1 Complete, Phase 2 Ready to Start
