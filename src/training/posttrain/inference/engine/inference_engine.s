package neurx.posttrain.inference.engine
use neurx.tensor.{tensor, tensor_ops}
use neurx.nn.{module}

struct inference_config {
    int max_num_batched_tokens
    int max_num_seqs
    int max_model_len
    float gpu_memory_utilization
    int block_size
    bool swap_space_enabled
    int num_gpu_blocks
    int num_cpu_blocks
    bool use_v2_block_manager
    string dtype
    int tensor_parallel_size
}

struct inference_sequence {
    int seq_id
    []int token_ids
    int prompt_len
    int output_len
    int max_tokens
    float temperature
    float top_p
    int top_k
    bool finished
}

struct cache_block {
    int block_id
    []int token_ids
    int ref_count
    bool is_gpu
}

struct block_cache_table {
    []int[] seq_block_tables
    []cache_block blocks
    int num_free_gpu_blocks
    int num_free_cpu_blocks
}

struct scheduler_output {
    []int scheduled_seq_ids
    []int num_tokens_per_seq
    int total_tokens
    bool is_prompt_phase
}

struct inference_engine {
    module model
    inference_config config
    block_cache_table block_table
    []inference_sequence sequences
    int next_seq_id
}

func new_inference_config() inference_config {
    inference_config {
        max_num_batched_tokens: 2048,
        max_num_seqs: 256,
        max_model_len: 4096,
        gpu_memory_utilization: 0.9,
        block_size: 16,
        swap_space_enabled: true,
        num_gpu_blocks: 1024,
        num_cpu_blocks: 2048,
        use_v2_block_manager: true,
        dtype: "float16",
        tensor_parallel_size: 1,
    }
}

func allocate_block(block_cache_table table, bool is_gpu) int {
    if is_gpu && table.num_free_gpu_blocks > 0 {
        int i = 0
        for i < table.blocks.len {
            if table.blocks[i].is_gpu && table.blocks[i].ref_count == 0 {
                table.blocks[i].ref_count = 1
                table.num_free_gpu_blocks = table.num_free_gpu_blocks - 1
                return i
            }
            i = i + 1
        }
    } else if !is_gpu && table.num_free_cpu_blocks > 0 {
        int i = 0
        for i < table.blocks.len {
            if !table.blocks[i].is_gpu && table.blocks[i].ref_count == 0 {
                table.blocks[i].ref_count = 1
                table.num_free_cpu_blocks = table.num_free_cpu_blocks - 1
                return i
            }
            i = i + 1
        }
    }
    return -1
}

func free_block(block_cache_table table, int block_id) {
    if block_id >= 0 && block_id < table.blocks.len {
        table.blocks[block_id].ref_count = table.blocks[block_id].ref_count - 1
        if table.blocks[block_id].ref_count == 0 {
            if table.blocks[block_id].is_gpu {
                table.num_free_gpu_blocks = table.num_free_gpu_blocks + 1
            } else {
                table.num_free_cpu_blocks = table.num_free_cpu_blocks + 1
            }
        }
    }
}

func schedule_sequences(
    inference_engine engine
) scheduler_output {
    []int scheduled = make([]int, engine.config.max_num_seqs)
    []int num_tokens = make([]int, engine.config.max_num_seqs)
    int total_tokens = 0
    bool is_prompt = false
    int i = 0
    for i < engine.sequences.len {
        inference_sequence seq = engine.sequences[i]
        if seq.finished {
            i = i + 1
            continue
        }
        bool seq_is_prompt = seq.output_len == 0
        int tokens_needed = 1
        if seq_is_prompt {
            tokens_needed = seq.prompt_len
        }
        if total_tokens + tokens_needed <= engine.config.max_num_batched_tokens {
            scheduled[scheduled.len] = seq.seq_id
            num_tokens[num_tokens.len] = tokens_needed
            total_tokens = total_tokens + tokens_needed
            if seq_is_prompt {
                is_prompt = true
            }
        }
        i = i + 1
    }
    scheduler_output {
        scheduled_seq_ids: scheduled,
        num_tokens_per_seq: num_tokens,
        total_tokens: total_tokens,
        is_prompt_phase: is_prompt,
    }
}

func paged_attention(
    tensor query,
    tensor key_cache,
    tensor value_cache,
    []int[] block_tables,
    []int context_lens,
    int block_size
) tensor {
    int batch_size = query.shape[0]
    int num_heads = query.shape[1]
    int head_dim = query.shape[2]
    tensor output = tensor_ops.zeros([batch_size, num_heads, head_dim])
    int b = 0
    for b < batch_size {
        []int blocks = block_tables[b]
        int context_len = context_lens[b]
        int num_blocks = (context_len + block_size - 1) / block_size
        []tensor attn_scores = make([]tensor, num_blocks)
        int block_idx = 0
        for block_idx < num_blocks {
            int block_id = blocks[block_idx]
            tensor k_block = tensor_ops.index_select(
                key_cache,
                0,
                block_id
            )
            tensor v_block = tensor_ops.index_select(
                value_cache,
                0,
                block_id
            )
            tensor q_b = tensor_ops.index_select(query, 0, b)
            tensor score = tensor_ops.matmul(
                q_b,
                tensor_ops.transpose(k_block, -2, -1)
            )
            float scale = 1.0 / (head_dim * 1.0)
            score = tensor_ops.mul_scalar(score, scale)
            attn_scores[block_idx] = score
            block_idx = block_idx + 1
        }
        tensor all_scores = tensor_ops.concat(attn_scores, -1)
        tensor attn_weights = tensor_ops.softmax(all_scores, -1)
        tensor attn_output = tensor_ops.zeros([num_heads, head_dim])
        block_idx = 0
        for block_idx < num_blocks {
            int block_id = blocks[block_idx]
            tensor v_block = tensor_ops.index_select(
                value_cache,
                0,
                block_id
            )
            int start = block_idx * block_size
            int end = start + block_size
            tensor weights_block = tensor_ops.slice(
                attn_weights,
                -1,
                start,
                end
            )
            tensor contrib = tensor_ops.matmul(weights_block, v_block)
            attn_output = tensor_ops.add(attn_output, contrib)
            block_idx = block_idx + 1
        }
        output = tensor_ops.index_copy(output, 0, b, attn_output)
        b = b + 1
    }
    output
}

func generate(
    inference_engine engine,
    []int[] prompts,
    int max_tokens,
    float temperature,
    float top_p
) []int[] {
    int i = 0
    for i < prompts.len {
        inference_sequence seq = inference_sequence {
            seq_id: engine.next_seq_id,
            token_ids: prompts[i],
            prompt_len: prompts[i].len,
            output_len: 0,
            max_tokens: max_tokens,
            temperature: temperature,
            top_p: top_p,
            top_k: 0,
            finished: false,
        }
        engine.sequences[engine.sequences.len] = seq
        engine.next_seq_id = engine.next_seq_id + 1
        i = i + 1
    }
    bool all_finished = false
    for !all_finished {
        scheduler_output sched = schedule_sequences(engine)
        if sched.scheduled_seq_ids.len == 0 {
            break
        }
        all_finished = true
        int j = 0
        for j < engine.sequences.len {
            if !engine.sequences[j].finished {
                all_finished = false
                break
            }
            j = j + 1
        }
    }
    []int[] outputs = intmake([][], prompts.len)
    i = 0
    for i < engine.sequences.len {
        outputs[i] = engine.sequences[i].token_ids
        i = i + 1
    }
    outputs
}

func new_inference_engine(module model, inference_config config) inference_engine {
    []cache_block blocks = make([]cache_block, config.num_gpu_blocks + config.num_cpu_blocks)
    int i = 0
    for i < config.num_gpu_blocks {
        blocks[i] = cache_block {
            block_id: i,
            token_ids: make([]int, config.block_size),
            ref_count: 0,
            is_gpu: true,
        }
        i = i + 1
    }
    for i < config.num_gpu_blocks + config.num_cpu_blocks {
        blocks[i] = cache_block {
            block_id: i,
            token_ids: make([]int, config.block_size),
            ref_count: 0,
            is_gpu: false,
        }
        i = i + 1
    }
    block_cache_table table = block_cache_table {
        seq_block_tables: []int[]{},
        blocks: blocks,
        num_free_gpu_blocks: config.num_gpu_blocks,
        num_free_cpu_blocks: config.num_cpu_blocks,
    }
    inference_engine {
        model: model,
        config: config,
        block_table: table,
        sequences: make([]inference_sequence, config.max_num_seqs),
        next_seq_id: 0,
    }
}
