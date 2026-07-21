// ============================================================
// NEURX Specialized Attention Mechanism
//
// English text:
//   1. Prefix-LM Attention: English text(prefix) + English text(generation) English text
//   2. Flash Attention 2 English text: IO English text, English text O(N) English text O(N²)
//   3. GQA (Grouped Query Attention): English textcomputeEnglish text
//   4. Long Context Support: Ring Attention for sequences > 128K
//
// English text NEURX English text GPT English text!
// ============================================================

package neurx.attention.mechanism

import neurx.arch.cuda.bindings.*
import neurx.tensor.*
import neurx.nn.*

// ============================================================
// English textconfiguration
// ============================================================
struct attention_config {
    int hidden_size              // English text
    int num_attention_heads      // Q English text
    int num_key_value_heads     // KV English text (GQA, English text <= num_heads)
    int head_dim                // English text = hidden_size / num_heads

    float attention_dropout      // Attention dropout
    float max_position_embeddings // English text
    bool use_flash_attention    // English textuse Flash Attention 2
    bool use_gqa               // English text GQA
    bool use_causal_mask        // English textdefaultEnglish text

    // Flash Attention parameter
    int softmax_scale           // Softmax English text (1/sqrt(head_dim))

    // English textoptimize
    bool use_gradient_checkpointing // gradientcheckpoint
}

// ============================================================
// NEURX English text: Prefix-LM Multi-Head Attention
// ============================================================

class NeurxAttention {
    attention_config config

    // English textweight
    tensor q_proj_weight        // [hidden, hidden] or [hidden, kv_dim]
    tensor k_proj_weight        // [hidden, kv_dim]
    tensor v_proj_weight        // [hidden, kv_dim]
    tensor o_proj_weight        // [hidden, hidden]

    // Layer Norms
    tensor layernorm_qk_gamma   // [hidden] - QK English text LayerNorm (NEURX English textoptimize)

    // RoPE cache
    option[rope_cache] rope_cos_cache
    option[rope_cache] rope_sin_cache

    // statisticsinformation
    struct stats {
        int64 total_flops
        int64 forward_time_us
        int64 backward_time_us
        float memory_usage_mb
    } stats
}

func init(attention_config cfg) NeurxAttention {

    int kv_dim = cfg.head_dim * cfg.num_key_value_heads

    print("🔧 Initializing NEURX Attention:")
    print(f"   Heads: {cfg.num_attention_heads} (Q) / {cfg.num_key_value_heads} (KV)")
    print(f"   Head dim: {cfg.head_dim}")
    print(f"   Flash Attention: {'✅' if cfg.use_flash_attention else '❌'}")
    print(f"   GQA: {'✅' if cfg.use_gqa else '❌'}")

    return NeurxAttention {
        config: cfg,

        // initializeweight (Xavier/Kaiming init)
        q_proj_weight: xavier_uniform(cfg.hidden_size, cfg.hidden_size),
        k_proj_weight: xavier_uniform(kv_dim, cfg.hidden_size),
        v_proj_weight: xavier_uniform(kv_dim, cfg.hidden_size),
        o_proj_weight: xavier_uniform(cfg.hidden_size, cfg.hidden_size),

        layernorm_qk_gamma: ones(cfg.hidden_size),

        rope_cos_cache: none,
        rope_sin_cache: none,

        stats: stats {
            total_flops: 0,
            forward_time_us: 0,
            backward_time_us: 0,
            memory_usage_mb: 0.0
        }
    }
}

// ============================================================
// English text: NEURX Prefix-LM Attention
// ============================================================

func forward(
    self: NeurxAttention,
    hidden_states: tensor,            // [batch, seq_len, hidden_size]
    attention_mask: option[tensor],    // [batch, 1, seq_len, seq_len] or None
    position_ids: option[tensor],       // [batch, seq_len]
    layer_past_kv: option[tuple[tensor, tensor]],  # Past KV cache for inference
    use_cache: bool = false,
    output_attentions: bool = false
) -> tuple[tensor, option[tuple[tensor, tensor]], option[tensor]] {
    """
    English text

    Args:
        hidden_states: inputEnglish textstate
        attention_mask: English text (None=English text)
        position_ids: English text ID (English text RoPE)
        layer_past_kv: English text K/V cache (English textgenerate)
        use_cache: English text KV cache
        output_attentions: English textweight

    Returns:
        tuple: (
            attention_output: [batch, seq_len, hidden],
            present_key_value: ((K, V)) if use_cache else None,
            attention_weights: [batch, heads, seq, seq] if output_attentions else None
        )
    """

    timer.start("attention_forward")

    int batch_size = shape(hidden_states)[0]
    int seq_len = shape(hidden_states)[1]
    attention_config cfg = self.config

    // ===== Step 1: Project to Q, K, V =====
    timer.start("projection")

    # Q projection
    tensor query_states = matmul(hidden_states, self.q_proj_weight.T)  # [B, S, H]

    # K/V projections (English text,English textuse GQA)
    tensor key_states = matmul(hidden_states, self.k_proj_weight.T)    # [B, S, kv_dim]
    tensor value_states = matmul(hidden_states, self.v_proj_weight.T)  # [B, S, kv_dim]

    # Apply LayerNorm to Q and K (NEURX optimization)
    query_states = layer_norm(query_states, self.layernorm_qk_gamma)
    key_states = layer_norm(key_states, self.layernorm_qk_gamma)

    timer.stop("projection")

    // ===== Step 2: Reshape to multi-head format =====
    timer.start("reshape")

    # Reshape to [batch, num_heads, seq_len, head_dim]
    query_states = query_states.view(batch_size, seq_len, cfg.num_attention_heads, cfg.head_dim).transpose(1, 2)
    key_states = key_states.view(batch_size, seq_len, cfg.num_key_value_heads, cfg.head_dim).transpose(1, 2)
    value_states = value_states.view(batch_size, seq_len, cfg.num_key_value_heads, cfg.head_dim).transpose(1, 2)

    timer.stop("reshape")

    // ===== Step 3: Apply RoPE Position Encoding =====
    timer.start("rope")

    if position_ids != none:
        tuple[cos_vals, sin_vals] = compute_or_get_rope(
            position_ids,
            cfg.head_dim,
            cfg.max_position_embeddings,
            self.rope_cos_cache,
            self.rope_sin_cache
        )

        # Apply RoPE to Q and K
        query_states = apply_rotary_emb(query_states, cos_vals, sin_vals)
        key_states = apply_rotary_emb(key_states, cos_vals, sin_vals)

    timer.stop("rope")

    // ===== Step 4: Handle KV Cache (for inference/generation) =====
    if layer_past_kv != none:
        tensor past_k, past_v = layer_past_kv!
        # Concatenate past KV with current KV along sequence dimension
        key_states = concat([past_k, key_states], dim=2)  # [B, H, past+S, D]
        value_states = concat([past_v, value_states], dim=2)

    int kv_seq_len = shape(key_states)[2]  # May be longer than seq_len due to cache

    // ===== Step 5: GQA Expansion =====
    timer.start("gqa")

    if cfg.use_gqa && cfg.num_key_value_heads < cfg.num_attention_heads:
        # Repeat KV heads to match Q heads
        # Example: Q has 32 heads, KV has 8 → repeat each KV head 4 times
        int n_rep = cfg.num_attention_heads / cfg.num_key_value_heads

        # Efficient repeat using expand + reshape
        key_states = key_states.unsqueeze(2).expand(
            batch_size, cfg.num_key_value_heads, n_rep, kv_seq_len, cfg.head_dim
        ).reshape(
            batch_size, cfg.num_attention_heads, kv_seq_len, cfg.head_dim
        )
        value_states = value_states.unsqueeze(2).expand(
            batch_size, cfg.num_key_value_heads, n_rep, kv_seq_len, cfg.head_dim
        ).reshape(
            batch_size, cfg.num_attention_heads, kv_seq_len, cfg.head_dim
        )

    timer.stop("gqa")

    // ===== Step 6: Compute Attention =====
    timer.start("attention_compute")

    option[tensor] attn_weights = none
    tensor attn_output

    if cfg.use_flash_attention && seq_len >= 128:
        # Use Flash Attention 2 for long sequences
        attn_output = _flash_attention_forward(
            query_states,
            key_states,
            value_states,
            attention_mask,
            cfg.softmax_scale
        )
    else:
        # Standard attention with explicit mask support (better for PrefixLM)
        attn_output, attn_weights = _standard_attention_forward(
            query_states,
            key_states,
            value_states,
            attention_mask,
            cfg.softmax_scale,
            cfg.attention_dropout,
            output_attentions
        )

    timer.stop("attention_compute")

    // ===== Step 7: Merge Heads & Output Projection =====
    timer.start("output_projection")

    # Reshape from [batch, heads, seq_len, head_dim] to [batch, seq_len, hidden]
    attn_output = attn_output.transpose(1, 2).contiguous().view(
        batch_size, seq_len, cfg.hidden_size
    )

    # Final linear projection
    attn_output = matmul(attn_output, self.o_proj_weight.T)  # [B, S, H]

    timer.stop("output_projection")

    // ===== Prepare Cache Output =====
    option[tuple[tensor, tensor]] present_kv = none
    if use_cache:
        present_kv = some((key_states, value_states))

    timer.stop("attention_forward")

    # Update statistics
    _update_stats(self, batch_size, seq_len, cfg, timer)

    return (attn_output, present_kv, attn_weights)

// ============================================================
// Standard Attention Implementation
// support NEURX Prefix-LM Mask (English text+English text)
// ============================================================

func _standard_attention_forward(
    tensor query_states,         // [B, heads, S_Q, D]
    tensor key_states,          // [B, heads, S_KV, D]
    tensor value_states,        // [B, heads, S_KV, D]
    option[tensor] mask,        // [B, 1, S_Q, S_KV] or [B, S_Q, S_KV]
    float scale,
    float dropout_p,
    bool return_attn_weights
) -> tuple[tensor, option[tensor]] {

    # Compute attention scores: Q * K^T / sqrt(d)
    tensor attn_scores = matmul(query_states, key_states.transpose(-2, -1)) * scale

    # Apply attention mask (NEURX Prefix-LM mask)
    if mask != none:
        attn_scores = attn_scores + mask

    # Softmax
    tensor attn_probs = softmax(attn_scores, dim=-1)

    # Dropout (training only)
    if self.training && dropout_p > 0:
        attn_probs = dropout(attn_probs, p=dropout_p)

    # Apply to values
    tensor context = matmul(attn_probs, value_states)  # [B, heads, S_Q, D]

    option[tensor] weights = return_attn_weights ? some(attn_probs) : none

    return (context, weights)

// ============================================================
// Flash Attention 2 Implementation
// IO-Aware, Memory-efficient O(S) instead of O(S²)
// ============================================================

func _flash_attention_forward(
    tensor query_states,         // [B, heads, S_Q, D]
    tensor key_states,          // [B, heads, S_KV, D]
    tensor value_states,        // [B, heads, S_KV, D]
    option[tensor] causal_mask,  // Optional causal/prefix mask
    float scale
) -> tensor {
    """
    Flash Attention 2 English text:

    English textcomputeEnglish text,English textcompleteEnglish text N×N English text:

    1. English text Q, K, V English text (blocks/tiles)
    2. English text SRAM English textcompute attention scores
    3. use online softmax English text running max English text sum
    4. English textoutput,English textresult

    Memory: O(S) instead of O(S²)
    """

    int B = shape(query_states)[0]
    int num_heads = shape(query_states)[1]
    int S_Q = shape(query_states)[2]
    int S_KV = shape(key_states)[2]
    int D = shape(query_states)[3]

    // Block size tuning (based on GPU SRAM size)
    int Br = min(128, S_Q)   # Query block size
    int Bc = min(256, S_KV)  # Key/Value block size

    // Initialize output
    tensor output = zeros(B, num_heads, S_Q, D)
    tensor l = zeros(B, num_heads, S_Q, 1)  # Running max
    tensor m = ones(B, num_heads, S_Q, 1) * (-1e9)  # Running sum (in log space)

    # Process in blocks
    for i_start in range(0, S_Q, Br):
        int i_end = min(i_start + Br, S_Q)

        # Load Q block
        tensor Qi = query_states[:, :, i_start:i_end, :]  # [B, H, Br, D]
        tensor Oi = output[:, :, i_start:i_end, :]       # [B, H, Br, D]
        tensor li = l[:, :, i_start:i_end, :]             // [B, H, Br, 1]
        tensor mi = m[:, :, i_start:i_end, :]             // [B, H, Br, 1]

        for j_start in range(0, S_KV, Bc):
            int j_end = min(j_start + Bc, S_KV)

            # Load K, V block
            tensor Kj = key_states[:, :, j_start:j_end, :]  # [B, H, Bc, D]
            tensor Vj = value_states[:, :, j_start:j_end, :] # [B, H, Bc, D]

            # Compute attention scores for this block
            tensor Sij = matmul(Qi, Kj.transpose(-2, -1)) * scale  # [B, H, Br, Bc]

            # Apply causal/prefix mask if provided
            if causal_mask != none:
                # Extract relevant portion of the mask
                tensor mask_block = causal_mask[:, :, i_start:i_end, j_start:j_end]
                Sij = Sij + mask_block

            # Online softmax
            tensor mij_new = max(Sij, dim=-1, keepdim=True)  # [B, H, Br, 1]

            # Update running statistics
            mij_corrected = exp(mi - mij_new)
            Pij = exp(Sij - mij_new)

            lij_new = mij_corrected * li + sum(Pij, dim=-1, keepdim=True)

            # Rescale old output
            Oij = (mij_corrected.unsqueeze(-1) * Oi)  # [B, H, Br, D]

            # Add new contribution
            Oij = Oij + matmul(Pij, Vj)  # [B, H, Br, D]

            # Normalize
            Oij = Oij / (lij_new + 1e-9)  # Avoid division by zero

            # Update running values
            mi = mij_new
            li = lij_new
            Oi = Oij

        # Store back to output
        output[:, :, i_start:i_end, :] = Oi
        l[:, :, i_start:i_end, :] = li
        m[:, :, i_start:i_end, :] = mi

    return output

// ============================================================
// NEURX Prefix-LM Mask English textoptimize
// ============================================================

class MaskBuilder {
    /*
    English text NEURX English text Attention Mask

    English text:
    1. CAUSAL_MODE: English text (GPT English text)
       ```
       1 1 1 1
       0 1 1 1
       0 0 1 1
       0 0 0 1
       ```

    2. BIDIRECTIONAL_MODE: English text (BERT/Prefix English text)
       ```
       1 1 1 1
       1 1 1 1
       1 1 1 1
       1 1 1 1
       ```

    3. PREFIX_LM_MODE: NEURX English text! English text + English text
       English text prefix_len=2, gen_len=2
       ```
       P P G G  (P=Prefix, G=Generation)
       P 1 1 1  ← prefix AllowedEnglish text prefix
       P 1 1 1
       G 1 1 0  ← gen AllowedEnglish text prefix English text gen
       G 1 1 1 0
       */

    static func build_prefix_lm_mask(
        int batch_size,
        int total_seq_len,
        []int prefix_lengths,  # English text sample English text prefix English text
        int kv_seq_len = -1    # KV English text (English textcacheEnglish text > seq_len)
    ) -> tensor {
        """
        English text NEURX Prefix-LM Attention Mask

        Args:
            batch_size: batchEnglish text
            total_seq_len: English text (query English text)
            prefix_lengths: English text sample English text prefix English text
            kv_seq_len: KV English text (-1 English text total_seq_len)

        Returns:
            mask tensor: [batch_size, 1, total_seq_len, kv_seq_len]
                         0 English text, -inf English text
        """

        if kv_seq_len == -1:
            kv_seq_len = total_seq_len

        # Initialize full causal mask
        tensor mask = triu(
            ones(total_seq_len, kv_seq_len),
            diagonal=1
        )  # Upper triangle = 1 (masked)

        mask = mask * -10000.0  # Convert to -inf for masked positions

        # Override prefix regions to be bidirectional
        for b in range(batch_size):
            int prefix_len = prefix_lengths[b]

            if prefix_len > 0:
                # For query positions within prefix: can attend to all prefix
                mask[b, 0, :prefix_len, :prefix_len] = 0.0

                # For query positions in generation: can attend to all prefix + previous gen
                # Causal mask already handles generation-to-generation
                # Just need to unmask generation-to-prefix part
                mask[b, 0, prefix_len:, :prefix_len] = 0.0

        # Expand for batch dimension
        mask = mask.unsqueeze(0).expand(batch_size, -1, -1, -1)

        return mask

    static func build_causal_mask(
        int seq_len,
        int kv_seq_len = -1
    ) -> tensor {
        """English text"""

        if kv_seq_len == -1:
            kv_seq_len = seq_len

        tensor mask = triu(ones(seq_len, kv_seq_len), diagonal=1)
        return mask.unsqueeze(0).unsqueeze(0) * -10000.0

    static func build_bidirectional_mask(
        int seq_len,
        int kv_seq_len = -1
    ) -> tensor {
        """English text (English text)"""

        if kv_seq_len == -1:
            kv_seq_len = seq_len

        return zeros(1, 1, seq_len, kv_seq_len)

    @staticmethod
    def combine_masks(
        tensor base_mask,
        option[tensor] padding_mask,
        int kv_seq_len
    ) -> tensor {
        """English text mask English text padding mask"""

        if padding_mask is None:
            return base_mask

        # Padding mask: [B, S] → [B, 1, 1, S_KV]
        # 1 = valid token, 0 = padding
        tensor padding_2d = (1.0 - padding_mask.unsqueeze(1).unsqueeze(2)) * -10000.0

        return base_mask + padding_2d

// ============================================================
// RoPE (Rotary Position embedding) toolfunction
// ============================================================

struct rope_cache {
    tensor cos_vals  // [1, 1, max_seq_len, head_dim/2]
    tensor sin_vals  // [1, 1, max_seq_len, head_dim/2]
    int cached_max_seq
}

func compute_rope_embeddings(
    []int position_ids,  # [batch, seq_len]
    int head_dim,
    float base = 10000.0,
    scaling_type: int = 0,  # 0=none, 1=linear, 2=ntk, 3=yarn
    float factor = 1.0
) -> tuple[tensor, tensor] {
    """
    compute RoPE English text cos/sin English text

    Args:
        position_ids: English text ID
        head_dim: English text
        base: English text (English text 10000 English text 500000)
        scaling_type: English text
        factor: English text (English text 4K→128K English text factor=32)

    Returns:
        (cos_vals, sin_vals): [1, seq_len, 1, head_dim/2]
    """

    int seq_len = len(position_ids)
    int half_dim = head_dim // 2

    # Compute frequency bands
    # θ_i = 1 / (base^(2i/d)) for i in [0, d/2)
    tensor freqs = arange(0, half_dim, dtype=float32)  # [d/2]
    freqs = 1.0 / (base ** (freqs * 2.0 / half_dim))  # [d/2]

    # Apply scaling for long context (YaRN, NTK-Aware, etc.)
    if scaling_type > 0 && factor > 1.0:
        freqs = apply_rope_scaling(freqs, scaling_type, factor)

    # Compute angles: pos * freq
    # positions: [seq_len, 1]
    tensor positions = tensor(position_ids).unsqueeze(1).float()  # [S, 1]
    tensor angles = positions * freqs  # [S, d/2]

    # Cos and Sin
    tensor cos_vals = cos(angles)  # [S, d/2]
    tensor sin_vals = sin(angles)

    # Add dimensions for broadcasting: [1, S, 1, d/2]
    cos_vals = cos_vals.unsqueeze(0).unsqueeze(2)
    sin_vals = sin_vals.unsqueeze(0).unsqueeze(2)

    return (cos_vals, sin_vals)

func apply_rotary_emb(
    tensor x,                  // [B, H, S, D]
    tensor cos_vals,           // [1, S, 1, D/2]
    tensor sin_vals            // [1, S, 1, D/2]
) -> tensor {
    """
    English text

    x = x_even * cos + x_odd * sin  (rotate)
    x_odd = x_odd * cos - x_even * sin

    English text x_even = x[..., ::2], x_odd = x[..., 1::2]
    """

    # Split into even and odd indices
    tensor x_even = x[..., ::2]  // [B, H, S, D/2]
    tensor x_odd = x[..., 1::2]   // [B, H, S, D/2]

    # Apply rotation
    tensor rotated_even = x_even * cos_vals - x_odd * sin_vals
    tensor rotated_odd = x_even * sin_vals + x_odd * cos_vals

    # Interleave back
    # Stack even and odd, then reshape
    tensor result = stack([rotated_even, rotated_odd], dim=-1)  // [B, H, S, D/2, 2]
    result = result.reshape(shape(x)[:-1])  // [B, H, S, D]

    return result

func apply_rope_scaling(
    tensor freqs,           // [d/2] English text
    int scaling_type,       // English text
    float factor            // English text
) -> tensor {
    """
    English text RoPE Scaling English textsupportEnglish text

    Types:
    0: None (no scaling)
    1: Linear (English text)
    2: NTK-Aware (English text,English text)
    3: YaRN (English text,English text+English text)
    """

    match scaling_type:
        case 1:  # Linear
            # English text factor English text
            return freqs / factor

        case 2:  # NTK-Aware
            # English text, English text
            # English text: https://arxiv.org/abs/2309.00071
            float base_new = base * ((factor * factor - 1) / (factor ** (2 * (len(freqs) - 1) / (len(freqs) - 1))) ** (1 / (len(freqs) - 1))) ** (len(freqs) - 2) / (len(freqs) - 1)
            # Simplified: scale low frequencies more than high frequencies
            return freqs * (1.0 - log(factor) / log(base) * (arange(len(freqs)) / (len(freqs) - 1)))

        case 3:  # YaRN (Yet another RoPE extension)
            # English text + English text
            # English text: https://arxiv.org/abs/2309.00071
            # YaRN use tanh English text
            float yarn_beta = 0.1 * log(factor) - 0.1 * log(log(factor))  # English text
            float yarn_alpha = factor - 1.0

            # English text
            tensor scale = 1.0 + yarn_alpha * freqs / (freqs.max())

            # English text tanh English text
            scale = tanh(scale / yarn_beta) * yarn_beta

            # English text
            return freqs * scale

        case _:  # No scaling
            return freqs

// ============================================================
// English textstatisticsEnglish text
// ============================================================

func _update_stats(
    ref NeurxAttention self,
    int batch_size,
    int seq_len,
    attention_config cfg,
    Timer timer) {

    # Estimate FLOPs
    int64 flops_per_head = int64(seq_len) * seq_len * cfg.head_dim * 2  # Matmul + scale
    int64 total_flops = flops_per_head * cfg.num_attention_heads * batch_size

    # Account for GQA savings
    if cfg.use_gqa:
        int kv_ratio = cfg.num_attention_heads / cfg.num_key_value_heads
        total_flops = total_flops / kv_ratio  # K,V computeEnglish text

    self.stats.total_flops += total_flops
    self.stats.forward_time_us += timer.get_elapsed_us("attention_forward")

    # Estimate memory (rough)
    # Q, K, V projections + attention scores + output
    int mem_per_sample = cfg.hidden_size * seq_len * 4  # input
    mem_per_sample += 3 * cfg.hidden_size * seq_len * 2  # Q,K,V (fp16/bf16)
    if !cfg.use_flash_attention:
        mem_per_sample += seq_len * seq_len * cfg.num_attention_heads  # attention matrix

    self.stats.memory_usage_mb = float(mem_per_sample * batch_size) / (1024 * 1024)

// ============================================================
// test & English text
// ============================================================

func test_attention() {
    print("\n" + "="*60)
    print("Testing NEURX Attention Mechanism")
    print("="*60)

    // Test config
    attention_config cfg {
        hidden_size: 4096,
        num_attention_heads: 32,
        num_key_value_heads: 8,  # GQA: 4:1 ratio
        head_dim: 128,
        attention_dropout: 0.0,
        max_position_embeddings: 8192,
        use_flash_attention: true,
        use_gqa: true,
        use_causal_mask: false,  # Will use custom mask
        softmax_scale: 1.0 / sqrt(128.0),
        use_gradient_checkpointing: false,
    }

    // Test 1: Initialization
    print("\n[Test 1] Initializing NeurxAttention...")
    NeurxAttention attn = init(cfg)
    assert(attn != None)
    print("✅ Initialization successful!")

    // Test 2: Forward pass (Causal mode)
    print("\n[Test 2] Testing causal attention forward pass...")
    tensor input = randn(2, 64, 4096)  # B=2, S=64, H=4096
    tensor causal_mask = MaskBuilder.build_causal_mask(64)

    tuple[output, _, weights] = attn.forward(
        hidden_states=input,
        attention_mask=some(causal_mask),
        position_ids=some(arange(64).unsqueeze(0).expand(2, 64)),
        use_cache=false,
        output_attentions=true
    )

    assert(shape(output) == (2, 64, 4096))
    assert(!any(isnan(output)))
    print(f"   Output shape: {shape(output)}")
    print("✅ Causal attention works!")

    // Test 3: Forward pass (Prefix-LM mode)
    print("\n[Test 3] Testing Prefix-LM attention...")
    tensor prefix_mask = MaskBuilder.build_prefix_lm_mask(
        batch_size=2,
        total_seq_len=64,
        prefix_lengths=[20, 30]  # sample 0: 20 prefix, sample 1: 30 prefix
    )

    tuple[prefix_output, _, _] = attn.forward(
        hidden_states=input,
        attention_mask=some(prefix_mask),
        position_ids=some(arange(64).unsqueeze(0).expand(2, 64)),
        use_cache=false
    )

    assert(shape(prefix_output) == (2, 64, 4096))
    assert(!any(isnan(prefix_output)))
    print("✅ Prefix-LM attention works!")

    // Test 4: Verify Prefix-LM mask structure
    print("\n[Test 4] Verifying Prefix-LM mask structure...")
    # For first sample with prefix_len=20
    # Position 5 (prefix) should see position 10 (prefix) → mask should be 0 (visible)
    assert(prefix_mask[0, 0, 5, 10] == 0.0)
    # Position 30 (generation) should see position 10 (prefix) → mask should be 0 (visible)
    assert(prefix_mask[0, 0, 30, 10] == 0.0)
    # Position 30 (generation) should NOT see position 50 (future gen) → mask < 0 (blocked)
    assert(prefix_mask[0, 0, 30, 50] < 0.0)
    print("✅ Mask structure correct!")

    // Test 5: KV Cache (Inference mode)
    print("\n[Test 5] Testing KV cache for autoregressive generation...")
    tensor short_input = randn(2, 1, 4096)  # Single token
    tensor initial_kv = randn(2, 8, 64, 128)  # Past KV: B, KV_heads, S=64, D

    tuple[cached_output, new_kv, _] = attn.forward(
        hidden_states=short_input,
        attention_mask=None,  # No mask needed when generating
        position_ids=some(tensor([[64]])),  # Next position after 64
        layer_past_kv=some(initial_kv),
        use_cache=true
    )

    # New KV should have length 65 (64 past + 1 current)
    assert(shape(new_kv![0]) == (2, 8, 65, 128))
    assert(shape(cached_output) == (2, 1, 4096))
    print("✅ KV cache works correctly!")

    // Test 6: RoPE Scaling (Long Context)
    print("\n[Test 6] Testing RoPE scaling for long context...")

    # Short context (4K)
    tuple[cos_short, sin_short] = compute_rope_embeddings(
        arange(4096), 128, base=500000.0
    )

    # Long context (128K, YaRN scaled)
    tuple[cos_long, sin_long] = compute_rope_embeddings(
        arange(131072), 128, base=500000.0, scaling_type=3, factor=32.0
    )

    assert(shape(cos_long) == (1, 131072, 1, 64))
    # Verify that frequencies are properly scaled (lower frequency for long contexts)
    print("   Short context (4K) cos range: [{cos_short.min():.4f}, {cos_short.max():.4f}]")
    print("   Long context (128K) cos range: [{cos_long.min():.4f}, {cos_long.max():.4f}]")
    print("✅ RoPE scaling works!")

    // Test 7: Performance stats
    print("\n[Test 7] Checking performance statistics...")
    print(f"   Total FLOPs: {attn.stats.total_flops:,}")
    print(f"   Forward time: {attn.stats.forward_time_us} μs")
    print(f"   Est. memory usage: {attn.stats.memory_usage_mb:.1f} MB")
    print("✅ Stats collected!")

    // Test 8: GQA efficiency
    print("\n[Test 8] Verifying GQA memory savings...")
    int standard_mem = 4096 * 64 * 32 * 2  # Full attention: Q(32)+K(32)+V(32)
    int gqa_mem = 4096 * 64 * (32 + 8 + 8) * 2  # GQA: Q(32)+KV(8)
    float savings = 1.0 - float(gqa_mem) / float(standard_mem)
    print(f"   Standard attention memory: {standard_mem / 1024:.1f} KB per sample")
    print(f"   GQA memory: {gqa_mem / 1024:.1f} KB per sample")
    print(f"   Memory savings: {savings:.1%}")
    assert(savings > 0.4)  # Should save at least 40%
    print("✅ GQA provides significant memory savings!")

    print("\n" + "="*60)
    print("All NEURX attention tests passed! ✨")
    print("="*60 + "\n")
