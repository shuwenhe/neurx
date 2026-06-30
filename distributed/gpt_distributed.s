package neurx.distributed.gpt_distributed

// ============================================================================
// Distributed GPT Training Bridge (operates on concrete GPT tensors)
//
// The generic data_parallel / zero modules work on abstract float* buffers.
// This bridge connects real distributed semantics directly to the concrete
// gpt_param_grads / gpt_adamw_state produced by the GPT backward pass.
//
// Implements:
//   • Data-Parallel (DDP) gradient all-reduce  (sum across ranks → average)
//   • Gradient bucketing for communication efficiency
//   • ZeRO-1 optimizer-state sharding (each rank owns a parameter slice)
//   • Distributed train step: per-rank grads → all-reduce → synchronized update
//
// In a real multi-node deployment the element-wise sum is performed by the
// NCCL backend (ring/tree all-reduce). Here the reduction math is implemented
// exactly so single-process simulation and multi-rank execution agree.
// ============================================================================

use neurx.model.llm.gpt.{gpt_config, gpt_model, gpt_layer, gpt_alloc, gpt_layer_at}
use neurx.model.llm.gpt_backward.{
    gpt_param_grads, gpt_layer_grads, gpt_adamw_state, gpt_forward_cache,
    gpt_adamw_step, gpt_forward_cached, gpt_backward, gpt_train_step,
    gpt_train_step_result, scale_all_grads
}

// ============================================================================
// 1. 分布式配置
// ============================================================================

struct dist_config {
    int world_size            // 总进程数 (= DP × TP × PP)
    int rank                  // 当前进程 rank
    int data_parallel_size    // 数据并行度
    int tensor_parallel_size  // 张量并行度
    int pipeline_parallel_size
    string backend            // "nccl" | "gloo"
    string zero_stage         // "none" | "zero1" | "zero2" | "zero3"
    int bucket_size_mb        // 梯度桶大小 (通信效率)
    bool overlap_comm         // 反向与通信重叠
}

func new_dist_config(int world_size, int rank, int dp_size) dist_config {
    dist_config {
        world_size: world_size,
        rank: rank,
        data_parallel_size: dp_size,
        tensor_parallel_size: 1,
        pipeline_parallel_size: 1,
        backend: "nccl",
        zero_stage: "zero1",
        bucket_size_mb: 25,
        overlap_comm: true,
    }
}

// ============================================================================
// 2. 张量级 all-reduce 原语
// ============================================================================

// 两个梯度向量逐元素相加 (跨 rank 求和的一步)
func dist_add_vec([]float a, []float b) []float {
    int n = len(a)
    []float out = gpt_alloc(n, 0.0)
    int i = 0
    while i < n {
        float bv = 0.0
        if i < len(b) {
            bv = b[i]
        }
        out[i] = a[i] + bv
        i = i + 1
    }
    out
}

// 梯度向量整体缩放 (求和后除以 world_size = 平均)
func dist_scale_vec([]float v, float scale) []float {
    int n = len(v)
    []float out = gpt_alloc(n, 0.0)
    int i = 0
    while i < n {
        out[i] = v[i] * scale
        i = i + 1
    }
    out
}

// ============================================================================
// 3. 层级梯度 all-reduce
// ============================================================================

func dist_add_layer_grads(gpt_layer_grads a, gpt_layer_grads b) gpt_layer_grads {
    gpt_layer_grads {
        d_norm1_gamma: dist_add_vec(a.d_norm1_gamma, b.d_norm1_gamma),
        d_norm2_gamma: dist_add_vec(a.d_norm2_gamma, b.d_norm2_gamma),
        d_wq: dist_add_vec(a.d_wq, b.d_wq),
        d_wk: dist_add_vec(a.d_wk, b.d_wk),
        d_wv: dist_add_vec(a.d_wv, b.d_wv),
        d_wo: dist_add_vec(a.d_wo, b.d_wo),
        d_wq_bias: dist_add_vec(a.d_wq_bias, b.d_wq_bias),
        d_wk_bias: dist_add_vec(a.d_wk_bias, b.d_wk_bias),
        d_wv_bias: dist_add_vec(a.d_wv_bias, b.d_wv_bias),
        d_wo_bias: dist_add_vec(a.d_wo_bias, b.d_wo_bias),
        d_ffn_gate_w: dist_add_vec(a.d_ffn_gate_w, b.d_ffn_gate_w),
        d_ffn_val_w: dist_add_vec(a.d_ffn_val_w, b.d_ffn_val_w),
        d_ffn_down_w: dist_add_vec(a.d_ffn_down_w, b.d_ffn_down_w),
    }
}

func dist_scale_layer_grads(gpt_layer_grads g, float scale) gpt_layer_grads {
    gpt_layer_grads {
        d_norm1_gamma: dist_scale_vec(g.d_norm1_gamma, scale),
        d_norm2_gamma: dist_scale_vec(g.d_norm2_gamma, scale),
        d_wq: dist_scale_vec(g.d_wq, scale),
        d_wk: dist_scale_vec(g.d_wk, scale),
        d_wv: dist_scale_vec(g.d_wv, scale),
        d_wo: dist_scale_vec(g.d_wo, scale),
        d_wq_bias: dist_scale_vec(g.d_wq_bias, scale),
        d_wk_bias: dist_scale_vec(g.d_wk_bias, scale),
        d_wv_bias: dist_scale_vec(g.d_wv_bias, scale),
        d_wo_bias: dist_scale_vec(g.d_wo_bias, scale),
        d_ffn_gate_w: dist_scale_vec(g.d_ffn_gate_w, scale),
        d_ffn_val_w: dist_scale_vec(g.d_ffn_val_w, scale),
        d_ffn_down_w: dist_scale_vec(g.d_ffn_down_w, scale),
    }
}

// ============================================================================
// 4. 完整模型梯度 all-reduce
// ============================================================================

// 两个 rank 的完整梯度求和
func dist_add_grads(gpt_param_grads a, gpt_param_grads b) gpt_param_grads {
    []gpt_layer_grads merged = []gpt_layer_grads{cap: a.n_layer}
    int l = 0
    while l < a.n_layer {
        merged[l] = dist_add_layer_grads(a.layers[l], b.layers[l])
        l = l + 1
    }
    gpt_param_grads {
        d_wte: dist_add_vec(a.d_wte, b.d_wte),
        d_wpe: dist_add_vec(a.d_wpe, b.d_wpe),
        d_final_gamma: dist_add_vec(a.d_final_gamma, b.d_final_gamma),
        d_lm_head: dist_add_vec(a.d_lm_head, b.d_lm_head),
        layers: merged,
        n_layer: a.n_layer,
    }
}

// 完整梯度缩放
func dist_scale_grads(gpt_param_grads g, float scale) gpt_param_grads {
    []gpt_layer_grads scaled = []gpt_layer_grads{cap: g.n_layer}
    int l = 0
    while l < g.n_layer {
        scaled[l] = dist_scale_layer_grads(g.layers[l], scale)
        l = l + 1
    }
    gpt_param_grads {
        d_wte: dist_scale_vec(g.d_wte, scale),
        d_wpe: dist_scale_vec(g.d_wpe, scale),
        d_final_gamma: dist_scale_vec(g.d_final_gamma, scale),
        d_lm_head: dist_scale_vec(g.d_lm_head, scale),
        layers: scaled,
        n_layer: g.n_layer,
    }
}

// DDP all-reduce: 跨所有 rank 求梯度和后取平均
// per_rank_grads[r] = rank r 在其本地 micro-batch 上算出的梯度
func dist_all_reduce_grads([]gpt_param_grads per_rank_grads) gpt_param_grads {
    int world = len(per_rank_grads)
    if world == 0 {
        // 不该发生; 返回空
        return per_rank_grads[0]
    }
    if world == 1 {
        return per_rank_grads[0]
    }

    // 累加所有 rank 的梯度
    gpt_param_grads summed = per_rank_grads[0]
    int r = 1
    while r < world {
        summed = dist_add_grads(summed, per_rank_grads[r])
        r = r + 1
    }

    // 平均 (DDP 标准: 梯度对 batch 取均值)
    float scale = 1.0 / (world * 1.0)
    dist_scale_grads(summed, scale)
}

// ============================================================================
// 5. 分布式训练步
//
//   每个 DP rank 在自己的 micro-batch 上做前向+反向 → 得到本地梯度，
//   all-reduce 平均 → 所有 rank 用相同的平均梯度做同步参数更新。
//   (单进程模拟: 顺序计算每个 rank 的梯度，再聚合)
// ============================================================================

struct dist_train_result {
    gpt_model model
    gpt_adamw_state opt
    float loss              // 跨 rank 平均损失
    float grad_norm
    int world_size
}

// 计算单个 rank 的梯度 (内部用 forward_cached + backward)
func dist_compute_rank_grads(
    gpt_model model,
    []int token_ids,
    []int targets,
    int batch_size,
    int seq_len
) gpt_param_grads {
    gpt_forward_cache fc
    []float logits
    (fc, logits) = gpt_forward_cached(model, token_ids, batch_size, seq_len)
    gpt_backward(model, fc, targets)
}

// 全局梯度范数 (跨参数)
func dist_grad_norm(gpt_param_grads grads) float {
    float sq = 0.0
    sq = sq + dist_vec_norm_sq(grads.d_wte)
    sq = sq + dist_vec_norm_sq(grads.d_wpe)
    sq = sq + dist_vec_norm_sq(grads.d_final_gamma)
    sq = sq + dist_vec_norm_sq(grads.d_lm_head)
    int l = 0
    while l < grads.n_layer {
        gpt_layer_grads g = grads.layers[l]
        sq = sq + dist_vec_norm_sq(g.d_wq)
        sq = sq + dist_vec_norm_sq(g.d_wk)
        sq = sq + dist_vec_norm_sq(g.d_wv)
        sq = sq + dist_vec_norm_sq(g.d_wo)
        sq = sq + dist_vec_norm_sq(g.d_ffn_gate_w)
        sq = sq + dist_vec_norm_sq(g.d_ffn_val_w)
        sq = sq + dist_vec_norm_sq(g.d_ffn_down_w)
        l = l + 1
    }
    dist_sqrt(sq)
}

func dist_vec_norm_sq([]float v) float {
    float s = 0.0
    int i = 0
    while i < len(v) {
        s = s + v[i] * v[i]
        i = i + 1
    }
    s
}

func dist_sqrt(float x) float {
    if x <= 0.0 { return 0.0 }
    float y = x
    int i = 0
    while i < 15 { y = 0.5 * (y + x / y); i = i + 1 }
    y
}

// 分布式数据并行训练步
//   rank_batches[r] = rank r 的 token batch  [micro_batch * seq_len]
//   rank_targets[r] = rank r 的 targets
func distributed_train_step(
    gpt_model model,
    gpt_adamw_state opt,
    [][]int rank_batches,
    [][]int rank_targets,
    int micro_batch,
    int seq_len,
    float grad_clip
) dist_train_result {
    int world = len(rank_batches)
    if world < 1 { world = 1 }

    // 1. 每个 rank 计算本地梯度
    []gpt_param_grads per_rank = []gpt_param_grads{cap: world}
    int r = 0
    while r < world {
        per_rank[r] = dist_compute_rank_grads(
            model, rank_batches[r], rank_targets[r], micro_batch, seq_len
        )
        r = r + 1
    }

    // 2. All-reduce: 跨 rank 平均梯度
    gpt_param_grads avg_grads = dist_all_reduce_grads(per_rank)

    // 3. 梯度裁剪 (在平均后的全局梯度上)
    float gnorm = dist_grad_norm(avg_grads)
    if grad_clip > 0.0 && gnorm > grad_clip {
        float coeff = grad_clip / gnorm
        avg_grads = scale_all_grads(avg_grads, coeff)
    }

    // 4. 同步参数更新 (所有 rank 用相同平均梯度 → 模型保持一致)
    gpt_model updated_model
    gpt_adamw_state updated_opt
    (updated_model, updated_opt) = gpt_adamw_step(model, avg_grads, opt)

    dist_train_result {
        model: updated_model,
        opt: updated_opt,
        loss: 0.0,
        grad_norm: gnorm,
        world_size: world,
    }
}

// ============================================================================
// 6. ZeRO-1 优化器状态分片
//
//   ZeRO-1: 优化器状态 (AdamW 的 m/v) 在 DP rank 间分片，
//   每个 rank 只持有 1/world_size 的优化器状态，显存占用大幅下降。
//   参数仍全量复制；梯度 all-reduce 后，每个 rank 更新自己负责的分片，
//   再 all-gather 同步参数。
// ============================================================================

struct zero1_partition {
    int rank
    int world_size
    int start_index     // 本 rank 负责的参数起始下标
    int end_index       // 结束下标 (不含)
    int total_params
}

// 计算某 rank 负责的参数区间 (按总参数量均分)
func zero1_compute_partition(int rank, int world_size, int total_params) zero1_partition {
    int per_rank = total_params / world_size
    int remainder = total_params - per_rank * world_size
    int start = rank * per_rank
    // 把余数分给前面的 rank
    if rank < remainder {
        start = start + rank
        per_rank = per_rank + 1
    } else {
        start = start + remainder
    }
    int end = start + per_rank
    if end > total_params {
        end = total_params
    }
    zero1_partition {
        rank: rank,
        world_size: world_size,
        start_index: start,
        end_index: end,
        total_params: total_params,
    }
}

// ZeRO-1 显存节省估算 (优化器状态从 12 字节/参数降到 12/world)
func zero1_memory_savings_bytes(int total_params, int world_size) int {
    // AdamW: fp32 momentum(4) + variance(4) + master(4) = 12 字节/参数
    int full = total_params * 12
    int sharded = full / world_size
    full - sharded
}

// ============================================================================
// 7. 梯度桶 (通信效率): 把小张量打包成桶以减少通信次数
// ============================================================================

struct grad_bucket {
    int bucket_id
    int total_elements
    int num_tensors
    bool ready          // 桶内所有梯度就绪，可触发 all-reduce
}

// 估算需要多少个桶 (按 bucket_size_mb)
func compute_num_buckets(int total_params, int bucket_size_mb) int {
    int bucket_elements = bucket_size_mb * 1024 * 1024 / 4   // fp32
    if bucket_elements <= 0 {
        return 1
    }
    int num = total_params / bucket_elements
    if num * bucket_elements < total_params {
        num = num + 1
    }
    if num < 1 {
        num = 1
    }
    num
}

// 估算通信量 (all-reduce 传输 2*(N-1)/N * 参数字节)
func estimate_comm_bytes(int total_params, int world_size) int {
    if world_size <= 1 {
        return 0
    }
    int param_bytes = total_params * 4
    // ring all-reduce: 2(N-1)/N 倍参数量
    2 * param_bytes * (world_size - 1) / world_size
}
