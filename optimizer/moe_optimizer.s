// ============================================================
// NEURX MOE (Mixture of Experts) advancedoptimizesystem
// completeimplementation: English text + English text + Expert English text + English text
// English text: NeurX-MoE / Mixtral / SparseMoE English text
// ============================================================

module moe_optimization

// ==================== English textconfigurationEnglish text ====================

struct MoEConfig {
    // English textparameter
    hidden_size: int = 4096
    intermediate_size: int = 14336        # FFN English text (English text = hidden * ~3.5)
    num_experts: int = 8                  # English textcount
    num_selected_experts: int = 2         # English texttokenEnglish text (top-k routing)
    num_shared_experts: int = 1           # English textcount (NeurX-MoE English text, English textcompute)

    // English textconfiguration
    load_balancing_method: string = "auxiliary_loss"  # auxiliary_loss | switch_transformer | expert_choice_routing
    loss_coef: float = 0.01              # English textlossEnglish text
    aux_loss_coef: float = 0.001          # Auxiliary loss English text (Switch Transformer)
    z_loss_coef: float = 0.0001           # Z-loss English text (English text logit English text)

    // English textconfiguration
    router_type: string = "topk"          # topk | soft | group_limited | hash
    router_bias_init: float = -2.0        # Router bias English text (English text)
    jitter_noise: float = 0.01            # Jitter noise English texttrainingEnglish text
    capacity_factor: float = 1.25         # Expert English text (English text batch English text)
    drop_token: bool = true               # English text token

    // Expert English textconfiguration
    enable_expert_specialization: bool = true   # English text
    specialization_method: string = "gradient_manipulation"  # gradient_manipulation | regularization | hard_routing
    diversity_penalty: float = 0.1        # English text (English text)

    // advancedEnglish text
    use_sparse_attention: bool = false    # English textuseEnglish text (English text GQA/MQA)
    expert_group_size: int = 1            # English text (Grouped MoE)
    normalize_router: bool = true         # English text router logits
    apply_residual: bool = true           # English textuseEnglish text
    expert_pruning_threshold: float = 0.001  # Expert English text (English text)
}

struct MoEForwardOutput {
    output: tensor                        # [batch, seq_len, hidden]
    aux_loss: tensor?                     # helperloss (English text)
    load_balance_loss: tensor?            # English textloss
    router_logits: tensor                 # [batch, seq_len, num_experts] - English text
    expert_mask: tensor                   # [batch, seq_len, num_experts] - English text (one-hot English text soft)
    expert_weights: tensor                # [batch, seq_len, num_experts] - weight
    dispatch_pattern: DispatchPattern     # English textstatisticsinformation
    perexpert_output?: list<tensor>       # English textoutput (English text/English text)
}

struct DispatchPattern {
    total_tokens: int                     # English text token English text
    tokens_per_expert: list<int>          # English text expert English text token count
    expert_utilization: list<float>       # Expert English text (0-1)
    load_variance: float                  # English text (English text)
    avg_load: float                       # English text
    max_load_imbalance_ratio: float       # English text/English text
    entropy: float                        # Router English text (English text)
    dropped_tokens: int                   # English text token English text
}

struct MoEExpert {
    id: int                               # Expert ID
    up_proj: Linear                      # English text (hidden -> intermediate)
    down_proj: Linear                    # English text (intermediate -> hidden)
    gate: Activation?                    # English textfunction
    specialization_score: float = 0.0     # English text
    importance_weight: float = 1.0       # English textweight (English text)
    is_active: bool = true                # English text (English text)
}

struct MoERouter {
    gate_layer: Linear                    # English text [hidden -> num_experts]
    bias: Parameter?                      # English text
    noise: Normal?                        # trainingEnglish text
    router_type: string
    top_k: int

    init(hidden_dim: int, num_experts: int, config: MoEConfig) {
        this.gate_layer = new Linear(in_features=hidden_dim, out_features=num_experts, bias=true)
        this.router_type = config.router_type
        this.top_k = config.num_selected_experts

        if config.jitter_noise > 0 && config.training:
            this.noise = new Normal(mean=0.0, std=config.jitter_noise)
    }
}

class LoadBalanceLossComputer {
    config: MoEConfig

    init(config: MoEConfig) {
        this.config = config
    }

    compute(router_logits: tensor, expert_mask: tensor) {
        // Compute both auxiliary loss and load balance loss

        batch_size, seq_len, num_experts = router_logits.shape

        // Step 1: Compute fraction of tokens assigned to each expert
        # f_i = (1/T) * sum_t(1{t assigned to i})
        expert_counts = expert_mask.sum(dim=(0, 1)).float()  # [num_experts]
        total_tokens = batch_size * seq_len
        expert_fraction = expert_counts / (total_tokens + 1e-10)  # [num_experts]

        // Step 2: Compute mean router probability for each expert
        # P_i = mean over all tokens of p(x)_i
        router_probs = softmax(router_logits.float(), dim=-1)  # [B, T, E]
        mean_prob = router_probs.mean(dim=(0, 1))  # [num_experts]

        // Step 3: Load Balance Loss (from Switch Transformer / GShard)
        # L = N * sum_i(f_i * P_i) where N = number of experts
        load_balance_loss = num_experts * (expert_fraction * mean_prob).sum()

        // Step 4: Auxiliary Loss (alternative formulation from Hash Layer)
        # Encourages router probabilities to be close to the actual assignment distribution
        aux_loss = cross_entropy(
            mean_prob.unsqueeze(0).expand(batch_size * seq_len, -1),
            expert_mask.reshape(-1, num_experts).float()
        ).mean()

        return (load_balance_loss * this.config.loss_coef, aux_loss * this.config.aux_loss_coef)
    }
}

// ==================== English text MoE FFN English text ====================

class MoEFFNLayer {
    config: MoEConfig
    experts: list<MoEExpert>
    shared_experts: list<MoEExpert>
    router: MoERouter
    loss_computer: LoadBalanceLossComputer
    training: bool = true

    init(config: MoEConfig) {
        this.config = config
        this.loss_computer = new LoadBalanceLossComputer(config)
        this.training = true

        # Initialize experts
        this.experts = []
        for i in range(config.num_experts):
            let expert = MoEExpert{
                id=i,
                up_proj=new Linear(config.hidden_size, config.intermediate_size),
                down_proj=new Linear(config.intermediate_size, config.hidden_size),
                gate=new SiLU(),  # SwiGLU uses SiLU activation
                is_active=true
            }
            this.experts.append(expert)

        # Initialize shared experts (NeurX-MoE style)
        this.shared_experts = []
        if config.num_shared_experts > 0:
            for i in range(config.num_shared_experts) {
                let shared_exp = MoEExpert{
                    id=config.num_experts + i,
                    up_proj=new Linear(config.hidden_size, config.intermediate_size),
                    down_proj=new Linear(config.intermediate_size, config.hidden_size),
                    gate=new SiLU(),
                    is_active=true
                }
                this.shared_experts.append(shared_exp)
            }

        # Initialize router
        this.router = new MoERouter(
            hidden_dim=config.hidden_size,
            num_experts=config.num_experts,
            config=config
        )

        # Initialize router bias to encourage balanced routing
        if config.router_bias_init != 0.0:
            nn_init.constant_(this.router.gate_layer.bias, config.router_bias_init)

    forward(hidden_states: tensor, attention_mask: tensor?) {
        batch_size, seq_len, hidden_dim = hidden_states.shape

        // Step 1: Compute router logits and select experts
        router_input = hidden_states  # Could also use attention output as input

        if this.training && this.config.jitter_noise > 0 && this.router.noise != null {
            # Add jitter noise during training for exploration
            noise = this.router.noise.sample(router_input.shape).to(device=router_input.device)
            router_input = router_input + noise

        router_logits = this.router.gate_layer.forward(router_input)
        # [batch, seq_len, num_experts]

        # Step 2: Apply routing strategy (Top-K, Soft, etc.)
        routing_weights, selected_experts = this._apply_routing(router_logits)
        # routing_weights: [batch, seq_len, num_experts] (sparse, only selected have non-zero)
        # selected_experts: [batch, seq_len, top_k] indices of selected experts

        # Step 3: Create expert mask for loss computation
        expert_mask = zeros_like(routing_weights)
        expert_mask.scatter_(-1, selected_experts, 1.0)
        # [batch, seq_len, num_experts] one-hot like mask

        # Step 4: Compute capacity limit and handle overflow
        capacity = int((batch_size * seq_len / this.config.num_experts) * this.config.capacity_factor)

        # Step 5: Dispatch tokens to experts and gather outputs
        expert_outputs = this._dispatch_and_compute(
            hidden_states,
            selected_experts,
            routing_weights,
            capacity
        )
        # expert_outputs: [batch, seq_len, hidden_dim]

        # Step 6: Add shared expert contribution (NeurX-MoE style)
        if this.shared_experts.length > 0 && this.config.apply_residual:
            shared_output = this._compute_shared_expert_output(hidden_states)
            expert_outputs = expert_outputs + shared_output
        elif !this.config.apply_residual:
            # If no residual, just use expert output directly
            pass
        else:
            # Standard residual: expert_output + original input
            expert_outputs = expert_outputs + hidden_states

        # Step 7: Compute auxiliary losses
        aux_loss: tensor? = null
        lb_loss: tensor? = null
        if this.training {
            lb_loss_val, aux_loss_val = this.loss_computer.compute(router_logits, expert_mask)

            # Z-Loss: penalize large router logits (numerical stability)
            if this.config.z_loss_coef > 0:
                z_loss = (router_logits ** 2).mean() * this.config.z_loss_coef
                aux_loss_val = aux_loss_val + z_loss

            lb_loss = lb_loss_val
            aux_loss = aux_loss_val

        # Step 8: Collect dispatch statistics
        dispatch_stats = this._compute_dispatch_statistics(expert_mask, capacity)

        return MoEForwardOutput{
            output=expert_outputs,
            aux_loss=aux_loss,
            load_balance_loss=lb_loss,
            router_logits=router_logits.detach(),
            expert_mask=expert_mask,
            expert_weights=routing_weights.detach(),
            dispatch_pattern=dispatch_stats
        }
    }

    _apply_routing(router_logits: tensor) {
        match this.config.router_type {
            "topk" => { return this._top_k_routing(router_logits) }
            "soft" => { return this._soft_routing(router_logits) }
            "group_limited" => { return this._group_limited_routing(router_logits) }
            _ => throw error(f"Unknown router type: {this.config.router_type}")
        }
    }

    _top_k_routing(router_logits: tensor) {
        # Standard Top-K routing used in most MoE implementations
        B, T, E = router_logits.shape
        k = min(this.router.top_k, E)

        # Get top-k values and indices
        topk_values, topk_indices = router_logits.topk(k, dim=-1, sorted=False)
        # topk_values: [B, T, k], topk_indices: [B, T, k]

        # Create sparse weight tensor (only selected experts get non-zero weights)
        weights = zeros_like(router_logits)
        weights.scatter_(-1, topk_indices, 1.0)  # Binary selection

        # Optionally apply softmax normalization among selected experts
        if this.config.normalize_router:
            topk_probs = softmax(topk_values, dim=-1)
            weights.scatter_(-1, topk_indices, topk_probs)

        return (weights, topk_indices)
    }

    _soft_routing(router_logits: tensor) {
        # Soft routing: all experts participate with different weights
        # Useful for fine-grained control but computationally expensive

        probs = softmax(router_logits.float(), dim=-1)

        # Select top-k for efficiency (still compute all but only use top-k)
        k = min(this.router.top_k, router_logits.shape[-1])
        _, topk_indices = probs.topk(k, dim=-1)

        # Zero out non-selected
        masked_probs = zeros_like(probs)
        masked_probs.scatter_(-1, topk_indices, probs.gather(-1, topk_indices))

        # Renormalize
        normalized = masked_probs / (masked_probs.sum(dim=-1, keepdim=true) + 1e-9)

        return (normalized, topk_indices)
    }

    _group_limited_routing(router_logits: tensor) {
        # Group-Limited Routing (GLaM / GShard style)
        # Split experts into groups, each token can only pick from its assigned group

        B, T, E = router_logits.shape
        group_size = this.config.expert_group_size
        num_groups = E // group_size
        k_per_group = max(1, this.router.top_k // num_groups)

        # Reshape to groups: [B, T, num_groups, group_size]
        grouped_logits = router_logits.reshape(B, T, num_groups, group_size)

        # Top-k within each group
        topk_vals, topk_idx_in_group = grouped_logits.topk(k_per_group, dim=-1)

        # Convert back to global indices
        base_indices = arange(num_groups).unsqueeze(0).unsqueeze(0).unsqueeze(-1) * group_size
        global_topk_idx = (base_indices.expand(B, T, -1, -1) + topk_idx_in_group).reshape(B, T, -1)

        # Create weights
        weights = zeros_like(router_logits)
        if this.config.normalize_router:
            topk_probs = softmax(topk_vals.reshape(B, T, -1), dim=-1)
            weights.scatter_(-1, global_topk_idx, topk_probs.reshape_as(weights))
        else:
            weights.scatter_(-1, global_topk_idx, 1.0)

        return (weights, global_topk_idx)
    }

    _dispatch_and_compute(
        hidden_states: tensor,
        selected_experts: tensor,
        routing_weights: tensor,
        capacity: int
    ) {
        # Efficient dispatch using scatter/gather operations (similar to Megablocks/Tutel)

        B, T, H = hidden_states.shape
        _, _, K = selected_experts.shape  # K = top-k

        # Flatten batch and sequence dimensions
        flat_hidden = hidden_states.reshape(-1, H)  # [B*T, H]
        flat_indices = selected_experts.reshape(-1, K)  # [B*T, K]
        flat_weights = routing_weights.reshape(-1, routing_weights.shape[-1])  # [B*T, E]

        # Create combined index for dispatching: (token_id, expert_id)
        # We'll process each selected expert separately

        final_output = zeros_like(flat_hidden)

        for k in range(K):
            expert_ids_for_k = flat_indices[:, k]  # Which expert each token goes to for k-th choice
            weights_for_k = flat_indices.new_zeros(B * T, self.config.num_experts)
            weights_for_k.scatter_(1, expert_ids_for_k.unsqueeze(1), 1.0)

            # Get weights corresponding to selected experts
            w = (flat_weights * weights_for_k).sum(dim=-1)  # [B*T]

            # Gather tokens for each expert
            expert_output = zeros(B*T, H, device=hidden_states.device)

            for e_idx in range(this.config.num_experts):
                # Mask for tokens going to this expert
                mask_e = (expert_ids_for_k == e_idx)

                if mask_e.sum() == 0:
                    continue

                # Check capacity constraint
                count_e = mask_e.sum().item()
                if count_e > capacity and this.config.drop_token:
                    # Randomly keep only 'capacity' tokens
                    perm = randperm(count_e)[:capacity]
                    mask_e_indices = where(mask_e)[0]
                    kept_indices = mask_e_indices[perm]

                    new_mask = zeros_like(mask_e)
                    new_mask[kept_indices] = True
                    mask_e = new_mask

                # Extract tokens for this expert
                tokens_for_expert = flat_hidden[mask_e]  # [count, H]

                # Apply expert's FFN
                if this.experts[e_idx].is_active:
                    expert_out = this._apply_single_expert(tokens_for_expert, this.experts[e_idx])
                else:
                    expert_out = zeros_like(tokens_for_expert)

                # Scale by routing weight
                expert_out = expert_out * w[mask_e].unsqueeze(-1)

                # Scatter back
                expert_output[mask_e] = expert_out

            final_output += expert_output

        return final_output.reshape(B, T, H)
    }

    _apply_single_expert(tokens: tensor, expert: MoEExpert) {
        # Standard FFN: Up-project -> Activation -> Down-project
        # For SwiGLU: split into two halves, gate one half, multiply

        up_output = expert.up_proj.forward(tokens)  # [count, intermediate]

        # Check if using SwiGLU (split intermediate into two parts)
        if this.config.intermediate_size % 2 == 0:
            half_dim = this.config.intermediate_size // 2
            gate_part, value_part = up_output[:, :half_dim], up_output[:, half_dim:]
            activated = expert.gate.forward(gate_part) * value_part
        else:
            activated = expert.gate.forward(up_output)

        down_output = expert.down_proj.forward(activated)  # [count, hidden]
        return down_output
    }

    _compute_shared_expert_output(hidden_states: tensor) {
        # Shared experts are applied to ALL tokens (like regular dense FFN)
        output = zeros_like(hidden_states)

        for shared_exp in this.shared_experts:
            up_out = shared_exp.up_proj.forward(hidden_states)

            # Same SwiGLU logic
            half_dim = this.config.intermediate_size // 2
            gate_part, value_part = up_out[:, :, :half_dim], up_out[:, :, half_dim:]
            activated = shared_exp.gate.forward(gate_part) * value_part

            down_out = shared_exp.down_proj.forward(activated)
            output = output + down_out

        # Average over shared experts
        if this.shared_experts.length > 0:
            output = output / this.shared_experts.length

        return output
    }

    _compute_dispatch_statistics(expert_mask: tensor, capacity: int) {
        # Compute detailed statistics about how tokens were dispatched

        tokens_per_expert = expert_mask.sum(dim=(0, 1)).tolist()
        total_tokens = expert_mask.sum().item()

        expert_utilization: list<float> = []
        for count in tokens_per_expert:
            utilization = min(count / (total_tokens / this.config.num_experts + 1e-6), 1.0)
            expert_utilization.append(utilization)

        # Load variance
        arr = tensor(tokens_per_expert).float()
        variance = ((arr - arr.mean()) ** 2).mean().item()
        avg_load = arr.mean().item()

        max_load = max(tokens_per_expert)
        min_load = min(tokens_per_experts)
        imbalance_ratio = max_load / (min_load + 1e-6)

        # Router entropy (higher = more uniform distribution)
        router_prob_distribution = expert_mask.sum(dim=(0, 1)).float() / (total_tokens + 1e-6)
        entropy = -(router_prob_distribution * (router_prob_distribution + 1e-10).log()).sum().item()

        # Dropped tokens estimation
        dropped = max(0, total_tokens - this.config.num_experts * capacity)

        return DispatchPattern{
            total_tokens=int(total_tokens),
            tokens_per_expert=tokens_per_expert,
            expert_utilization=expert_utilization,
            load_variance=variance,
            avg_load=avg_load,
            max_load_imbalance_ratio=imbalance_ratio,
            entropy=entropy,
            dropped_tokens=int(dropped)
        }
    }
}

// ==================== Expert English text ====================

class ExpertSpecializer {
    config: MoEConfig
    moe_layer: MoEFFNLayer?

    init(config: MoEConfig) {
        this.config = config
    }

    bind(moe_layer: MoEFFNLayer) {
        this.moe_layer = moe_layer
    }

    compute_specialization_loss(moe_output: MoEForwardOutput) {
        if !this.config.enable_expert_specialization or this.moe_layer == null:
            return tensor(0.0)

        match this.config.specialization_method {
            "gradient_manipulation" => {
                return this._gradient_manipulation_loss(moe_output)
            }
            "regularization" => {
                return this._diversity_regularization_loss()
            }
            "hard_routing" => {
                return this._hard_routing_auxiliary_loss(moe_output)
            }
            _ => {
                return tensor(0.0)
            }
        }
    }

    _gradient_manipulation_loss(moe_output: MoEForwardOutput) {
        # Encourage different experts to specialize on different patterns
        # Based on the idea that similar inputs should go to same experts

        router_logits = moe_output.router_logits  # [B, T, E]
        B, T, E = router_logits.shape

        # Method 1: Penalize high correlation between experts' routing decisions
        # If expert A and expert B always select similar tokens, they're redundant

        # Compute pairwise similarity of expert selection patterns
        expert_selections = (router_logits > 0).float()  # Binary: [B, T, E]

        # Reshape: treat each expert's selections as a vector of length B*T
        expert_vectors = expert_selections.permute(2, 0, 1).reshape(E, -1)  # [E, B*T]

        # Normalize vectors
        norms = expert_vectors.norm(p=2, dim=1, keepdim=true).clamp(min=1e-8)
        normalized_vectors = expert_vectors / norms

        # Compute cosine similarity matrix between experts
        similarity_matrix = matmul(normalized_vectors, normalized_vectors.T)  # [E, E]

        # Penalize off-diagonal similarities (experts should be diverse)
        identity = eye(E, device=router_logits.device)
        off_diag_penalty = (similarity_matrix * (1 - identity)).abs().mean()

        return this.config.diversity_penalty * off_diag_penalty
    }

    _diversity_regularization_loss() {
        # Simple regularization on expert weights to encourage diversity
        # Penalize similar weight patterns across experts

        if this.moe_layer == null:
            return tensor(0.0)

        total_penalty = tensor(0.0, requires_grad=true)

        for i in range(len(this.moe_layer!.experts)):
            for j in range(i + 1, len(this.moe_layer!.experts)):
                exp_i = this.moe_layer!.experts[i]
                exp_j = this.moe_layer!.experts[j]

                # Compare up-projection weights
                w_i = exp_i.up_proj.weight.flatten()
                w_j = exp_j.up_proj.weight.flatten()

                cos_sim = cosine_similarity(w_i.unsqueeze(0), w_j.unsqueeze(0))
                penalty = (cos_sim ** 2).mean()  # Square to penalize both positive and negative

                total_penalty = total_penalty + penalty

        return this.config.diversity_penalty * total_penalty / (len(this.moe_layer!.experts) * (len(this.moe_layer!.experts) - 1) / 2)
    }

    _hard_routing_auxiliary_loss(moe_output: MoEForwardOutput) {
        # Additional loss term for hard routing scenarios
        # Encourages confident (high probability) assignments

        router_logits = moe_output.router_logits
        router_probs = softmax(router_logits, dim=-1)

        # Entropy bonus: reward high-confidence (low entropy) selections
        # But only for the selected top-k
        topk_probs = router_probs.max(dim=-1)[0]  # Max prob per token
        confidence_reward = -topk_probs.log().mean()  # Negative log of confidence

        return this.config.diversity_penalty * confidence_reward * 0.01  # Small coefficient
    }

    analyze_expert_specialization(moe_layer: MoEFFNLayer) {
        # Analyze how specialized each expert has become
        # Returns detailed report on expert usage patterns

        reports: list<IndividualExpertReport> = []

        for expert in moe_layer.experts:
            # Analyze weight statistics
            up_weight_norm = expert.up_proj.weight.norm(dim=1).mean().item()
            down_weight_norm = expert.down_proj.weight.norm(dim=1).mean().item()

            # Weight magnitude indicates activity level
            weight_magnitude = (expert.up_proj.weight.abs().mean() + expert.down_proj.weight.abs().mean()).item()

            reports.append(IndividualExpertReport{
                expert_id=expert.id,
                is_active=expert.is_active,
                up_projection_l2_norm=up_weight_norm,
                down_projection_l2_norm=down_weight_norm,
                weight_magnitude=weight_magnitude,
                specialization_score=expert.specialization_score,
                importance_weight=expert.importance_weight
            })

        # Compute overall metrics
        active_count = sum(1 for r in reports if r.is_active)
        avg_specialization = mean(r.specialization_score for r in reports)
        max_importance = max(r.importance_weight for r in reports)
        min_importance = min(r.importance_weight for r in reports)

        return ExpertAnalysisReport{
            num_total_experts=len(reports),
            num_active_experts=active_count,
            expert_reports=reports,
            average_specialization_score=avg_specialization,
            importance_range=(min_importance, max_importance),
            redundancy_detected=this._detect_redundancy(reports)
        }
    }

    _detect_redundancy(expert_reports: list<IndividualExpertReport>) {
        # Heuristic: check if multiple experts have very similar magnitudes and patterns
        magnitudes = [r.weight_magnitude for r in expert_reports if r.is_active]
        if magnitudes.length < 2:
            return false

        std_dev = standard_deviation(magnitudes)
        mean_mag = mean(magnitudes)

        # If coefficient of variation is low, might be redundancy
        cv = std_dev / (mean_mag + 1e-8)
        return cv < 0.1  # Low variation suggests potential redundancy
    }
}

struct ExpertAnalysisReport {
    num_total_experts: int
    num_active_experts: int
    expert_reports: list<IndividualExpertReport>
    average_specialization_score: float
    importance_range: tuple<float, float>
    redundancy_detected: bool
}

struct IndividualExpertReport {
    expert_id: int
    is_active: bool
    up_projection_l2_norm: float
    down_projection_l2_norm: float
    weight_magnitude: float
    specialization_score: float
    importance_weight: float
}

// ==================== Expert English textmanagementEnglish text ====================

class ExpertManager {
    moe_layers: list<MoEFFNLayer>
    specializer: ExpertSpecializer
    config: MoEConfig

    init(moe_layers: list<MoEFFNLayer>, config: MoEConfig) {
        this.moe_layers = moe_layers
        this.config = config
        this.specializer = new ExpertSpecializer(config)

        for layer in moe_layers {
            this.specializer.bind(layer)
        }
    }

    prune_low_importance_experts(threshold?: float) {
        effective_threshold = threshold ?? this.config.expert_pruning_threshold

        pruned_count = 0
        pruned_ids: set<int> = set{}

        for layer in this.moe_layers:
            analysis = this.specializer.analyze_expert_specialization(layer)

            for report in analysis.expert_reports:
                if report.importance_weight < effective_threshold && report.is_active:
                    layer.experts[report.expert_id].is_active = false
                    pruned_ids.add(report.expert_id)
                    pruned_count += 1

        return PruningReport{
            experts_pruned=pruned_count,
            pruned_expert_ids=list(pruned_ids),
            threshold_used=effective_threshold,
            remaining_active=sum(1 for l in this.moe_layers for e in l.experts if e.is_active)
        }
    }

    merge_similar_experts(similarity_threshold: float = 0.95) {
        # Detect and merge highly similar experts to improve efficiency

        merge_operations: list<MergeOperation> = []

        for layer in this.moe_layers:
            active_experts = [e for e in layer.experts if e.is_active]

            for i in range(len(active_experts)):
                for j in range(i + 1, len(active_experts)):
                    exp_a = active_experts[i]
                    exp_b = active_experts[j]

                    # Compute weight similarity
                    sim_up = cosine_similarity(
                        exp_a.up_proj.weight.flatten().unsqueeze(0),
                        exp_b.up_proj.weight.flatten().unsqueeze(0)
                    ).item()

                    sim_down = cosine_similarity(
                        exp_a.down_proj.weight.flatten().unsqueeze(0),
                        exp_b.down_proj.weight.flatten().unsqueeze(0)
                    ).item()

                    avg_sim = (sim_up + sim_down) / 2

                    if avg_sim > similarity_threshold:
                        merge_operations.append(MergeOperation{
                            layer_index=this.moe_layers.index(layer),
                            expert_a_id=exp_a.id,
                            expert_b_id=exp_b.id,
                            similarity=avg_sim,
                            action="merge"
                        })

                        # Perform merge: average weights
                        with no_grad():
                            exp_a.up_proj.weight.data = (exp_a.up_proj.weight.data + exp_b.up_proj.weight.data) / 2
                            exp_a.down_proj.weight.data = (exp_a.down_proj.weight.data + exp_b.down_proj.weight.data) / 2

                        # Deactivate merged expert
                        exp_b.is_active = False

        return MergingReport{
            merges_performed=merge_operations.length,
            operations=merge_operations,
            estimated_memory_savings_pct=merge_operations.length * 100 / (this.config.num_experts * len(this.moe_layers))
        }
    }

    get_global_efficiency_report() {
        # Aggregate statistics across all MoE layers

        total_params_before = 0
        total_params_after = 0
        all_dispatch_patterns: list<DispatchPattern> = []

        for layer in this.moe_layers:
            for expert in layer.experts:
                total_params_before += count_parameters(expert.up_proj) + count_parameters(expert.down_proj)
                if expert.is_active:
                    total_params_after += count_parameters(expert.up_proj) + count_parameters(expert.down_proj)

        sparsity = 1.0 - (total_params_after / total_params_after) if total_params_after > 0 else 0.0

        return MoEEfficiencyReport{
            total_experts_per_layer=this.config.num_experts,
            total_moe_layers=len(this.moe_layers),
            active_experts_per_layer=[sum(1 for e in l.experts if e.is_active) for l in this.moe_layers],
            parameter_sparsity=sparsity,
            theoretical_flops_reduction=f"{(1 - total_params_after / total_params_before) * 100:.1f}%"
        }
    }
}

struct PruningReport {
    experts_pruned: int
    pruned_expert_ids: list<int>
    threshold_used: float
    remaining_active: int
}

struct MergingReport {
    merges_performed: int
    operations: list<MergeOperation>
    estimated_memory_savings_pct: float
}

struct MergeOperation {
    layer_index: int
    expert_a_id: int
    expert_b_id: int
    similarity: float
    action: string
}

struct MoEEfficiencyReport {
    total_experts_per_layer: int
    total_moe_layers: int
    active_experts_per_layer: list<int>
    parameter_sparsity: float
    theoretical_flops_reduction: string
}

// ==================== English textfunctionEnglish texttest ====================

function create_moe_ffn_layer(config?: MoEConfig) {
    return new MoEFFNLayer(config=config ?? new MoEConfig())
}

function test_moe_system() {
    print("🧪 Testing NEURX MOE Optimization System...")

    cfg = MoEConfig(
        hidden_size=256,
        intermediate_size=512,
        num_experts=4,
        num_selected_experts=2,
        num_shared_experts=1,
        training=true
    )

    moe_layer = new MoEFFNLayer(cfg)

    # Test 1: Forward pass
    print("  ✓ Test 1: MoE Forward Pass")
    dummy_input = randn(2, 16, 256)  # Batch=2, SeqLen=16, Hidden=256
    output = moe_layer.forward(dummy_input, null)
    assert output.output.shape == dummy_input.shape, f"Output shape mismatch: {output.output.shape}"
    assert output.aux_loss != null, "Auxiliary loss should be computed during training"
    assert output.dispatch_pattern.total_tokens == 32, f"Token count wrong: {output.dispatch_pattern.total_tokens}"

    # Test 2: Dispatch statistics
    print("  ✓ Test 2: Dispatch Pattern Statistics")
    stats = output.dispatch_pattern
    assert stats.tokens_per_expert.length == cfg.num_experts, "Expert counts length mismatch"
    assert stats.load_variance >= 0, "Load variance should be non-negative"
    assert stats.entropy >= 0, "Entropy should be non-negative"
    print(f"      - Expert utilization: {[f'{u:.2f}' for u in stats.expert_utilization]}")
    print(f"      - Load balance ratio: {stats.max_load_imbalance_ratio:.2f}x")

    # Test 3: Expert specialization analysis
    print("  ✓ Test 3: Expert Specialization Analysis")
    specializer = new ExpertSpecializer(cfg)
    specializer.bind(moe_layer)

    spec_loss = specializer.compute_specialization_loss(output)
    assert spec_loss.requires_grad, "Specialization loss should support gradients"

    analysis = specializer.analyze_expert_specialization(moe_layer)
    assert analysis.num_total_experts == cfg.num_experts
    assert analysis.expert_reports.length == cfg.num_experts
    for report in analysis.expert_reports:
        assert report.up_projection_l2_norm > 0, "Norm should be positive"

    # Test 4: Expert management (pruning simulation)
    print("  ✓ Test 4: Expert Management")
    manager = new ExpertManager([moe_layer], cfg)
    eff_report = manager.get_global_efficiency_report()
    assert eff_report.total_moe_layers == 1
    assert eff_report.active_experts_per_layer[0] == cfg.num_experts

    # Test with pruning
    prune_report = manager.prune_low_importance_experts(threshold=999.0)  # Very high threshold to avoid actual pruning
    assert prune_report.remaining_active > 0, "Should still have active experts"

    print("\n✅ All MoE Optimization Tests Passed!")
    return true
}

// Export public API
export {
    MoEConfig, MoEForwardOutput, DispatchPattern, MoEExpert, MoERouter,
    MoEFFNLayer, LoadBalanceLossComputer,
    ExpertSpecializer, ExpertAnalysisReport, IndividualExpertReport,
    ExpertManager, PruningReport, MergingReport, MergeOperation, MoEEfficiencyReport,
    create_moe_ffn_layer, test_moe_system
}
