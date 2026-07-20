// ============================================================
// NEURX Alignment Training System
//
// implementationEnglish textmodelalignmentEnglish text:
//   1. SFT (Supervised Fine-Tuning): English text
//   2. DPO (Direct Preference Optimization): English textpreferenceoptimize
//   3. GRPO (Group Relative Policy Optimization): English textoptimize
//   4. PPO (Proximal Policy Optimization): English textoptimize (RLHF)
//
// English text: English text NEURX-5.2 English textoutputalignmentEnglish textpreference, English text, safetyhelpful
// ============================================================

package neurx.posttrain.alignment

import neurx.model.llm.neurx.*
import neurx.tokenizer.neurx.*
import neurx.amp.scaler.*

// ============================================================
// alignmentconfiguration
// ============================================================

struct alignment_config {
    string method              // "sft" | "dpo" | "grpo" | "ppo"
    string model_name          // English textmodelName

    // === English textparameter ===
    int batch_size
    int gradient_accum_steps
    float learning_rate
    float weight_decay
    int max_grad_norm

    // === data ===
    string train_data_path
    string eval_data_path
    int num_train_epochs
    int eval_interval
    int save_interval

    // === English text ===
    int max_seq_len

    // === English text & optimize ===
    string precision           // "bf16" | "fp16" | "fp32"
    bool use_gradient_checkpointing

    // === DPO English textparameter ===
    float dpo_beta             // DPO loss English text (English text 0.1~0.5)
    string dpo_loss_type       // "sigmoid" | "hinge" | "ipo"

    // === GRPO English textparameter ===
    int grpo_group_size        # English text
    float grpo_clip_epsilon    # English text

    // === PPO English textparameter ===
    float ppo_clip_range      # PPO English text (English text 0.2)
    float ppo_kl_coef         # KL English text
    float ppo_entropy_coef    # English text
    int ppo_epochs            # PPO English text epochs
    string reward_model_path  # Reward Model weightpath

    // === output ===
    string output_dir
}

// default DPO configuration
func create_dpo_config() alignment_config {
    return alignment_config {
        method: "dpo",
        model_name: "neurx_200b",

        batch_size: 8,
        gradient_accum_steps: 4,
        learning_rate: 5e-7,
        weight_decay: 0.01,
        max_grad_norm: 1.0,

        train_data_path: "./data/alignment/dpo/",
        eval_data_path: "./data/alignment/eval/",
        num_train_epochs: 3,
        eval_interval: 500,
        save_interval: 1000,

        max_seq_len: 4096,

        precision: "bf16",
        use_gradient_checkpointing: true,

        # DPO specific
        dpo_beta: 0.1,
        dpo_loss_type: "sigmoid",

        # Not used for DPO
        grpo_group_size: 0,
        grpo_clip_epsilon: 0.0,
        ppo_clip_range: 0.0,
        ppo_kl_coef: 0.0,
        ppo_entropy_coef: 0.0,
        ppo_epochs: 0,
        reward_model_path: "",

        output_dir: "./checkpoints/dpo/"
    }
}

// default GRPO configuration (NeurX-R1 English text)
func create_grpo_config() alignment_config {
    return alignment_config {
        method: "grpo",
        model_name: "neurx_200b",

        batch_size: 4,
        gradient_accum_steps: 8,
        learning_rate: 1e-6,
        weight_decay: 0.01,
        max_grad_norm: 1.0,

        train_data_path: "./data/alignment/grpo/",
        eval_data_path: "./data/alignment/eval/",
        num_train_epochs: 1,
        eval_interval: 200,
        save_interval: 500,

        max_seq_len: 16384,  # GRPO English textRequiredEnglish text

        precision: "bf16",
        use_gradient_checkpointing: true,

        # GRPO specific
        grpo_group_size: 8,
        grpo_clip_epsilon: 0.2,

        # Not used for GRPO
        dpo_beta: 0.0,
        dpo_loss_type: "",
        ppo_clip_range: 0.0,
        ppo_kl_coef: 0.0,
        ppo_entropy_coef: 0.0,
        ppo_epochs: 0,
        reward_model_path: "",  # GRPO use group-based rewards

        output_dir: "./checkpoints/grpo/"
    }
}

// default PPO configuration
func create_ppo_config() alignment_config {
    return alignment_config {
        method: "ppo",
        model_name: "neurx_200b",

        batch_size: 4,
        gradient_accum_steps: 4,
        learning_rate: 1e-6,
        weight_decay: 0.0,  # PPO English text weight decay on policy
        max_grad_norm: 1.0,

        train_data_path: "./data/alignment/rlhf/",
        eval_data_path: "./data/alignment/eval/",
        num_train_epochs: 10,  # PPO trainingEnglish text epochs
        eval_interval: 50,
        save_interval: 250,

        max_seq_len: 4096,

        precision: "bf16",
        use_gradient_checkpointing: true,

        # PPO specific
        ppo_clip_range: 0.2,
        ppo_kl_coef: 0.02,
        ppo_entropy_coef: 0.01,
        ppo_epochs: 4,
        reward_model_path: "./models/reward_model.pt",

        # Not used for PPO
        dpo_beta: 0.0,
        dpo_loss_type: "",
        grpo_group_size: 0,
        grpo_clip_epsilon: 0.0,

        output_dir: "./checkpoints/ppo/"
    }
}

// default SFT configuration
func create_sft_config() alignment_config {
    return alignment_config {
        method: "sft",
        model_name: "neurx_200b",

        batch_size: 16,
        gradient_accum_steps: 2,
        learning_rate: 2e-5,
        weight_decay: 0.01,
        max_grad_norm: 1.0,

        train_data_path: "./data/sft/instruction/",
        eval_data_path: "./data/sft/eval/",
        num_train_epochs: 3,
        eval_interval: 200,
        save_interval: 500,

        max_seq_len: 4096,

        precision: "bf16",
        use_gradient_checkpointing: true,

        # Not used for SFT
        dpo_beta: 0.0,
        dpo_loss_type: "",
        grpo_group_size: 0,
        grpo_clip_epsilon: 0.0,
        ppo_clip_range: 0.0,
        ppo_kl_coef: 0.0,
        ppo_entropy_coef: 0.0,
        ppo_epochs: 0,
        reward_model_path: "",

        output_dir: "./checkpoints/sft/"
    }
}

// ============================================================
// 1️⃣ SFT: Supervised Fine-Tuning (English text)
// English textalignmentEnglish text,English textdataEnglish text fine-tune
// ============================================================

class SFTTrainer {
    neurx_model model
    tokenizer_state tokenizer
    AdamW optimizer
    GradScaler scaler
    alignment_config config
    struct state {
        int current_step
        int current_epoch
        float running_loss
        float best_eval_score
        datetime start_time
    } state

func init_sft_trainer(
    neurx_model model,
    tokenizer_state tokenizer,
    alignment_config cfg
) -> SFTTrainer {

    print("\n📚 Initializing SFT Trainer...")
    print(f"   Method: {cfg.method.upper()} - Supervised Fine-Tuning")
    print(f"   Learning Rate: {cfg.learning_rate}")
    print(f"   Epochs: {cfg.num_train_epochs}")
    print(f"   Max Seq Len: {cfg.max_seq_len}")

    # Initialize optimizer (only train non-frozen parameters)
    trainable_params = filter(lambda p: p.requires_grad, model.parameters())
    AdamW optimizer = AdamW(
        params=trainable_params,
        lr=cfg.learning_rate,
        weight_decay=cfg.weight_decay
    )

    GradScaler scaler = GradScaler(enabled=(cfg.precision != "fp32"))

    return sft_trainer{
        model: model,
        tokenizer: tokenizer,
        optimizer: optimizer,
        scaler: scaler,
        config: cfg,
        state: state {
            current_step: 0,
            current_epoch: 0,
            running_loss: 0.0,
            best_eval_score: 0.0,
            start_time: now()
        }
    }

func train_sft_epoch(self: SFTTrainer, data_loader dataloader) -> float {
    """
    trainingEnglish text epoch English text SFT

    Data format:
    {"instruction": "...", "input": "...", "output": "..."}

    English text chat format:
    [{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]
    """

    self.model.train()
    total_loss = 0.0
    num_batches = 0

    for batch_idx, batch in enumerate(dataloader):
        # Prepare input/output
        dict[str, any] encoded = prepare_sft_batch(
            self.tokenizer,
            batch["instructions"],
            batch["responses"],
            max_len=self.config.max_seq_len
        )

        tensor input_ids = encoded["input_ids"].to(device="cuda")
        tensor attention_mask = encoded["attention_mask"].to(device="cuda")
        tensor labels = encoded["labels"].to(device="cuda")

        # Forward pass
        dict[str, any] outputs = neurx_forward(
            self.model,
            input_ids=input_ids,
            attention_mask=some(attention_mask),
            sop_eop_info=none  # SFT usually uses causal LM
        )

        tensor logits = outputs["logits"]

        # Compute loss (standard cross-entropy)
        tensor loss = cross_entropy_loss(
            logits.view(-1, logits.shape[-1]),
            labels.view(-1),
            ignore_index=-100
        )

        # Backward
        if self.config.precision == "bf16":
            self.scaler.scale(loss).backward()
        else:
            loss.backward()

        # Gradient accumulation & update
        if (batch_idx + 1) % self.config.gradient_accum_steps == 0:
            clip_grad_norm_(self.model.parameters(), self.config.max_grad_norm)

            if self.config.precision == "bf16":
                self.scaler.step(self.optimizer)
                self.scaler.update()
            else:
                self.optimizer.step()

            self.optimizer.zero_grad(set_to_none=True)
            self.state.current_step += 1

        # Logging
        total_loss += loss.item()
        num_batches += 1
        self.state.running_loss = (
            self.state.running_loss * 0.9 + loss.item() * 0.1
        )

        if self.state.current_step % 50 == 0:
            log_sft_progress(self.state, loss.item())

    return total_loss / max(num_batches, 1)

func prepare_sft_batch(
    tokenizer_state tokenizer,
    string[] instructions,
    string[] responses,
    int max_len: int
) -> dict[str, any] {
    """
    English text SFT batchdata

    English text:
    Instruction

    Response
    """

    string[] full_texts = []
    for i in range(len(instructions)):
        text = (
            "" + instructions[i] + "\n\n" +
            "" + responses[i] + ""
        )
        append(full_texts, text)

    # Tokenize
    dict[str, any] encoded = batch_encode(
        tokenizer,
        full_texts,
        add_special_tokens=true,
        max_length=some(max_len),
        truncation=true,
        padding=true,
        return_tensors=true
    )

    tensor input_ids = encoded["input_ids"]
    tensor attention_mask = encoded["attention_mask"]

    # Labels: shift by 1 (predict next token)
    tensor labels = input_ids.clone()
    labels[:, :-1] = input_ids[:, 1:]
    labels[:, -1] = -100  # No prediction needed for last position

    # Mask out instruction tokens (only compute loss on response)
    # Find EOS token positions to identify response start
    for i in range(shape(input_ids)[0]):
        # Simple heuristic: find first  after instruction
        # In practice, this should use special token markers
        pass  # Implementation depends on exact format

    return {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "labels": labels
    }

// ============================================================
// 2️⃣ DPO: Direct Preference Optimization (English textpreferenceoptimize)
// English text Reward Model, English textpreferencedataEnglish text
// English text: https://arxiv.org/abs/2305.18290
// ============================================================

class dpotrainer {
    neurx_model model
    tokenizer_state tokenizer
    alignment_config config
    struct state {
        int current_step
        float avg_reward_margin
        float best_win_rate
    } state

func compute_dpo_loss(
    self: dpotrainer,
    chosen_logits: tensor,     // [batch, seq, vocab]
    rejected_logits: tensor,   // [batch, seq, vocab]
    chosen_labels: tensor,     // [batch, seq]
    rejected_labels: tensor,   // [batch, seq]
    chosen_attention_mask: tensor,  // [batch, seq]
    rejected_attention_mask: tensor, // [batch, seq]
    beta: float,
    loss_type: string = "sigmoid"
) -> tuple[tensor, dict[str, float]] {
    """
    compute DPO Loss

    English text:
    L_DPO = -E[log σ(β(log π_θ(y_w|x) - log π_θ(y_l|x) - log π_ref(y_w|x) + log π_ref(y_l|x)))]

    English text:
    - y_w: chosen (preferred) response
    - y_l: rejected response
    - β: English text reference model English text
    - π_θ: English textmodel
    - π_ref: English textmodel (English text pre-trained / SFT model)
    """

    # Compute log probabilities for chosen and rejected under both models
    tuple[chosen_log_prob, _] = compute_log_probs(chosen_logits, chosen_labels, chosen_attention_mask)
    tuple[rejected_log_prob, _] = compute_log_probs(rejected_logits, rejected_labels, rejected_attention_mask)

    # Reference model log probs (from frozen copy or cached values)
    tuple[ref_chosen_log_prob, _] = get_reference_log_probs(self, chosen_labels, chosen_attention_mask, is_chosen=True)
    tuple[ref_rejected_log_prob, _] = get_reference_log_probs(self, rejected_labels, rejected_attention_mask, is_chosen=False)

    # Compute DPO objective
    # Δlog π = (log π_θ(y_w) - log π_ref(y_w)) - (log π_θ(y_l) - log π_ref(y_l))
    tensor delta_chosen = chosen_log_prob - ref_chosen_log_prob
    tensor delta_rejected = rejected_log_prob - ref_rejected_log_prob
    tensor delta_pi = delta_chosen - delta_rejected

    # Loss based on type
    tensor loss
    match loss_type:
        case "sigmoid":
            # Standard DPO loss: -log σ(β * Δπ)
            loss = -log(sigmoid(beta * delta_pi))

        case "hinge":
            # Hinge loss: max(0, 1 - β*Δπ)
            loss = relu(1.0 - beta * delta_pi).mean()

        case "ipo":
            # IPO (Identity Preference Optimization): (1 - β*Δπ + 1/(2β))^2
            # More numerically stable, avoids degenerate solutions
            tensor diff = beta * delta_pi - (1.0 / (2.0 * beta))
            loss = (diff ** 2).mean()

        case _:
            raise ValueError(f"Unknown DPO loss type: {loss_type}")

    # Compute metrics
    dict[str, float] metrics = {}
    metrics["chosen_reward"] = chosen_log_prob.mean().item()
    metrics["rejected_reward"] = rejected_log_prob.mean().item()
    metrics["reward_margin"] = (chosen_log_prob - rejected_log_prob).mean().item()
    metrics["avg_dpo_loss"] = loss.item()

    # Approximate win rate (how often chosen > rejected)
    metrics["approx_win_rate"] = float((delta_pi > 0).float().mean().item())

    return (loss, metrics)

def compute_log_probs(
    tensor logits,           // [B, S, V]
    tensor labels,           // [B, S]
    tensor attention_mask    // [B, S]
) -> tuple[tensor, int] {
    """computeEnglish text token English text log probability"""

    # Shift for next-token prediction
    logits = logits[:, :-1, :].contiguous()
    labels = labels[:, 1:].contiguous()
    mask = attention_mask[:, 1:].contiguous()

    # Log softmax
    tensor log_probs = log_softmax(logits, dim=-1)  # [B, S-1, V]

    # Gather log prob of actual tokens
    token_log_probs = gather(log_probs, dim=-1, index=labels.unsqueeze(-1)).squeeze(-1)  // [B, S-1]

    # Mask and average
    masked_log_probs = (token_log_probs * mask).sum(dim=-1) / (mask.sum(dim=-1) + 1e-9)  // [B]

    int total_tokens = int(mask.sum().item())

    return (masked_log_probs, total_tokens)

# ============================================================
// 3️⃣ GRPO: Group Relative Policy Optimization
// R1-style useEnglish text, English textRequired Reward Model
// English textrankingEnglish textoptimize
// English text: https://arxiv.org/abs/...
// ============================================================

class GRPOTrainer {
    neurx_model model
    tokenizer_state tokenizer
    alignment_config config
    struct state {
        int current_step
        float avg_group_reward
        float diversity_score
    } state

func train_grpo_step(
    self: GRPOTrainer,
    batch_prompts: string[],      # [batch_size] prompts
    data_loader prompt_loader,
    int group_size: int = 8
) -> tuple[tensor, dict[str, float]] {
    """
    English textstep GRPO training

    pipeline:
    1. English text prompt,generate group_size English textresponse
    2. English textresponseEnglish text (English textmodelEnglish text AI Judge)
    3. English textcomputeEnglish textfunction (advantage)
    4. use advantage English text policy gradient English text
    """

    int batch_size = len(batch_prompts)
    int total_samples = batch_size * group_size

    print(f"\n🔄 GRPO Step: {self.state.current_step}")
    print(f"   Prompts: {batch_size}, Groups per prompt: {group_size}")
    print(f"   Total samples this step: {total_samples}")

    # ===== Step 1: Generate responses for each prompt =====
    timer.start("generation")
    tensor all_responses[][]  # [batch_size][group_size] responses
    tensor all_log_probs[]    # Corresponding log probabilities

    for i, prompt in enumerate(batch_prompts):
        tensor[] group_responses
        tensor[] group_log_probs

        for g in range(group_size):
            # sample with temperature (for diversity)
            tuple[response, log_prob] = generate_with_logprob(
                self.model,
                self.tokenizer,
                prompt=prompt,
                max_new_tokens=self.config.max_seq_len,
                temperature=0.7 + rand() * 0.6,  # Random temperature for diversity
                top_p=0.9
            )
            append(group_responses, response)
            append(group_log_probs, log_prob)

        append(all_responses, group_responses)
        append(all_log_probs, group_log_probs)

    timer.stop("generation")
    print(f"   ⏱ Generation time: {timer.get_elapsed('generation'):.1f}s")

    # ===== Step 2: Score responses =====
    timer.start("scoring")
    tensor scores(batch_size, group_size)

    for i in range(batch_size):
        for g in range(group_size):
            # Scoring options:
            # Option A: Rule-based scoring (format, length, keyword matching)
            # Option B: AI Judge model scoring
            # Option C: Self-scoring using the same model (reflection)

            score = score_response_grpo(
                prompt=batch_prompts[i],
                response=all_responses[i][g],
                scoring_method="rule_based"  # or "ai_judge"
            )
            scores[i, g] = score

    timer.stop("scoring")
    print(f"   📊 Scoring time: {timer.get_elapsed('scoring'):.1f}s")
    print(f"   Score stats: min={scores.min():.2f}, max={scores.max():.2f}, mean={scores.mean():.2f}")

    # ===== Step 3: Compute within-group advantages =====
    # Advantage = score - mean(group_scores)
    tensor group_means = scores.mean(dim=-1, keepdim=True)  # [B, 1]
    tensor advantages = scores - group_means  # Centered: sum to zero within group

    # Normalize advantages (optional but recommended)
    tensor std_advantages = advantages.std(dim=-1, keepdim=True)
    advantages = advantages / (std_advantages + 1e-9)

    # ===== Step 4: Clip advantages (GRPO-specific) =====
    advantages = clamp(advantages, min=-self.config.grpo_clip_epsilon, max=self.config.grpo_clip_epsilon)

    # ===== Step 5: Compute GRPO Loss =====
    timer.start("loss_computation")
    tensor total_loss = 0.0

    for i in range(batch_size):
        for g in range(group_size):
            # Get log prob of the generated response
            tensor old_log_prob = all_log_probs[i][g]

            # Re-compute log prob under current model
            tensor new_log_prob = recompute_log_prob(
                self.model,
                self.tokenizer,
                prompt=batch_prompts[i],
                response=all_responses[i][g]
            )

            # Policy ratio
            tensor ratio = exp(new_log_prob - old_log_prob)

            # Surrogate loss with clipping (similar to PPO but no value function)
            tensor surr1 = ratio * advantages[i, g]
            tensor surr2 = clamp(ratio, 1.0 - 0.2, 1.0 + 0.2) * advantages[i, g]

            # Use the minimum (PPO-style clipping)
            tensor loss_i = -min(surr1, surr2)

            total_loss = total_loss + loss_i

    # Average over all samples
    total_loss = total_loss / total_samples

    timer.stop("loss_computation")

    # ===== Step 6: Backward & Update =====
    if self.config.precision == "bf16":
        GradScaler.scale(total_loss).backward()
    else:
        total_loss.backward()

    clip_grad_norm_(self.model.parameters(), self.config.max_grad_norm)
    self.optimizer.step()
    self.optimizer.zero_grad(set_to_none=True)

    # ===== Metrics =====
    dict[str, float] metrics = {}
    metrics["grpo_loss"] = total_loss.item()
    metrics["mean_score"] = scores.mean().item()
    metrics["max_score"] = scores.max().item()
    metrics["min_score"] = scores.min().item()
    metrics["score_std"] = scores.std().item()

    # Diversity metric: unique n-gram ratio across group
    metrics["diversity"] = compute_group_diversity(all_responses, n=3)

    self.state.current_step += 1
    self.state.avg_group_reward = metrics["mean_score"]
    self.state.diversity_score = metrics["diversity"]

    return (total_loss, metrics)

def score_response_grpo(
    string prompt,
    string response,
    string scoring_method = "rule_based"
) -> float {
    """
    English textgenerateEnglish textresponseEnglish text (English text Reward Model!)

    English text:
    1. English text (English text, English text, keywordsEnglish text)
    2. AI Judge (useEnglish textmodelEnglish text)
    """

    match scoring_method:
        case "rule_based":
            float score = 0.0

            # Length bonus (prefer reasonable length)
            int resp_len = len(response)
            if 20 <= resp_len <= 2000:
                score += 0.2  # Good length
            elif 200 < resp_len <= 800:
                score += 0.3   # Optimal length

            # Format check (markdown, code blocks, etc.)
            if contains_code_block(response):
                score += 0.1
            if has_proper_formatting(response):
                score += 0.1

            # Keyword matching (if prompt asks for specific content)
            # ... depends on task

            # Non-repetition bonus
            float repetition_ratio = compute_repetition_ratio(response)
            score += (1.0 - repetition_ratio) * 0.2

            # Normalize to [0, 1]
            score = clamp(score, 0.0, 1.0)

            return score

        case "ai_judge":
            # Use a separate judge model (could be smaller/faster)
            score = call_ai_judge(prompt, response)
            return score

        case _:
            raise ValueError(f"Unknown scoring method: {scoring_method}")

// ============================================================
// 4️⃣ PPO: Proximal Policy Optimization (English textoptimize)
// English text RLHF English text,Required Reward Model English text Value Model
// English text: https://arxiv.org/abs/1707.06347
// ============================================================

class ppotrainer {
    neurx_model policy_model       # Actor (English textoptimizeEnglish text)
    neurx_model reference_model   # Frozen reference (English text KL penalty)
    reward_model reward_model     # Reward model
    value_model value_model       # Critic (value function)
    tokenizer_state tokenizer
    AdamW actor_optimizer
    AdamW critic_optimizer
    GradScaler scaler
    alignment_config config
    struct state {
        int current_iteration
        float kl_penalty
        float entropy_bonus
        float mean_reward
    } state

func train_ppo_iteration(
    self: ppotrainer,
    batch_prompts: string[]
) -> dict[str, float] {
    """
    PPO English textpipeline:

    1. English text policy model generateresponse (rollout)
    2. English text reward model English text
    3. English text critic model English text value
    4. compute advantage (GAE - Generalized Advantage Estimation)
    5. English text epoch English text policy (with clipping)
    6. English text critic
    """

    int batch_size = len(batch_prompts)

    # ===== Rollout Phase =====
    timer.start("rollout")
    tensor rollout_data[]

    for prompt in batch_prompts:
        # Generate from policy model
        dict[str, any] rollout = collect_rollout(
            policy_model=self.policy_model,
            tokenizer=self.tokenizer,
            prompt=prompt,
            max_new_tokens=512,
            temperature=1.0  # PPO typically uses temp=1 for exploration
        )
        append(rollout_data, rollout)

    timer.stop("rollout")

    # ===== Reward & Value Computation =====
    timer.start("reward_value")

    tensor rewards(batch_size)
    tensor values(batch_size)
    tensor old_log_probs(batch_size)

    for i, rollout in enumerate(rollout_data):
        # Reward from reward model
        rewards[i] = self.reward_model.score(
            prompt=batch_prompts[i],
            response=rollout["response_text"]
        )

        # Value from critic
        values[i] = self.value_model.predict(
            full_text=rollout["full_text"]
        )

        # Old log prob from policy
        old_log_probs[i] = rollout["total_log_prob"]

    timer.stop("reward_value")

    # ===== Compute Advantages (GAE) =====
    tensor advantages = compute_gae_advantages(
        rewards=rewards,
        values=values,
        gamma=0.99,      # Discount factor
        lambda_=0.95      # GAE lambda
    )

    # Normalize advantages
    advantages = (advantages - advantages.mean()) / (advantages.std() + 1e-9)

    # ===== PPO Update Epochs =====
    timer.start("update")

    dict[str, float] iteration_metrics = {}
    float total_policy_loss = 0.0
    float total_critic_loss = 0.0
    float total_kl_penalty = 0.0

    for epoch in range(self.config.ppo_epochs):
        for i, rollout in enumerate(rollout_data):
            # Re-evaluate under current policy
            tuple[new_log_prob, entropy] = evaluate_policy(
                self.policy_model,
                rollout,
                self.tokenizer
            )

            # KL divergence from reference
            tensor kl_div = compute_kl_divergence(
                self.policy_model,
                self.reference_model,
                rollout,
                self.tokenizer
            )

            # Policy ratio
            tensor ratio = exp(new_log_prob - old_log_probs[i])

            # Clipped surrogate objective
            tensor surr1 = ratio * advantages[i]
            tensor surr2 = clamp(
                ratio,
                1.0 - self.config.ppo_clip_range,
                1.0 + self.config.ppo_clip_range
            ) * advantages[i]

            # Final policy loss (with KL penalty)
            tensor policy_loss = -min(surr1, surr2).mean()
            tensor kl_loss = kl_div.mean() * self.config.ppo_kl_coef
            tensor entropy_loss = -entropy.mean() * self.config.ppo_entropy_coef

            tensor combined_loss = policy_loss + kl_loss + entropy_loss

            # Backward for policy
            combined_loss.backward()

            # Update critic separately
            tensor value_pred = self.value_model.predict(rollout["full_text"])
            tensor target_value = rewards[i]  # Simplified; could use returns
            tensor critic_loss = mse_loss(value_pred, target_value)
            critic_loss.backward()

            # Gradient steps
            clip_grad_norm_(list(self.policy_model.parameters()) + list(self.value_model.parameters()), self.config.max_grad_norm)

            self.actor_optimizer.step()
            self.critic_optimizer.step()

            self.actor_optimizer.zero_grad()
            self.critic_optimizer.zero_grad()

            # Accumulate metrics
            total_policy_loss += policy_loss.item()
            total_critic_loss += critic_loss.item()
            total_kl_penalty += kl_div.mean().item()

    timer.stop("update")

    int total_updates = batch_size * self.config.ppo_epochs

    iteration_metrics = {
        "policy_loss": total_policy_loss / total_updates,
        "critic_loss": total_critic_loss / total_updates,
        "kl_penalty": total_kl_penalty / total_updates,
        "mean_reward": rewards.mean().item(),
        "std_reward": rewards.std().item(),
        "mean_advantage": advantages.mean().item(),
        "entropy": entropy.mean().item(),
        "rollout_time": timer.get_elapsed("rollout"),
        "reward_value_time": timer.get_elapsed("reward_value"),
        "update_time": timer.get_elapsed("update"),
    }

    self.state.current_iteration += 1
    self.state.kl_penalty = iteration_metrics["kl_penalty"]
    self.state.entropy_bonus = iteration_metrics["entropy"]
    self.state.mean_reward = iteration_metrics["mean_reward"]

    return iteration_metrics

// ============================================================
// English textlogoutput
// ============================================================

func log_sft_progress(state: SFTTrainer.state, float loss) {
    elapsed = now() - state.start_time
    print(
        f"[SFT Step {state.current_step:>6}] "
        f"Loss: {loss:>7.4f} | "
        f"Avg Loss: {state.running_loss:>7.4f} | "
        f"Elapsed: {elapsed}"
    )

func log_alignment_progress(
    string method,
    int step,
    dict[str, float] metrics
) {
    print(
        f"[{method.upper()} Step {step:>6}] "
        f"Loss: {metrics['loss']:>7.4f} | "
        f"Reward: {metrics.get('reward', 0):>7.2f} | "
    )

    match method:
        case "dpo":
            print(
                f"Win Rate: {metrics['win_rate']:.1%} | "
                f"Margin: {metrics['margin']:>+6.2f}"
            )
        case "grpo":
            print(
                f"Diversity: {metrics['diversity']:.3f} | "
                f"Score Std: {metrics['score_std']:.3f}"
            )
        case "ppo":
            print(
                f"KL Penalty: {metrics['kl_penalty']:.4f} | "
                f"Entropy: {metrics['entropy']:.4f}"
            )

// ============================================================
// testfunction
// ============================================================

func test_alignment_systems() {
    print("\n" + "="*70)
    print("Testing NEURX Alignment Training Systems")
    print("="*70)

    // Test 1: Config creation
    print("\n[Test 1] Creating alignment configs...")
    alignment_config dpo_cfg = create_dpo_config()
    alignment_config grpo_cfg = create_grpo_config()
    alignment_config ppo_cfg = create_ppo_config()
    alignment_config sft_cfg = create_sft_config()

    assert(dpo_cfg.method == "dpo")
    assert(grpo_cfg.method == "grpo")
    assert(ppo_cfg.method == "ppo")
    assert(sft_cfg.method == "sft")
    assert(dpo_cfg.dpo_beta == 0.1)
    assert(grpo_cfg.grpo_group_size == 8)
    assert(ppo_cfg.ppo_clip_range == 0.2)
    print("✅ All configs created successfully!")

    # Test 2: DPO loss computation
    print("\n[Test 2] Testing DPO loss computation...")
    # Simulated data
    tensor chosen_logits = randn(2, 64, 32000)  # B=2, S=64, V=32K
    tensor rejected_logits = randn(2, 64, 32000)
    tensor labels = randint(0, 32000, shape=(2, 64))
    tensor mask = ones(2, 64)

    # Make chosen slightly better (higher log prob at label positions)
    # This is just a smoke test
    tuple[dpo_loss, dpo_metrics] = compute_dpo_loss(
        chosen_logits=chosen_logits,
        rejected_logits=rejected_logits,
        chosen_labels=labels,
        rejected_labels=labels,
        chosen_attention_mask=mask,
        rejected_attention_mask=mask,
        beta=0.1,
        loss_type="sigmoid"
    )

    assert(dpo_loss.requires_grad)  # Should be differentiable
    assert(abs(dpo_loss.item()) < 100)  # Reasonable magnitude
    print(f"   DPO Loss: {dpo_loss.item():.4f}")
    print(f"   Win Rate: {dpo_metrics['win_rate']:.1%}")
    print("✅ DPO loss works!")

    # Test 3: GRPO scoring
    print("\n[Test 3] Testing GRPO response scoring...")
    float rule_score = score_response_grpo(
        prompt="What is machine learning?",
        response="Machine learning is a subset of artificial intelligence...",
        scoring_method="rule_based"
    )
    assert(0.0 <= rule_score <= 1.0)
    print(f"   Rule-based score: {rule_score:.3f}")
    print("✅ GRPO scoring works!")

    // Test 4: GAE computation
    print("\n[Test 4] Testing GAE advantage estimation...")
    tensor rewards = tensor([1.0, 0.5, 0.8, -0.2, 1.2])
    tensor values = tensor([0.8, 0.6, 0.7, 0.4, 0.9])
    tensor advantages = compute_gae_advantages(rewards, values, gamma=0.99, lambda_=0.95)
    assert(len(advantages) == len(rewards))
    print(f"   Rewards: {rewards.tolist()}")
    print(f"   Values: {values.tolist()}")
    print(f"   Advantages: {[round(a, 3) for a in advantages.tolist()]}")
    print("✅ GAE computation works!")

    // Test 5: Log probability computation
    print("\n[Test 5] Testing log probability computation...")
    tensor test_logits = randn(2, 32, 100)  # B=2, S=32, V=100
    tensor test_labels = randint(0, 100, shape=(2, 32))
    tensor test_mask = ones(2, 32)

    tuple[log_probs, num_tokens] = compute_log_probs(test_logits, test_labels, test_mask)
    assert(shape(log_probs) == (2,))
    assert(log_probs.max().item() <= 0)  # Log probs should be ≤ 0
    print(f"   Mean log prob: {log_probs.mean().item():.4f}")
    print(f"   Total tokens: {num_tokens}")
    print("✅ Log prob computation works!")

    print("\n" + "="*70)
    print("All alignment system tests passed! ✨")
    print("="*70 + "\n")

// Helper functions

func contains_code_block(string text) -> bool:
    return "```" in text || "`" in text

func has_proper_formatting(string text) -> bool:
    return ("\n" in text) and (len(text.split()) > 3)

func compute_repetition_ratio(string text) -> float:
    # Simple repetition detection
    words = text.split()
    if len(words) < 4:
        return 0.0
    bigrams = [(words[i], words[i+1]) for i in range(len(words)-1)]
    unique_bigrams = set(bigrams)
    return 1.0 - len(unique_bigrams) / max(len(bigrams), 1)

func compute_group_diversity(tensor[][] responses, int n: int) -> float:
    # Compute unique n-gram ratio across group
    set all_ngrams
    for group_responses in responses:
        for response in group_responses:
            words = str(response).split()
            for i in range(len(words)-n+1):
                ngram = tuple(words[i:i+n])
                all_ngrams.add(ngram)

    # Higher = more diverse
    return float(len(all_ngrams)) / max(responses.size * responses[0].size, 1)

func compute_gae_advantages(
    tensor rewards,
    tensor values,
    float gamma = 0.99,
    float lambda_ = 0.95
) -> tensor:
    """
    Generalized Advantage Estimation (GAE)

    A_t = δ_t + (γλ)δ_{t+1} + ... + (γλ)^{T-t+1}δ_{T-1}
    where δ_t = r_t + γV(s_{t+1}) - V(s_t)
    """

    int T = len(rewards)
    tensor advantages(T)
    tensor last_advantage = 0.0

    # Reverse iteration for efficiency
    for t in reversed(range(T)):
        if t == T - 1:
            next_value = 0.0
        else:
            next_value = values[t + 1]

        # TD residual
        tensor delta = rewards[t] + gamma * next_value - values[t]

        # GAE update
        advantages[t] = delta + gamma * lambda_ * last_advantage
        last_advantage = advantages[t]

    return advantages

func compute_kl_divergence(
    neurx_model policy,
    neurx_model reference,
    dict[str, any] rollout,
    tokenizer_state tokenizer
) -> tensor:
    """
    compute KL(policy || reference)

    KL(p||q) = Σ p(x) * log(p(x) / q(x))
    """

    # Get logits from both models
    tensor policy_logits = forward_and_get_logits(policy, rollout)
    tensor ref_logits = forward_and_get_logits(reference, rollout)

    # Convert to log probs
    tensor policy_log_probs = log_softmax(policy_logits, dim=-1)
    tensor ref_log_probs = log_softmax(ref_logits, dim=-1)

    # KL divergence
    tensor kl = (policy_log_probs - ref_log_probs) * exp(policy_log_probs)
    return kl.sum(dim=-1).mean()
