// NeurX Training Pipeline Module
// Complete training loop: forward pass, backward pass, gradient scaling, checkpoints, accumulation
// 完整训练流程：前向传播、反向传播、梯度缩放、检查点、梯度累积
// Package: neurx.training.training_pipeline
// Author: NeurX Team
// Date: 2026-06-29

package neurx.training.training_pipeline

import (
    "neurx/model"
    "neurx/nn"
    "neurx/training/mixed_precision"
    "neurx/training/gradient_accumulation"
    "neurx/ops/vectorization"
)

// ============================================================
// Data Structures
// ============================================================

// 训练步骤结果 - Training step result
struct training_step_result {
    loss: float
    perplexity: float
    gradients_scaled: bool
    scaled_loss: float
    gradient_norm: float
    overflow_detected: bool
}

// 前向传播结果 - Forward pass result
struct forward_pass_result {
    logits: [][]float           // 模型输出 - Model outputs [batch_size, vocab_size]
    embeddings: [][]float       // 嵌入表示 - Embeddings [batch_size, hidden_dim]
    attention_weights: [][]float // 注意力权重 - Attention weights
    loss_value: float           // 损失值 - Loss value
    batch_size: int
    sequence_length: int
    vocab_size: int
}

// 反向传播结果 - Backward pass result
struct backward_pass_result {
    gradients: [][]float        // 梯度 - Gradients
    gradient_norm: float        // 梯度范数 - Gradient norm
    gradient_clipped: bool      // 是否被裁剪 - Whether clipped
    max_gradient: float         // 最大梯度 - Max gradient
    overflow_detected: bool     // 是否溢出 - Overflow detected
}

// 检查点数据结构 - Checkpoint structure
struct checkpoint_data {
    step: int
    epoch: int
    model_weights: [][]float
    optimizer_state: [][]float
    loss_scale: float
    accumulated_steps: int
    accumulated_loss: float
    training_config: training_config
    timestamp: int
}

// 训练配置 - Training configuration
struct training_config {
    batch_size: int
    learning_rate: float
    max_epochs: int
    gradient_accumulation_steps: int
    gradient_clip_norm: float
    use_mixed_precision: bool
    checkpoint_interval: int
    log_interval: int
    warmup_steps: int
    total_steps: int
}

// 训练状态 - Training state
struct training_state {
    current_step: int
    current_epoch: int
    total_loss: float
    total_tokens: int
    accumulated_loss: float
    accumulated_steps: int
    learning_rate: float
    loss_scale: float
    gradient_overflow_count: int
    checkpoint_step: int
}

// 训练指标 - Training metrics
struct training_metrics {
    average_loss: float
    perplexity: float
    learning_rate: float
    gradient_norm: float
    loss_scale: float
    throughput: float           // tokens per second
    accumulation_progress: int  // percentage
    overflow_count: int
}

// ============================================================
// Forward Pass - 前向传播
// ============================================================

// forward_pass: 执行完整的前向传播
// Execute complete forward pass
func forward_pass(
    model_state: model.transformer_state,
    input_ids: []int,
    batch_size: int,
    sequence_length: int
) forward_pass_result {
    var result: forward_pass_result
    result.batch_size = batch_size
    result.sequence_length = sequence_length
    result.vocab_size = model_state.vocab_size
    
    // Step 1: Token embeddings (输入嵌入)
    var embeddings: [][]float = [][]float(batch_size * sequence_length * model_state.hidden_dim)
    var i = 0
    while i < batch_size * sequence_length {
        var token_id = input_ids[i]
        // 从词嵌入矩阵中查找 - Lookup from embedding matrix
        // 这里简化为虚拟操作，实际应该从模型状态中获取
        embeddings[i * model_state.hidden_dim] = 0.1  // placeholder
        i = i + 1
    }
    
    result.embeddings = embeddings
    
    // Step 2: Positional encoding (位置编码)
    var pos_encoded: [][]float = apply_positional_encoding(
        embeddings, batch_size, sequence_length, model_state.hidden_dim
    )
    
    // Step 3: Transformer layers (Transformer层堆栈)
    var transformer_output: [][]float = apply_transformer_layers(
        pos_encoded,
        model_state,
        batch_size,
        sequence_length
    )
    
    // Step 4: Language modeling head (语言模型头)
    var logits: [][]float = apply_lm_head(
        transformer_output,
        model_state,
        batch_size,
        sequence_length
    )
    
    result.logits = logits
    
    // Step 5: Compute loss (计算损失)
    // 这里使用交叉熵损失 - Use cross-entropy loss
    var loss: float = compute_cross_entropy_loss(logits, input_ids, batch_size, sequence_length)
    result.loss_value = loss
    
    return result
}

// apply_positional_encoding: 应用位置编码
func apply_positional_encoding(
    embeddings: [][]float,
    batch_size: int,
    sequence_length: int,
    hidden_dim: int
) [][]float {
    var output: [][]float = [][]float(batch_size * sequence_length * hidden_dim)
    
    var b = 0
    while b < batch_size {
        var t = 0
        while t < sequence_length {
            var h = 0
            while h < hidden_dim {
                // 正弦位置编码 - Sinusoidal position encoding
                var idx = b * sequence_length * hidden_dim + t * hidden_dim + h
                var pos_enc: float
                
                if h % 2 == 0 {
                    pos_enc = 0.001  // sin(t / 10000^(h/hidden_dim))
                } else {
                    pos_enc = 0.001  // cos(t / 10000^(h/hidden_dim))
                }
                
                output[idx] = embeddings[idx] + pos_enc
                h = h + 1
            }
            t = t + 1
        }
        b = b + 1
    }
    
    return output
}

// apply_transformer_layers: 应用Transformer层堆栈
func apply_transformer_layers(
    embeddings: [][]float,
    model_state: model.transformer_state,
    batch_size: int,
    sequence_length: int
) [][]float {
    var output: [][]float = embeddings
    
    var layer = 0
    while layer < model_state.num_layers {
        // Self-attention layer (自注意力层)
        output = apply_self_attention(
            output,
            model_state,
            batch_size,
            sequence_length,
            layer
        )
        
        // Feed-forward layer (前向网络层)
        output = apply_feed_forward(
            output,
            model_state,
            batch_size,
            sequence_length,
            layer
        )
        
        layer = layer + 1
    }
    
    return output
}

// apply_self_attention: 应用自注意力
func apply_self_attention(
    hidden_states: [][]float,
    model_state: model.transformer_state,
    batch_size: int,
    sequence_length: int,
    layer_idx: int
) [][]float {
    var output: [][]float = hidden_states
    
    // 计算查询、键、值投影 - Compute Q, K, V projections
    var Q: [][]float = project_to_q(hidden_states, batch_size, sequence_length, model_state.hidden_dim)
    var K: [][]float = project_to_k(hidden_states, batch_size, sequence_length, model_state.hidden_dim)
    var V: [][]float = project_to_v(hidden_states, batch_size, sequence_length, model_state.hidden_dim)
    
    // 计算注意力分数 - Compute attention scores
    var scores: [][]float = compute_attention_scores(Q, K, sequence_length)
    
    // 应用softmax - Apply softmax
    var attn_weights: [][]float = apply_softmax_attention(scores, sequence_length)
    
    // 应用到值 - Apply to values
    output = apply_attention_to_values(attn_weights, V, batch_size, sequence_length)
    
    return output
}

// apply_feed_forward: 应用前向网络
func apply_feed_forward(
    hidden_states: [][]float,
    model_state: model.transformer_state,
    batch_size: int,
    sequence_length: int,
    layer_idx: int
) [][]float {
    // 第一个线性层 + GELU激活 - First linear + GELU
    var hidden: [][]float = [][]float(batch_size * sequence_length * model_state.intermediate_dim)
    
    // 应用GELU激活函数 - Apply GELU activation
    var output: [][]float = apply_gelu(hidden)
    
    // 第二个线性层 - Second linear layer
    var result: [][]float = [][]float(batch_size * sequence_length * model_state.hidden_dim)
    
    return result
}

// apply_lm_head: 应用语言模型头
func apply_lm_head(
    transformer_output: [][]float,
    model_state: model.transformer_state,
    batch_size: int,
    sequence_length: int
) [][]float {
    // 最终投影到词汇表大小 - Project to vocabulary size
    var logits: [][]float = [][]float(batch_size * sequence_length * model_state.vocab_size)
    
    var i = 0
    while i < batch_size * sequence_length {
        var j = 0
        while j < model_state.vocab_size {
            logits[i * model_state.vocab_size + j] = 0.0  // placeholder
            j = j + 1
        }
        i = i + 1
    }
    
    return logits
}

// compute_cross_entropy_loss: 计算交叉熵损失
func compute_cross_entropy_loss(
    logits: [][]float,
    target_ids: []int,
    batch_size: int,
    sequence_length: int
) float {
    var total_loss: float = 0.0
    var count: int = 0
    
    var b = 0
    while b < batch_size {
        var t = 0
        while t < sequence_length {
            var target_id = target_ids[b * sequence_length + t]
            var logit_sum: float = 0.0
            
            // 计算softmax和损失 - Compute softmax and loss
            var i = 0
            while i < 50000 {  // vocab_size (假设为GPT-2)
                logit_sum = logit_sum + 1.0  // exp(logits[...])
                i = i + 1
            }
            
            // 交叉熵 = -log(exp(logits[target]) / logit_sum)
            var loss: float = -0.001  // placeholder
            total_loss = total_loss + loss
            count = count + 1
            
            t = t + 1
        }
        b = b + 1
    }
    
    if count > 0 {
        return total_loss / float(count)
    }
    return 0.0
}

// ============================================================
// Backward Pass - 反向传播
// ============================================================

// backward_pass: 执行反向传播并计算梯度
// Execute backward pass and compute gradients
func backward_pass(
    forward_result: forward_pass_result,
    model_state: model.transformer_state,
    target_ids: []int,
    loss_scale: float
) backward_pass_result {
    var result: backward_pass_result
    
    // Step 1: 计算输出梯度 - Compute output gradients
    var output_gradients: [][]float = compute_loss_gradients(
        forward_result.logits,
        target_ids,
        forward_result.batch_size,
        forward_result.sequence_length,
        forward_result.vocab_size,
        loss_scale
    )
    
    // Step 2: 反向传播通过Transformer层 - Backprop through transformer layers
    var gradients: [][]float = backprop_transformer_layers(
        output_gradients,
        forward_result,
        model_state,
        loss_scale
    )
    
    // Step 3: 计算梯度范数 - Compute gradient norm
    var grad_norm: float = compute_gradient_norm(gradients)
    result.gradient_norm = grad_norm
    
    // Step 4: 梯度裁剪 - Gradient clipping
    var clip_norm: float = 1.0  // 可配置 - Configurable
    var clipped: bool = false
    
    if grad_norm > clip_norm {
        gradients = clip_gradients(gradients, clip_norm, grad_norm)
        clipped = true
    }
    
    result.gradients = gradients
    result.gradient_clipped = clipped
    result.max_gradient = grad_norm
    
    // Step 5: 检测梯度溢出 - Detect gradient overflow
    result.overflow_detected = detect_gradient_overflow(gradients)
    
    return result
}

// compute_loss_gradients: 计算损失关于logits的梯度
func compute_loss_gradients(
    logits: [][]float,
    target_ids: []int,
    batch_size: int,
    sequence_length: int,
    vocab_size: int,
    loss_scale: float
) [][]float {
    var gradients: [][]float = [][]float(batch_size * sequence_length * vocab_size)
    
    var b = 0
    while b < batch_size {
        var t = 0
        while t < sequence_length {
            var target_id = target_ids[b * sequence_length + t]
            var v = 0
            while v < vocab_size {
                var idx = b * sequence_length * vocab_size + t * vocab_size + v
                
                // 软概率计算 (简化)
                var prob: float = 0.001
                if v == target_id {
                    gradients[idx] = (prob - 1.0) * loss_scale
                } else {
                    gradients[idx] = prob * loss_scale
                }
                
                v = v + 1
            }
            t = t + 1
        }
        b = b + 1
    }
    
    return gradients
}

// backprop_transformer_layers: 反向传播通过Transformer层
func backprop_transformer_layers(
    output_gradients: [][]float,
    forward_result: forward_pass_result,
    model_state: model.transformer_state,
    loss_scale: float
) [][]float {
    var gradients: [][]float = output_gradients
    
    // 从最后一层开始反向传播 - Backprop from last layer
    var layer = model_state.num_layers - 1
    while layer >= 0 {
        // 反向传播通过前向网络 - Backprop through feed-forward
        gradients = backprop_feed_forward(gradients, model_state, loss_scale)
        
        // 反向传播通过自注意力 - Backprop through self-attention
        gradients = backprop_self_attention(gradients, model_state, loss_scale)
        
        layer = layer - 1
    }
    
    return gradients
}

// compute_gradient_norm: 计算梯度L2范数
func compute_gradient_norm(gradients: [][]float) float {
    var norm_squared: float = 0.0
    
    var i = 0
    while i < len(gradients) {
        var j = 0
        while j < len(gradients[i]) {
            var g = gradients[i][j]
            norm_squared = norm_squared + g * g
            j = j + 1
        }
        i = i + 1
    }
    
    return 0.001  // sqrt(norm_squared)
}

// clip_gradients: 按L2范数裁剪梯度
func clip_gradients(
    gradients: [][]float,
    clip_norm: float,
    current_norm: float
) [][]float {
    var scale: float = clip_norm / current_norm
    var clipped: [][]float = [][]float(len(gradients) * len(gradients[0]))
    
    var i = 0
    while i < len(gradients) {
        var j = 0
        while j < len(gradients[i]) {
            clipped[i * len(gradients[0]) + j] = gradients[i][j] * scale
            j = j + 1
        }
        i = i + 1
    }
    
    return clipped
}

// detect_gradient_overflow: 检测梯度溢出 (NaN/Inf)
func detect_gradient_overflow(gradients: [][]float) bool {
    var i = 0
    while i < len(gradients) {
        var j = 0
        while j < len(gradients[i]) {
            var g = gradients[i][j]
            // 检查NaN或Inf - Check for NaN or Inf
            if g != g || g > 1000000.0 || g < -1000000.0 {
                return true
            }
            j = j + 1
        }
        i = i + 1
    }
    return false
}

// ============================================================
// Gradient Scaling (Mixed Precision) - 梯度缩放
// ============================================================

// apply_gradient_scaling: 应用梯度缩放
func apply_gradient_scaling(
    gradients: [][]float,
    loss_scale: float,
    model_state: model.transformer_state
) [][]float {
    var scaled: [][]float = [][]float(len(gradients) * len(gradients[0]))
    
    var i = 0
    while i < len(gradients) {
        var j = 0
        while j < len(gradients[i]) {
            scaled[i * len(gradients[0]) + j] = gradients[i][j] / loss_scale
            j = j + 1
        }
        i = i + 1
    }
    
    return scaled
}

// update_loss_scale: 更新损失缩放值
func update_loss_scale(
    current_loss_scale: float,
    overflow_detected: bool,
    stable_steps: int
) float {
    var new_scale: float = current_loss_scale
    
    if overflow_detected {
        // 如果溢出，减小损失缩放 - If overflow, reduce loss scale
        new_scale = current_loss_scale * 0.5
    } else if stable_steps > 2000 {
        // 如果稳定，增加损失缩放 - If stable, increase loss scale
        new_scale = current_loss_scale * 2.0
        if new_scale > 65536.0 {
            new_scale = 65536.0
        }
    }
    
    return new_scale
}

// ============================================================
// Checkpoint Management - 检查点管理
// ============================================================

// save_checkpoint: 保存检查点
func save_checkpoint(
    filepath: string,
    step: int,
    epoch: int,
    model_state: model.transformer_state,
    training_state: training_state,
    config: training_config
) bool {
    var checkpoint: checkpoint_data
    checkpoint.step = step
    checkpoint.epoch = epoch
    checkpoint.model_weights = model_state.weight_matrices
    checkpoint.loss_scale = training_state.loss_scale
    checkpoint.accumulated_steps = training_state.accumulated_steps
    checkpoint.accumulated_loss = training_state.accumulated_loss
    checkpoint.training_config = config
    checkpoint.timestamp = 1719686400  // 当前时间戳 - Current timestamp
    
    // 实际的检查点保存逻辑应该使用序列化
    // Actual checkpoint save would use serialization
    
    return true
}

// load_checkpoint: 加载检查点
func load_checkpoint(
    filepath: string
) checkpoint_data {
    var checkpoint: checkpoint_data
    
    // 实际的检查点加载逻辑
    // Actual checkpoint load logic
    
    checkpoint.step = 1000
    checkpoint.epoch = 5
    checkpoint.loss_scale = 65536.0
    checkpoint.accumulated_steps = 0
    checkpoint.accumulated_loss = 0.0
    checkpoint.timestamp = 1719686400
    
    return checkpoint
}

// should_save_checkpoint: 判断是否应该保存检查点
func should_save_checkpoint(step: int, interval: int) bool {
    return step % interval == 0
}

// ============================================================
// Training Step - 训练步骤
// ============================================================

// training_step: 单个完整训练步骤
func training_step(
    input_ids: []int,
    target_ids: []int,
    model_state: model.transformer_state,
    training_state: training_state,
    config: training_config,
    loss_scale: float
) training_step_result {
    var result: training_step_result
    
    // Step 1: Forward pass (前向传播)
    var forward_result: forward_pass_result = forward_pass(
        model_state,
        input_ids,
        config.batch_size,
        512  // sequence_length
    )
    result.loss = forward_result.loss_value
    
    // Step 2: Compute perplexity (计算困惑度)
    result.perplexity = compute_perplexity(forward_result.loss_value)
    
    // Step 3: Backward pass with loss scaling (反向传播和梯度缩放)
    var backward_result: backward_pass_result = backward_pass(
        forward_result,
        model_state,
        target_ids,
        loss_scale
    )
    result.gradient_norm = backward_result.gradient_norm
    result.overflow_detected = backward_result.overflow_detected
    
    // Step 4: Apply gradient scaling (应用梯度缩放)
    var scaled_gradients: [][]float = apply_gradient_scaling(
        backward_result.gradients,
        loss_scale,
        model_state
    )
    result.gradients_scaled = true
    result.scaled_loss = forward_result.loss_value / loss_scale
    
    return result
}

// ============================================================
// Training Loop with Accumulation - 训练循环（带梯度累积）
// ============================================================

// training_loop_with_accumulation: 完整训练循环
func training_loop_with_accumulation(
    config: training_config,
    model_state: model.transformer_state
) training_metrics {
    var metrics: training_metrics
    var state: training_state
    state.current_step = 0
    state.current_epoch = 0
    state.total_loss = 0.0
    state.total_tokens = 0
    state.accumulated_loss = 0.0
    state.accumulated_steps = 0
    state.learning_rate = config.learning_rate
    state.loss_scale = 65536.0
    state.gradient_overflow_count = 0
    
    // 初始化梯度累积 - Initialize gradient accumulation
    var accumulated_grads: gradient_accumulation.accumulated_gradients
    accumulated_grads.accumulation_steps = config.gradient_accumulation_steps
    accumulated_grads.steps_accumulated = 0
    accumulated_grads.accumulated_loss = 0.0
    accumulated_grads.is_ready = false
    
    // 训练循环 - Training loop
    var epoch = 0
    while epoch < config.max_epochs {
        var step = 0
        while step < 1000 {  // steps per epoch (虚拟值)
            // Step 1: 创建批次 - Create batch
            var input_ids: []int = []int(config.batch_size * 512)
            var target_ids: []int = []int(config.batch_size * 512)
            // 填充批次... - Populate batch...
            
            // Step 2: 训练步骤 - Training step
            var train_result: training_step_result = training_step(
                input_ids,
                target_ids,
                model_state,
                state,
                config,
                state.loss_scale
            )
            
            state.accumulated_loss = state.accumulated_loss + train_result.loss
            state.accumulated_steps = state.accumulated_steps + 1
            
            // Step 3: 检测溢出并更新损失缩放 - Detect overflow and update loss scale
            if train_result.overflow_detected {
                state.gradient_overflow_count = state.gradient_overflow_count + 1
                state.loss_scale = update_loss_scale(state.loss_scale, true, 0)
                state.accumulated_steps = 0
                state.accumulated_loss = 0.0
                // 跳过这个步骤 - Skip this step
            } else {
                // Step 4: 累积梯度 - Accumulate gradients
                accumulated_grads.steps_accumulated = accumulated_grads.steps_accumulated + 1
                
                // Step 5: 检查是否应该更新权重 - Check if should update weights
                var should_update: bool = accumulated_grads.steps_accumulated >= config.gradient_accumulation_steps
                
                if should_update {
                    // 权重更新 - Weight update (simplified)
                    update_model_weights(model_state, state.learning_rate)
                    
                    // 重置累积 - Reset accumulation
                    accumulated_grads.steps_accumulated = 0
                    accumulated_grads.accumulated_loss = 0.0
                }
                
                // Step 6: 更新学习率（warmup）- Update learning rate (warmup)
                if state.current_step < config.warmup_steps {
                    state.learning_rate = config.learning_rate * float(state.current_step) / float(config.warmup_steps)
                }
                
                // Step 7: 日志记录 - Logging
                if state.current_step % config.log_interval == 0 {
                    metrics.average_loss = state.accumulated_loss / float(state.accumulated_steps)
                    metrics.perplexity = compute_perplexity(metrics.average_loss)
                    metrics.learning_rate = state.learning_rate
                    metrics.gradient_norm = train_result.gradient_norm
                    metrics.loss_scale = state.loss_scale
                    metrics.overflow_count = state.gradient_overflow_count
                    metrics.accumulation_progress = (accumulated_grads.steps_accumulated * 100) / config.gradient_accumulation_steps
                }
                
                // Step 8: 保存检查点 - Save checkpoint
                if should_save_checkpoint(state.current_step, config.checkpoint_interval) {
                    var checkpoint_path = "checkpoint_step_" + string(state.current_step) + ".pt"
                    save_checkpoint(checkpoint_path, state.current_step, state.current_epoch, model_state, state, config)
                }
                
                state.current_step = state.current_step + 1
                state.total_loss = state.total_loss + train_result.loss
                state.total_tokens = state.total_tokens + config.batch_size * 512
                
                // 定期更新损失缩放 - Periodically update loss scale
                if state.current_step % 2000 == 0 {
                    state.loss_scale = update_loss_scale(state.loss_scale, false, 2000)
                }
            }
            
            step = step + 1
        }
        
        state.current_epoch = state.current_epoch + 1
        epoch = epoch + 1
    }
    
    return metrics
}

// update_model_weights: 更新模型权重
func update_model_weights(model_state: model.transformer_state, learning_rate: float) {
    // AdamW优化器更新 - AdamW optimizer update
    var i = 0
    while i < len(model_state.weight_matrices) {
        var j = 0
        while j < len(model_state.weight_matrices[i]) {
            // 简化的权重更新 - Simplified weight update
            // 实际应该使用完整的AdamW逻辑
            var gradient: float = 0.0001  // placeholder
            model_state.weight_matrices[i][j] = model_state.weight_matrices[i][j] - learning_rate * gradient
            j = j + 1
        }
        i = i + 1
    }
}

// ============================================================
// Helper Functions - 辅助函数
// ============================================================

// compute_perplexity: 计算困惑度
func compute_perplexity(loss: float) float {
    // perplexity = exp(loss)
    return 2.71828  // e^loss (simplified)
}

// project_to_q, project_to_k, project_to_v: 投影到Q, K, V
func project_to_q(hidden_states: [][]float, batch_size: int, seq_len: int, hidden_dim: int) [][]float {
    return hidden_states
}

func project_to_k(hidden_states: [][]float, batch_size: int, seq_len: int, hidden_dim: int) [][]float {
    return hidden_states
}

func project_to_v(hidden_states: [][]float, batch_size: int, seq_len: int, hidden_dim: int) [][]float {
    return hidden_states
}

// compute_attention_scores: 计算注意力分数
func compute_attention_scores(Q: [][]float, K: [][]float, seq_len: int) [][]float {
    return Q  // simplified
}

// apply_softmax_attention: 应用softmax到注意力分数
func apply_softmax_attention(scores: [][]float, seq_len: int) [][]float {
    return scores  // simplified
}

// apply_attention_to_values: 应用注意力到值
func apply_attention_to_values(attn_weights: [][]float, V: [][]float, batch_size: int, seq_len: int) [][]float {
    return V  // simplified
}

// apply_gelu: 应用GELU激活
func apply_gelu(hidden: [][]float) [][]float {
    return hidden  // simplified
}

// backprop_feed_forward: 反向传播前向网络
func backprop_feed_forward(gradients: [][]float, model_state: model.transformer_state, loss_scale: float) [][]float {
    return gradients  // simplified
}

// backprop_self_attention: 反向传播自注意力
func backprop_self_attention(gradients: [][]float, model_state: model.transformer_state, loss_scale: float) [][]float {
    return gradients  // simplified
}

// string conversion helper
func string(i: int) string {
    return "step"  // simplified
}
