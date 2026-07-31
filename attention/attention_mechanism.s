package neurx.attention.mechanism
import neurx.arch.cuda.bindings.*
import neurx.tensor.*
import neurx.nn.*
struct attention_config {
    int hidden_size
    int num_attention_heads
    int num_key_value_heads
    int head_dim
    float attention_dropout
    float max_position_embeddings
    bool use_flash_attention
    bool use_gqa
    bool use_causal_mask
    int softmax_scale
    bool use_gradient_checkpointing
}
class NeurxAttention {
    attention_config config
    tensor q_proj_weight
    tensor k_proj_weight
    tensor v_proj_weight
    tensor o_proj_weight
    tensor layernorm_qk_gamma
    option[rope_cache] rope_cos_cache
    option[rope_cache] rope_sin_cache
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

func forward(
    self: NeurxAttention,
    hidden_states: tensor,
    attention_mask: option[tensor],
    position_ids: option[tensor],
    layer_past_kv: option[tuple[tensor, tensor]],
    use_cache: bool = false,
    output_attentions: bool = false
) {
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
    timer.start("projection")
    tensor query_states = matmul(hidden_states, self.q_proj_weight.T)
    tensor key_states = matmul(hidden_states, self.k_proj_weight.T)
    tensor value_states = matmul(hidden_states, self.v_proj_weight.T)
    query_states = layer_norm(query_states, self.layernorm_qk_gamma)
    key_states = layer_norm(key_states, self.layernorm_qk_gamma)
    timer.stop("projection")
    timer.start("reshape")
    query_states = query_states.view(batch_size, seq_len, cfg.num_attention_heads, cfg.head_dim).transpose(1, 2)
    key_states = key_states.view(batch_size, seq_len, cfg.num_key_value_heads, cfg.head_dim).transpose(1, 2)
    value_states = value_states.view(batch_size, seq_len, cfg.num_key_value_heads, cfg.head_dim).transpose(1, 2)
    timer.stop("reshape")
    timer.start("rope")
    if position_ids != none:
        tuple[cos_vals, sin_vals] = compute_or_get_rope(
            position_ids,
            cfg.head_dim,
            cfg.max_position_embeddings,
            self.rope_cos_cache,
            self.rope_sin_cache
        )
        query_states = apply_rotary_emb(query_states, cos_vals, sin_vals)
        key_states = apply_rotary_emb(key_states, cos_vals, sin_vals)
    timer.stop("rope")
    if layer_past_kv != none:
        tensor past_k, past_v = layer_past_kv!
        key_states = concat([past_k, key_states], dim=2)
        value_states = concat([past_v, value_states], dim=2)
    int kv_seq_len = shape(key_states)[2]
    timer.start("gqa")
    if cfg.use_gqa && cfg.num_key_value_heads < cfg.num_attention_heads:
        int n_rep = cfg.num_attention_heads / cfg.num_key_value_heads
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
    timer.start("attention_compute")
    option[tensor] attn_weights = none
    tensor attn_output
    if cfg.use_flash_attention && seq_len >= 128:
        attn_output = _flash_attention_forward(
            query_states,
            key_states,
            value_states,
            attention_mask,
            cfg.softmax_scale
        )
    else:
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
    timer.start("output_projection")
    attn_output = attn_output.transpose(1, 2).contiguous().view(
        batch_size, seq_len, cfg.hidden_size
    )
    attn_output = matmul(attn_output, self.o_proj_weight.T)
    timer.stop("output_projection")
    option[tuple[tensor, tensor]] present_kv = none
    if use_cache:
        present_kv = some((key_states, value_states))
    timer.stop("attention_forward")
    _update_stats(self, batch_size, seq_len, cfg, timer)
    return (attn_output, present_kv, attn_weights)
func _standard_attention_forward(
    tensor query_states,
    tensor key_states,
    tensor value_states,
    option[tensor] mask,
    float scale,
    float dropout_p,
    bool return_attn_weights
) {
    tensor attn_scores = matmul(query_states, key_states.transpose(-2, -1)) * scale
    if mask != none:
        attn_scores = attn_scores + mask
    tensor attn_probs = softmax(attn_scores, dim=-1)
    if self.training && dropout_p > 0:
        attn_probs = dropout(attn_probs, p=dropout_p)
    tensor context = matmul(attn_probs, value_states)
    option[tensor] weights = return_attn_weights ? some(attn_probs) : none
    return (context, weights)
func _flash_attention_forward(
    tensor query_states,
    tensor key_states,
    tensor value_states,
    option[tensor] causal_mask,
    float scale
) {
    """
    Flash attention 2 English text:
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
    int Br = min(128, S_Q)
    int Bc = min(256, S_KV)
    tensor output = zeros(B, num_heads, S_Q, D)
    tensor l = zeros(B, num_heads, S_Q, 1)
    tensor m = ones(B, num_heads, S_Q, 1) * (-1e9)
    for i_start in range(0, S_Q, Br):
        int i_end = min(i_start + Br, S_Q)
        tensor Qi = query_states[:, :, i_start:i_end, :]
        tensor Oi = output[:, :, i_start:i_end, :]
        tensor li = l[:, :, i_start:i_end, :]
        tensor mi = m[:, :, i_start:i_end, :]
        for j_start in range(0, S_KV, Bc):
            int j_end = min(j_start + Bc, S_KV)
            tensor Kj = key_states[:, :, j_start:j_end, :]
            tensor Vj = value_states[:, :, j_start:j_end, :]
            tensor Sij = matmul(Qi, Kj.transpose(-2, -1)) * scale
            if causal_mask != none:
                tensor mask_block = causal_mask[:, :, i_start:i_end, j_start:j_end]
                Sij = Sij + mask_block
            tensor mij_new = max(Sij, dim=-1, keepdim=True)
            mij_corrected = exp(mi - mij_new)
            Pij = exp(Sij - mij_new)
            lij_new = mij_corrected * li + sum(Pij, dim=-1, keepdim=True)
            Oij = (mij_corrected.unsqueeze(-1) * Oi)
            Oij = Oij + matmul(Pij, Vj)
            Oij = Oij / (lij_new + 1e-9)
            mi = mij_new
            li = lij_new
            Oi = Oij
        output[:, :, i_start:i_end, :] = Oi
        l[:, :, i_start:i_end, :] = li
        m[:, :, i_start:i_end, :] = mi
    return output
class MaskBuilder {
    static func build_prefix_lm_mask(
        int batch_size,
        int total_seq_len,
        []int prefix_lengths,
        int kv_seq_len = -1
    ) {
        """
        English text NEURX Prefix-LM attention Mask
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
        tensor mask = triu(
            ones(total_seq_len, kv_seq_len),
            diagonal=1
        )
        mask = mask * -10000.0
        for b in range(batch_size):
            int prefix_len = prefix_lengths[b]
            if prefix_len > 0:
                mask[b, 0, :prefix_len, :prefix_len] = 0.0
                mask[b, 0, prefix_len:, :prefix_len] = 0.0
        mask = mask.unsqueeze(0).expand(batch_size, -1, -1, -1)
        return mask
    static func build_causal_mask(
        int seq_len,
        int kv_seq_len = -1
    ) {
        """English text"""
        if kv_seq_len == -1:
            kv_seq_len = seq_len
        tensor mask = triu(ones(seq_len, kv_seq_len), diagonal=1)
        return mask.unsqueeze(0).unsqueeze(0) * -10000.0
    static func build_bidirectional_mask(
        int seq_len,
        int kv_seq_len = -1
    ) {
        """English text (English text)"""
        if kv_seq_len == -1:
            kv_seq_len = seq_len
        return zeros(1, 1, seq_len, kv_seq_len)
    @staticmethod
    def combine_masks(
        tensor base_mask,
        option[tensor] padding_mask,
        int kv_seq_len
    ) {
        """English text mask English text padding mask"""
        if padding_mask is None:
            return base_mask
        tensor padding_2d = (1.0 - padding_mask.unsqueeze(1).unsqueeze(2)) * -10000.0
        return base_mask + padding_2d
struct rope_cache {
    tensor cos_vals
    tensor sin_vals
    int cached_max_seq
}
func compute_rope_embeddings(
    []int position_ids,
    int head_dim,
    float base = 10000.0,
    scaling_type: int = 0,
    float factor = 1.0
) {
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
    int half_dim = head_dim
    tensor freqs = arange(0, half_dim, dtype=float32)
    freqs = 1.0 / (base ** (freqs * 2.0 / half_dim))
    if scaling_type > 0 && factor > 1.0:
        freqs = apply_rope_scaling(freqs, scaling_type, factor)
    tensor positions = tensor(position_ids).unsqueeze(1).float()
    tensor angles = positions * freqs
    tensor cos_vals = cos(angles)
    tensor sin_vals = sin(angles)
    cos_vals = cos_vals.unsqueeze(0).unsqueeze(2)
    sin_vals = sin_vals.unsqueeze(0).unsqueeze(2)
    return (cos_vals, sin_vals)
func apply_rotary_emb(
    tensor x,
    tensor cos_vals,
    tensor sin_vals
) {
    """
    English text
    x = x_even * cos + x_odd * sin  (rotate)
    x_odd = x_odd * cos - x_even * sin
    English text x_even = x[..., ::2], x_odd = x[..., 1::2]
    """
    tensor x_even = x[..., ::2]
    tensor x_odd = x[..., 1::2]
    tensor rotated_even = x_even * cos_vals - x_odd * sin_vals
    tensor rotated_odd = x_even * sin_vals + x_odd * cos_vals
    tensor result = stack([rotated_even, rotated_odd], dim=-1)
    result = result.reshape(shape(x)[:-1])
    return result
func apply_rope_scaling(
    tensor freqs,
    int scaling_type,
    float factor
) {
    """
    English text RoPE Scaling English textsupportEnglish text
    Types:
    0: None (no scaling)
    1: linear (English text)
    2: NTK-Aware (English text,English text)
    3: YaRN (English text,English text+English text)
    """
    match scaling_type:
        case 1:
            return freqs / factor
        case 2:
            float base_new = base * ((factor * factor - 1) / (factor ** (2 * (len(freqs) - 1) / (len(freqs) - 1))) ** (1 / (len(freqs) - 1))) ** (len(freqs) - 2) / (len(freqs) - 1)
            return freqs * (1.0 - log(factor) / log(base) * (arange(len(freqs)) / (len(freqs) - 1)))
        case 3:
            float yarn_beta = 0.1 * log(factor) - 0.1 * log(log(factor))
            float yarn_alpha = factor - 1.0
            tensor scale = 1.0 + yarn_alpha * freqs / (freqs.max())
            scale = tanh(scale / yarn_beta) * yarn_beta
            return freqs * scale
        case _:
            return freqs
func _update_stats(
    ref NeurxAttention self,
    int batch_size,
    int seq_len,
    attention_config cfg,
    Timer timer) {
    int64 flops_per_head = int64(seq_len) * seq_len * cfg.head_dim * 2
    int64 total_flops = flops_per_head * cfg.num_attention_heads * batch_size
    if cfg.use_gqa:
        int kv_ratio = cfg.num_attention_heads / cfg.num_key_value_heads
        total_flops = total_flops / kv_ratio
    self.stats.total_flops += total_flops
    self.stats.forward_time_us += timer.get_elapsed_us("attention_forward")
    int mem_per_sample = cfg.hidden_size * seq_len * 4
    mem_per_sample += 3 * cfg.hidden_size * seq_len * 2
    if !cfg.use_flash_attention:
        mem_per_sample += seq_len * seq_len * cfg.num_attention_heads
    self.stats.memory_usage_mb = float(mem_per_sample * batch_size) / (1024 * 1024)
func test_attention() {
    print("\n" + "="*60)
    print("Testing NEURX Attention Mechanism")
    print("="*60)
    attention_config cfg {
        hidden_size: 4096,
        num_attention_heads: 32,
        num_key_value_heads: 8,
        head_dim: 128,
        attention_dropout: 0.0,
        max_position_embeddings: 8192,
        use_flash_attention: true,
        use_gqa: true,
        use_causal_mask: false,
        softmax_scale: 1.0 / sqrt(128.0),
        use_gradient_checkpointing: false,
    }
    print("\n[Test 1] Initializing NeurxAttention...")
    NeurxAttention attn = init(cfg)
    assert(attn != None)
    print("✅ Initialization successful!")
    print("\n[Test 2] Testing causal attention forward pass...")
    tensor input = randn(2, 64, 4096)
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
    print("\n[Test 3] Testing Prefix-LM attention...")
    tensor prefix_mask = MaskBuilder.build_prefix_lm_mask(
        batch_size=2,
        total_seq_len=64,
        prefix_lengths=[20, 30]
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
    print("\n[Test 4] Verifying Prefix-LM mask structure...")
    assert(prefix_mask[0, 0, 5, 10] == 0.0)
    assert(prefix_mask[0, 0, 30, 10] == 0.0)
    assert(prefix_mask[0, 0, 30, 50] < 0.0)
    print("✅ Mask structure correct!")
    print("\n[Test 5] Testing KV cache for autoregressive generation...")
    tensor short_input = randn(2, 1, 4096)
    tensor initial_kv = randn(2, 8, 64, 128)
    tuple[cached_output, new_kv, _] = attn.forward(
        hidden_states=short_input,
        attention_mask=None,
        position_ids=some(tensor([[64]])),
        layer_past_kv=some(initial_kv),
        use_cache=true
    )
    assert(shape(new_kv![0]) == (2, 8, 65, 128))
    assert(shape(cached_output) == (2, 1, 4096))
    print("✅ KV cache works correctly!")
    print("\n[Test 6] Testing RoPE scaling for long context...")
    tuple[cos_short, sin_short] = compute_rope_embeddings(
        arange(4096), 128, base=500000.0
    )
    tuple[cos_long, sin_long] = compute_rope_embeddings(
        arange(131072), 128, base=500000.0, scaling_type=3, factor=32.0
    )
    assert(shape(cos_long) == (1, 131072, 1, 64))
    print("   Short context (4K) cos range: [{cos_short.min():.4f}, {cos_short.max():.4f}]")
    print("   Long context (128K) cos range: [{cos_long.min():.4f}, {cos_long.max():.4f}]")
    print("✅ RoPE scaling works!")
    print("\n[Test 7] Checking performance statistics...")
    print(f"   Total FLOPs: {attn.stats.total_flops:,}")
    print(f"   Forward time: {attn.stats.forward_time_us} μs")
    print(f"   Est. memory usage: {attn.stats.memory_usage_mb:.1f} MB")
    print("✅ Stats collected!")
    print("\n[Test 8] Verifying GQA memory savings...")
    int standard_mem = 4096 * 64 * 32 * 2
    int gqa_mem = 4096 * 64 * (32 + 8 + 8) * 2
    float savings = 1.0 - float(gqa_mem) / float(standard_mem)
    print(f"   Standard attention memory: {standard_mem / 1024:.1f} KB per sample")
    print(f"   GQA memory: {gqa_mem / 1024:.1f} KB per sample")
    print(f"   Memory savings: {savings:.1%}")
    assert(savings > 0.4)
    print("✅ GQA provides significant memory savings!")
    print("\n" + "="*60)
    print("All NEURX attention tests passed! ✨")
    print("="*60 + "\n")
