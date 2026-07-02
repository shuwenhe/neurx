package neurx.distributed.moe_all_to_all

// ============================================================================
// MoE All-to-All 路由通信
//
// 核心流程:
//   1. Token 到专家的映射 (每个 token 选择 top-k 专家)
//   2. 创建路由索引
//   3. 使用 All-to-All 收发 token
//   4. 各 GPU 处理本地专家
//   5. 使用 All-to-All 收回输出
//   6. 恢复原始 token 顺序
//
// 性能:
//   - All-to-All 是双向的，总通信量 = 2 × 模型大小
//   - 与 GEMM 通信重叠以隐藏延迟
//   - 动态分配容量以处理负载不均
//
// ============================================================================

use neurx.strings
use neurx.runtime.io.{io_println}
use neurx.distributed.collective.{collective_state, alltoall_async}

// ============================================================================
// 1. 路由和负载均衡
// ============================================================================

// 单个 token 的路由决策
struct routing_decision {
    []int expert_indices         // [top_k] - 选中的专家 ID
    []float expert_weights       // [top_k] - 每个专家的权重 (归一化)
    int num_experts_selected
}

// 专家容量和负载统计
struct expert_capacity_stats {
    int expert_id
    int capacity                 // 该专家可以处理的最大 token 数
    int current_load             // 当前分配给该专家的 token 数
    float utilization_ratio
    int dropped_tokens           // 容量溢出的 token 数 (如果启用硬容量限制)
}

// MoE 路由状态
struct moe_routing_state {
    int num_experts
    int top_k
    int num_tokens
    int batch_size
    int hidden_dim
    
    // 路由权重矩阵 [num_tokens, num_experts]
    []float router_logits
    
    // 路由决策 [num_tokens]
    []routing_decision routing_decisions
    
    // 专家容量管理
    []expert_capacity_stats expert_stats
    
    // 通信统计
    long tokens_sent_per_expert     // [num_experts] 发送给每个专家的 token 数
    long tokens_received_per_expert // [num_experts]
    
    // 辅助损失项 (用于平衡)
    float aux_loss
}

// ============================================================================
// 2. 路由算法
// ============================================================================

// 计算路由权重 (门控网络输出)
// 输入: hidden_states [num_tokens, hidden_dim]
// 输出: logits [num_tokens, num_experts]
func compute_router_logits(
    []float hidden_states,
    []float router_weight,      // [hidden_dim, num_experts]
    int num_tokens,
    int hidden_dim,
    int num_experts
) []float {
    
    []float logits = make([]float, num_tokens * num_experts)
    
    int t = 0
    while t < num_tokens {
        int e = 0
        while e < num_experts {
            float logit = 0.0
            int h = 0
            while h < hidden_dim {
                logit = logit + hidden_states[t * hidden_dim + h] * 
                               router_weight[h * num_experts + e]
                h = h + 1
            }
            logits[t * num_experts + e] = logit
            e = e + 1
        }
        t = t + 1
    }
    
    logits
}

// Top-K 专家选择
func select_top_k_experts(
    []float logits,           // [num_tokens, num_experts]
    int num_tokens,
    int num_experts,
    int top_k,
    int num_experts_total    // 全局专家数
) []routing_decision {
    
    []routing_decision decisions = make([]routing_decision, num_tokens)
    
    int t = 0
    while t < num_tokens {
        // 找到 top-k 专家 (简化实现: 排序)
        []int indices = make([]int, num_experts)
        []float values = make([]float, num_experts)
        
        int e = 0
        while e < num_experts {
            indices[e] = e
            values[e] = logits[t * num_experts + e]
            e = e + 1
        }
        
        // 简单的冒泡排序找 top-k
        int k = 0
        while k < top_k && k < num_experts {
            int best_idx = k
            float best_val = values[k]
            
            int i = k + 1
            while i < num_experts {
                if values[i] > best_val {
                    best_val = values[i]
                    best_idx = i
                }
                i = i + 1
            }
            
            // 交换
            int tmp_idx = indices[k]
            indices[k] = indices[best_idx]
            indices[best_idx] = tmp_idx
            
            float tmp_val = values[k]
            values[k] = values[best_idx]
            values[best_idx] = tmp_val
            
            k = k + 1
        }
        
        // 计算权重 (softmax)
        []int selected_experts = make([]int, top_k)
        []float weights = make([]float, top_k)
        
        float max_logit = values[0]
        float sum_exp = 0.0
        
        int j = 0
        while j < top_k {
            selected_experts[j] = indices[j]
            float exp_logit = exp(values[j] - max_logit)
            weights[j] = exp_logit
            sum_exp = sum_exp + exp_logit
            j = j + 1
        }
        
        // 归一化权重
        j = 0
        while j < top_k {
            if sum_exp > 0.0 {
                weights[j] = weights[j] / sum_exp
            }
            j = j + 1
        }
        
        decisions[t] = routing_decision {
            expert_indices: selected_experts,
            expert_weights: weights,
            num_experts_selected: top_k,
        }
        
        t = t + 1
    }
    
    decisions
}

// ============================================================================
// 3. Token 分发与收集
// ============================================================================

// 创建 All-to-All 的发送缓冲区
// 将 token 按照路由决策打包，发送给不同的 GPU
func create_send_buffers(
    moe_routing_state state,
    []float hidden_states,       // [num_tokens, hidden_dim]
    int ep_rank,                 // expert parallel rank
    int ep_size                  // expert parallel size
) [][]float {
    
    // 创建 ep_size 个缓冲区，每个对应一个 destination GPU
    [][]float send_buffers = make([][]float, ep_size)
    
    int i = 0
    while i < ep_size {
        send_buffers[i] = make([]float, 0)
        i = i + 1
    }
    
    // 遍历每个 token 的路由决策
    int t = 0
    while t < state.num_tokens {
        routing_decision decision = state.routing_decisions[t]
        
        // 对每个选中的专家
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            float weight = decision.expert_weights[k]
            
            // 计算目标 GPU (expert_parallel_rank)
            int target_ep_rank = expert_id / (state.num_experts / ep_size)
            if target_ep_rank >= ep_size {
                target_ep_rank = ep_size - 1
            }
            
            // 将加权后的 hidden_state 追加到目标缓冲区
            int h = 0
            while h < state.hidden_dim {
                float weighted_val = hidden_states[t * state.hidden_dim + h] * weight
                // append weighted_val to send_buffers[target_ep_rank]
                h = h + 1
            }
            
            k = k + 1
        }
        
        t = t + 1
    }
    
    send_buffers
}

// 执行 All-to-All 通信
func moe_alltoall_exchange(
    moe_routing_state state,
    collective_state comm,
    int ep_rank,
    int ep_size,
    [][]float send_buffers  // [ep_size][variable_size]
) [][]float {
    
    // 在实际实现中，这会使用 NCCL AlltoAll
    // 返回接收缓冲区 [ep_size][variable_size]
    
    [][]float recv_buffers = make([][]float, ep_size)
    
    int i = 0
    while i < ep_size {
        recv_buffers[i] = make([]float, 0)
        i = i + 1
    }
    
    recv_buffers
}

// ============================================================================
// 4. 专家处理和输出收集
// ============================================================================

// 处理本 GPU 负责的专家
func process_local_experts(
    moe_routing_state state,
    [][]float token_batches,     // [num_local_experts][variable_num_tokens, hidden_dim]
    [][]float expert_weights,    // [num_local_experts][hidden_dim, ffn_dim]
    int ep_rank,
    int ep_size
) [][]float {
    
    // 每个 expert 执行 FFN 计算
    [][]float expert_outputs = make([][]float, 0)
    
    expert_outputs
}

// 重构输出 token 的原始顺序
func reconstruct_token_order(
    moe_routing_state state,
    [][]float expert_outputs,    // 来自各专家的输出
    int num_tokens,
    int hidden_dim
) []float {
    
    []float output = make([]float, num_tokens * hidden_dim)
    
    // 使用反向的路由信息恢复顺序
    int t = 0
    while t < num_tokens {
        routing_decision decision = state.routing_decisions[t]
        
        []float combined_output = make([]float, hidden_dim)
        
        // 组合来自各专家的加权输出
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            float weight = decision.expert_weights[k]
            
            // 从相应的专家输出取值
            // combined_output += expert_outputs[expert_id] * weight
            
            k = k + 1
        }
        
        // 复制到输出缓冲区
        int h = 0
        while h < hidden_dim {
            output[t * hidden_dim + h] = combined_output[h]
            h = h + 1
        }
        
        t = t + 1
    }
    
    output
}

// ============================================================================
// 5. 负载均衡和辅助损失
// ============================================================================

// 计算负载均衡指标
func compute_load_balancing_loss(
    moe_routing_state state
) float {
    
    // 计算每个专家的 token 数量分布
    []int expert_token_count = make([]int, state.num_experts)
    
    int t = 0
    while t < state.num_tokens {
        routing_decision decision = state.routing_decisions[t]
        
        int k = 0
        while k < decision.num_experts_selected {
            int expert_id = decision.expert_indices[k]
            expert_token_count[expert_id] = expert_token_count[expert_id] + 1
            k = k + 1
        }
        
        t = t + 1
    }
    
    // 计算不均衡指标: (max - mean) / mean
    float mean_count = float(state.num_tokens * state.top_k) / float(state.num_experts)
    float max_count = 0.0
    
    int e = 0
    while e < state.num_experts {
        if float(expert_token_count[e]) > max_count {
            max_count = float(expert_token_count[e])
        }
        e = e + 1
    }
    
    float imbalance = 0.0
    if mean_count > 0.0 {
        imbalance = (max_count - mean_count) / mean_count
    }
    
    // 辅助损失 = 负载均衡系数 × 不均衡度
    float aux_loss_weight = 0.01
    state.aux_loss = imbalance * aux_loss_weight
    
    state.aux_loss
}

// 计算专家利用率
func compute_expert_utilization(
    moe_routing_state state
) float {
    
    // 平均利用率 = 实际处理的 token / (预期 token × num_experts)
    float total_expert_assignments = 0.0
    
    int t = 0
    while t < state.num_tokens {
        total_expert_assignments = total_expert_assignments + float(state.top_k)
        t = t + 1
    }
    
    float expected_assignments = float(state.num_tokens * state.num_experts) / float(state.num_experts)
    
    float utilization = 0.0
    if expected_assignments > 0.0 {
        utilization = total_expert_assignments / expected_assignments
    }
    
    utilization
}

// ============================================================================
// 6. 完整 MoE All-to-All 层
// ============================================================================

// MoE All-to-All 前向传播
func moe_alltoall_forward(
    moe_routing_state state,
    collective_state comm,
    []float hidden_states,
    []float router_weight,
    [][]float expert_weights,
    int ep_rank,
    int ep_size,
    int batch_size,
    int seq_len
) ([]float, float) {
    
    state.num_tokens = batch_size * seq_len
    
    // 步骤 1: 计算路由
    []float logits = compute_router_logits(
        hidden_states, router_weight, state.num_tokens, 
        state.hidden_dim, state.num_experts
    )
    
    state.router_logits = logits
    state.routing_decisions = select_top_k_experts(
        logits, state.num_tokens, state.num_experts, state.top_k, state.num_experts
    )
    
    // 步骤 2: 创建 All-to-All 缓冲区
    [][]float send_buffers = create_send_buffers(state, hidden_states, ep_rank, ep_size)
    
    // 步骤 3: All-to-All 通信
    [][]float recv_buffers = moe_alltoall_exchange(state, comm, ep_rank, ep_size, send_buffers)
    
    // 步骤 4: 处理本地专家
    [][]float expert_outputs = process_local_experts(state, recv_buffers, expert_weights, ep_rank, ep_size)
    
    // 步骤 5: All-to-All 返回输出
    [][]float return_send_buffers = make([][]float, ep_size)
    // ... 打包专家输出
    [][]float return_recv_buffers = moe_alltoall_exchange(state, comm, ep_rank, ep_size, return_send_buffers)
    
    // 步骤 6: 重构输出顺序
    []float output = reconstruct_token_order(state, return_recv_buffers, state.num_tokens, state.hidden_dim)
    
    // 步骤 7: 计算负载均衡损失
    float aux_loss = compute_load_balancing_loss(state)
    
    (output, aux_loss)
}

// ============================================================================
// 7. 工具函数
// ============================================================================

func exp(float x) float {
    // 占位符
    2.718
}

func float(int x) float {
    0.0 + x
}
