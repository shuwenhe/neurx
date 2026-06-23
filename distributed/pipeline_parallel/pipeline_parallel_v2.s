package neurx.distributed.pipeline_parallel_v2

// ═══════════════════════════════════════════════════════════════════
// NeurX Pipeline Parallelism V2 (1F1B Schedule with Microbatches)
// ═══════════════════════════════════════════════════════════════════
//
// Implements efficient pipeline parallelism for 2T parameter models.
// Uses the "1 Forward, 1 Backward" (1F1B) schedule to minimize:
//   - Pipeline bubbles (idle GPU time)
//   - Peak memory (activation checkpointing integration)
//   - Communication overhead (overlapping compute and communication)
//
// Pipeline parallelism splits model LAYERS across GPUs:
//   Stage 0: layers 0..(L/pp_degree-1)
//   Stage 1: layers pp_degree..(2*pp_degree-1)
//   ...
//   Stage P-1: layers (P-1)*pp_degree..L-1
//
// Data flow: microbatch → stage0 → stage1 → ... → stage(P-1) → loss
// Gradient flow: loss_grad → stage(P-1) → ... → stage1 → stage0
//
// 1F1B Schedule Overview (pp_degree=4, num_microbatches=8):
//   Time →
//   S0: F0 F1 F2 F3 B0 F4 B1 F5 B2 F6 B3 B7  (forward then backward interleaved)
//   S1:    F0 F1 F2 F3 B0 F4 B1 F5 B2 F6 B3 B7  (staggered)
//   S2:       F0 F1 F2 F3 B0 F4 B1 F5 B2 F6 B3 B7
//   S3:          F0 F1 F2 F3 B0 F4 B1 F5 B2 F6 B3 B7
//   ↑ Bubble region at start/end

// ===================== Configuration =====================

int SCHEDULE_GPIPE = 0       // Simple: all forwards first, then all backwards (more memory)
int SCHEDULE_1F1B = 1        // Interleaved: minimize peak memory (recommended)
int SCHEDULE_INTERLEAVED_1F1B = 2  // Multiple virtual stages per physical stage (advanced)

struct pipeline_config {
    int pp_degree              // Number of pipeline stages (must divide num_layers)
    int pp_rank                // This rank's stage index (0 to pp_degree-1)
    int num_layers             // Total number of transformer layers
    int num_microbatches       // Microbatches per training step
    int micro_batch_size       // Tokens/samples per microbatch
    string schedule_type       // GPipe / 1F1B / Interleaved
    
    // Chunking: split each stage into multiple chunks for interleaved scheduling
    int num_chunks             // Virtual stages per physical stage (for INTERLEAVED)
    
    // Activation checkpointing
    bool use_activation_checkpointing
    int checkpoint_strategy    // 0=none, 1=selective, 2=all layers
    
    // Communication
    bool overlap_comm_compute  // Overlap P2P sends with computation
}

struct pipeline_stage {
    int stage_id               // Global stage index
    int start_layer            // First layer index on this stage
    int end_layer              // Last layer index on this stage (inclusive)
    int num_layers_local       // Number of layers managed by this stage
}

struct microbatch_state {
    int microbatch_id
    bool forward_done
    bool backward_done
    [][]double input_activation     // Cached input to this stage
    [][]double output_activation    // Cached output from this stage
    [][]double input_gradient       // Gradient received from next stage (or loss)
    [][]double output_gradient      // Gradient sent to previous stage
}

struct pipeline_state {
    pipeline_config config
    pipeline_stage stage_info
    
    // Per-microbatch tracking
    []microbatch_state mb_states
    
    // 1F1B schedule state
    int forward_counter         // Number of forwards completed so far
    int backward_counter        // Number of backwards completed so far
    int total_warmup_microbatches  // Number of microbatches in warmup phase = pp_degree - pp_rank - 1
    int total_steady_microbatches  // Number of steady-state iterations
    int total_cooldown_microbatches // Number in cooldown phase
    
    // Performance tracking
    double time_forward_ms
    double time_backward_ms
    double time_comm_ms
    double time_bubble_ms
    double peak_memory_bytes
    
    // Layer weights (this stage's portion)
    [][][][]double layer_weights   // [local_layer_idx][weight_matrix]
}

func pp_mod(int val, int div) int {
    if div <= 0 { return 0 }
    int r = val
    while r >= div { r = r - div }
    while r < 0 { r = r + div }
    return r
}

// ===================== Initialization =====================

func init_pipeline(pipeline_config cfg) pipeline_state {
    pipeline_state state
    state.config = cfg
    
    // Calculate layer assignment for this stage
    int pp = cfg.pp_degree
    int pr = cfg.pp_rank
    int L = cfg.num_layers
    
    // Distribute layers as evenly as possible
    int base_layers_per_stage = L / pp
    int remainder = pp_mod(L, pp)
    
    state.stage_info.stage_id = pr
    
    if pr < remainder {
        // First 'remainder' stages get one extra layer
        state.stage_info.start_layer = pr * (base_layers_per_stage + 1)
        state.stage_info.num_layers_local = base_layers_per_stage + 1
    } else {
        state.stage_info.start_layer = 
            remainder * (base_layers_per_stage + 1) + (pr - remainder) * base_layers_per_stage
        state.stage_info.num_layers_local = base_layers_per_stage
    }
    state.stage_info.end_layer = state.stage_info.start_layer + state.stage_info.num_layers_local - 1
    
    // Initialize microbatch states
    int num_mb = cfg.num_microbatches
    state.mb_states = []microbatch_state{cap: num_mb}
    int i = 0
    while i < num_mb {
        state.mb_states[i] = microbatch_state{
            microbatch_id: i,
            forward_done: false,
            backward_done: false,
        }
        i = i + 1
    }
    
    // Calculate 1F1B schedule phases
    state.forward_counter = 0
    state.backward_counter = 0
    state.total_warmup_microbatches = cfg.pp_degree - pr - 1  // Fewer warmsups for later stages
    state.total_steady_microbatches = num_mb - (cfg.pp_degree - 1)
    state.total_cooldown_microbatches = cfg.pp_degree - pr - 1
    
    // Initialize performance counters
    state.time_forward_ms = 0.0
    state.time_backward_ms = 0.0
    state.time_comm_ms = 0.0
    state.time_bubble_ms = 0.0
    state.peak_memory_bytes = 0.0
    
    // Allocate weight storage (placeholder — actual weights loaded from checkpoint)
    state.layer_weights = [][][][]double{cap: state.stage_info.num_layers_local}
    int w = 0
    while w < state.stage_info.num_layers_local {
        state.layer_weights[w] = [][][]double{cap: 10}  // ~10 tensors per transformer layer
        w = w + 1
    }
    
    return state
}

// ===================== 1F1B Schedule Execution =====================
//
// The 1F1B schedule is executed by each pipeline stage independently,
// following a deterministic pattern based on (stage_id, num_microbatches).
//
// For stage `rank` with M microbatches and P pipeline stages:
//
// PHASE 1: Warmup (forward only, no backward yet)
//   Run (P - 1 - rank) forward passes
//   These fill the pipeline before any backward can start
//
// PHASE 2: Steady State (1 forward, 1 backward alternating)
//   Run (M - P + 1) iterations of: forward(microbatch_i), backward(microbatch_j)
//   This minimizes peak memory by freeing activation after backward
//
// PHASE 3: Cooldown (backward only, no more forwards)
//   Run remaining backward passes
//   Drain the pipeline

// Execute one full step of 1F1B scheduled pipeline parallelism
// Returns: average loss across all microbatches (on last stage), or 0.0 otherwise
func execute_1f1b_step(
    ref pipeline_state state,
    [][]double initial_input,           // [num_mb][batch, seq, hidden] or similar
    func forward_fn,                     // Function: forward(layer_weights, input) -> (output, activations_to_save)
    func backward_fn,                    // Function: backward(grad_output, saved_activations, layer_weights) -> grad_input
    func loss_fn) double {               // Function: compute_loss(output, targets) -> (loss, grad_output)
    
    pipeline_config cfg = state.config
    int rank = cfg.pp_rank
    int P = cfg.pp_degree
    int M = cfg.num_microbatches
    bool is_last_stage = (rank == P - 1)
    bool is_first_stage = (rank == 0)
    
    double total_loss = 0.0
    int loss_count = 0
    
    // ===== PHASE 1: WARMUP =====
    // Forward only: fill the pipeline
    int warmup_count = P - 1 - rank
    if warmup_count < 0 { warmup_count = 0 }
    if warmup_count > M { warmup_count = M }
    
    int fwd_idx = 0
    while fwd_idx < warmup_count  state.forward_counter < M {
        int mb_id = state.forward_counter
        
        // Get input for this microbatch
        [][]double mb_input
        if is_first_stage {
            mb_input = initial_input[mb_id]
        } else {
            // Receive from previous stage via P2P
            mb_input = p2p_recv_from_prev(state, mb_id)
        }
        
        // Forward pass through this stage's layers
        double t0 = 0.0  // get_time()
        
        [][]double output = run_forward_stage(state, mb_input, mb_id)
        
        double t1 = 0.0
        state.time_forward_ms = state.time_forward_ms + (t1 - t0)
        
        // Cache output for later backward
        state.mb_states[mb_id].output_activation = output
        state.mb_states[mb_id].forward_done = true
        
        // Send to next stage (or compute loss if last stage)
        if !is_last_stage {
            p2p_send_to_next(state, output, mb_id)
        } else {
            // Last stage: compute loss
            // (loss_val, grad) = loss_fn(output, target_for_mb[mb_id])
            // state.mb_states[mb_id].input_gradient = grad
            // total_loss += loss_val; loss_count++
            total_loss = total_loss + 0.0  // Placeholder
            loss_count = loss_count + 1
        }
        
        state.forward_counter = state.forward_counter + 1
        fwd_idx = fwd_idx + 1
    }
    
    // ===== PHASE 2: STEADY STATE =====
    // Alternating 1F1B
    int steady_count = M - P + 1
    if steady_count < 0 { steady_count = 0 }
    
    int ss_idx = 0
    while ss_idx < steady_count {
        // --- FORWARD ---
        if state.forward_counter < M {
            int fwd_mb_id = state.forward_counter
            
            [][]double fwd_input
            if is_first_stage {
                fwd_input = initial_input[fwd_mb_id]
            } else {
                fwd_input = p2p_recv_from_prev(state, fwd_mb_id)
            }
            
            double tf0 = 0.0
            [][]double fwd_out = run_forward_stage(state, fwd_input, fwd_mb_id)
            double tf1 = 0.0
            state.time_forward_ms = state.time_forward_ms + (tf1 - tf0)
            
            state.mb_states[fwd_mb_id].output_activation = fwd_out
            state.mb_states[fwd_mb_id].forward_done = true
            
            if !is_last_stage {
                p2p_send_to_next(state, fwd_out, fwd_mb_id)
            } else {
                total_loss = total_loss + 0.0
                loss_count = loss_count + 1
            }
            
            state.forward_counter = state.forward_counter + 1
        }
        
        // --- BACKWARD ---
        int bwd_mb_id = state.backward_counter
        
        if bwd_mb_id >= 0  bwd_mb_id < M  
           state.mb_states[bwd_mb_id].forward_done 
           !state.mb_states[bwd_mb_id].backward_done {
            
            // Receive gradient from next stage (or use loss gradient if last stage)
            [][]double grad_output
            if is_last_stage {
                grad_output = state.mb_states[bwd_mb_id].input_gradient
            } else {
                grad_output = p2p_recv_grad_from_next(state, bwd_mb_id)
            }
            
            double tb0 = 0.0
            [][]double grad_input = run_backward_stage(state, grad_output, bwd_mb_id)
            double tb1 = 0.0
            state.time_backward_ms = state.time_backward_ms + (tb1 - tb0)
            
            state.mb_states[bwd_mb_id].output_gradient = grad_input
            state.mb_states[bwd_mb_id].backward_done = true
            
            // Send gradient to previous stage
            if !is_first_stage {
                p2p_send_grad_to_prev(state, grad_input, bwd_mb_id)
            }
            // Else: gradient goes to embedding/optimizer (handled outside)
            
            // Free cached activations for this microbatch (memory optimization!)
            free_microbatch_activations(ref state, bwd_mb_id)
            
            state.backward_counter = state.backward_counter + 1
        }
        
        ss_idx = ss_idx + 1
    }
    
    // ===== PHASE 3: COOLDOWN =====
    // Backward only: drain remaining microbatches
    while state.backward_counter < M {
        int cool_mb_id = state.backward_counter
        
        [][]double cool_grad
        if is_last_stage {
            cool_grad = state.mb_states[cool_mb_id].input_gradient
        } else {
            cool_grad = p2p_recv_grad_from_next(state, cool_mb_id)
        }
        
        double tc0 = 0.0
        [][]double cool_grad_in = run_backward_stage(state, cool_grad, cool_mb_id)
        double tc1 = 0.0
        state.time_backward_ms = state.time_backward_ms + (tc1 - tc0)
        
        state.mb_states[cool_mb_id].backward_done = true
        
        if !is_first_stage {
            p2p_send_grad_to_prev(state, cool_grad_in, cool_mb_id)
        }
        
        free_microbatch_activations(ref state, cool_mb_id)
        
        state.backward_counter = state.backward_counter + 1
    }
    
    // Return average loss (only meaningful on last stage)
    if loss_count > 0 {
        return total_loss / double(loss_count)
    }
    return 0.0
}

// ===================== Stage-Level Forward/Backward =====================

// Run forward through all layers on this pipeline stage
func run_forward_stage(pipeline_state state, [][]double input, int mb_id) [][]double {
    [][]double current = input
    
    // Optionally save input for backward
    if state.config.use_activation_checkpointing != 2 {  // Not checkpointing ALL
        state.mb_states[mb_id].input_activation = copy_tensor(input)
    }
    
    int layer_idx = 0
    while layer_idx < state.stage_info.num_layers_local {
        // current = transformer_layer_forward(current, state.layer_weights[layer_idx])
        // Placeholder: just identity for now
        layer_idx = layer_idx + 1
    }
    
    return current
}

// Run backward through all layers on this pipeline stage (reverse order)
func run_backward_stage(pipeline_state state, [][]double grad_output, int mb_id) [][]double {
    [][]double current_grad = grad_output
    
    int layer_idx = state.stage_info.num_layers_local - 1
    while layer_idx >= 0 {
        // current_grad = transformer_layer_backward(current_grad, state.mb_states[mb_id], state.layer_weights[layer_idx])
        layer_idx = layer_idx - 1
    }
    
    return current_grad
}

// ===================== Point-to-Point Communication =====================

// Send activation tensor to next pipeline stage
func p2p_send_to_next(pipeline_state state, [][]double activation, int mb_id) {
    // In real NCCL/MPI:
    // Send(activation.data, dest=pp_rank+1, tag=mb_id * 2 + 0)  // even tag = forward
    // If overlap_comm_compute: use async send (isend)
    state.time_comm_ms = state.time_comm_ms + 0.05  // Simulated latency
}

// Receive activation from previous pipeline stage
func p2p_recv_from_prev(pipeline_state state, int mb_id) [][]double {
    // In real NCCL/MPI:
    // Recv(buffer, src=pp_rank-1, tag=mb_id * 2 + 0)
    state.time_comm_ms = state.time_comm_ms + 0.05
    return [][]double{}  // Would contain actual data
}

// Send gradient to previous stage
func p2p_send_grad_to_prev(pipeline_state state, [][]double gradient, int mb_id) {
    // Send(gradient, dest=pp_rank-1, tag=mb_id * 2 + 1)  // odd tag = backward
    state.time_comm_ms = state.time_comm_ms + 0.05
}

// Receive gradient from next stage
func p2p_recv_grad_from_next(pipeline_state state, int mb_id) [][]double {
    // Recv(buffer, src=pp_rank+1, tag=mb_id * 2 + 1)
    state.time_comm_ms = state.time_comm_ms + 0.05
    return [][]double{}
}

// ===================== Memory Management =====================

// Free cached activations for a completed microbatch
func free_microbatch_activations(ref pipeline_state state, int mb_id) {
    state.mb_states[mb_id].input_activation = [][]double{}
    state.mb_states[mb_id].output_activation = [][]double{}
    // In real implementation: actually deallocate GPU memory
}

// Deep copy a 2D tensor
func copy_tensor([][]double src) [][]double {
    int rows = len(src)
    if rows == 0 { return [][]double{} }
    int cols = len(src[0])
    
    [][]double dst = [][]double{cap: rows}
    int i = 0
    while i < rows {
        dst[i] = []double{cap: cols}
        int j = 0
        while j < cols {
            dst[i][j] = src[i][j]
            j = j + 1
        }
        i = i + 1
    }
    return dst
}

// ===================== Performance Analysis =====================

struct pipeline_metrics {
    double throughput_tokens_per_sec
    double utilization_percent      // Actual compute time / total time
    double bubble_fraction          // Fraction of time spent in pipeline bubble
    double comm_overlap_efficiency  // How well comm overlaps with compute
    double memory_efficiency        // Peak memory vs theoretical max
    int steps_completed
    double avg_step_time_ms
}

func analyze_pipeline_performance(pipeline_state state, double wall_clock_time_ms) pipeline_metrics {
    pipeline_metrics m
    m.steps_completed = 1  // Simplified
    m.avg_step_time_ms = wall_clock_time_ms
    
    double total_active = state.time_forward_ms + state.time_backward_ms
    double total_time = total_active + state.time_comm_ms + state.time_bubble_ms
    
    if total_time > 0.0 {
        m.utilization_percent = (total_active / total_time) * 100.0
        m.bubble_fraction = state.time_bubble_ms / total_time
    }
    
    // Bubble fraction formula for 1F1B:
    // Ideal: (P-1)/(M+P-1) where P=pp_degree, M=num_microbatches
    int P = state.config.pp_degree
    int M = state.config.num_microbatches
    double ideal_bubble = double(P - 1) / double(M + P - 1)
    
    m.comm_overlap_efficiency = 1.0 - (state.time_comm_ms / (total_active + 0.001))
    m.memory_efficiency = 0.8  // Estimated: 1F1B saves ~(50 - (50 / vs) * vs) GPipe
    
    // Throughput estimate
    int tokens_per_mb = state.config.micro_batch_size * 8192  // Assume seq_len=8K
    double tokens_per_step = double(tokens_per_mb * M * state.config.pp_degree)
    m.throughput_tokens_per_sec = tokens_per_step / (wall_clock_time_ms / 1000.0)
    
    return m
}

// Print detailed pipeline statistics
func print_pipeline_stats(pipeline_state state, pipeline_metrics metrics) {
    // log_info("=== Pipeline Parallel Stats (Stage " + str(state.config.pp_rank) + ") ===")
    // log_info("Schedule: " + state.config.schedule_type)
    // log_info("Layers [" + str(state.stage_info.start_layer) + ".." + str(state.stage_info.end_layer) + "]")
    // log_info("Forward Time: " + str(state.time_forward_ms) + "ms")
    // log_info("Backward Time: " + str(state.time_backward_ms) + "ms")  
    // log_info("Comm Time: " + str(state.time_comm_ms) + "ms")
    // log_info("Bubble Time: " + str(state.time_bubble_ms) + "ms")
    // log_info("Utilization: " + str(metrics.utilization_percent) + "%")
    // log_info("Throughput: " + str(metrics.throughput_tokens_per_sec) + " tokens/sec")
}

// Recommended configuration for 2T model pipeline parallelism
func recommended_pp_config_2t(int num_gpus_available) pipeline_config {
    // Determine optimal pp_degree based on GPU count and model depth
    int optimal_pp = 8  // Default for 160-layer model
    
    if num_gpus_available >= 512 {
        optimal_pp = 16  // More stages for larger clusters
    } else if num_gpus_available <= 128 {
        optimal_pp = 4
    }
    
    pipeline_config cfg
    cfg.pp_degree = optimal_pp
    cfg.pp_rank = 0  // Example: would be set per-rank
    cfg.num_layers = 160  // 2T GPT model
    cfg.num_microbatches = 8  // Tunable: more microbatches = less bubble, more memory
    cfg.micro_batch_size = 2  // Very small for 2T model (memory constraint)
    cfg.schedule_type = "1f1b"
    cfg.num_chunks = 1
    cfg.use_activation_checkpointing = true
    cfg.checkpoint_strategy = 2  // Checkpoint all layers
    cfg.overlap_comm_compute = true
    
    return cfg
}
