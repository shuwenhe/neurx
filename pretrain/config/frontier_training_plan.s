package neurx.pretrain.config.frontier_training_plan

// Frontier-scale training readiness planner.
//
// This module does not encode any private GPT-5.5 specification. It defines
// the engineering capabilities required for a GPT-5-class training run and
// gives NeurX a structured way to block unsafe launches while key systems are
// still partial or missing.

struct frontier_model_target {
    string name
    string architecture
    int total_params_billion
    int active_params_billion
    int layers
    int hidden_dim
    int attention_heads
    int kv_heads
    int context_len
    int vocab_size
    int moe_experts
    int moe_top_k
    bool multimodal
}

struct frontier_data_plan {
    int target_tokens_billion
    int high_quality_tokens_billion
    int code_tokens_billion
    int math_tokens_billion
    int multilingual_tokens_billion
    bool exact_dedup
    bool near_dedup
    bool pii_filter
    bool toxicity_filter
    bool eval_contamination_filter
}

struct frontier_cluster_plan {
    int gpu_count
    int gpu_memory_gb
    string accelerator
    string interconnect
    int tensor_parallel
    int pipeline_parallel
    int data_parallel
    int expert_parallel
    int zero_stage
    bool elastic_recovery
}

struct frontier_train_recipe {
    int global_batch_tokens
    int sequence_length
    int warmup_steps
    int max_steps
    float peak_lr
    float min_lr
    string optimizer
    string scheduler
    bool bf16
    bool fp8
    bool gradient_checkpointing
    bool flash_attention
    bool fused_optimizer
}

struct frontier_capability {
    string key
    string area
    string status              // "ready", "partial", or "missing"
    string priority            // "p0", "p1", or "p2"
    bool launch_blocker
    string implementation_path
    string required_work
}

struct frontier_audit {
    []frontier_capability capabilities
    int total
    int ready
    int partial
    int missing
    int blockers
    float readiness_score
    bool can_launch_frontier_run
}

func default_gpt55_class_target() frontier_model_target {
    frontier_model_target {
        name: "neurx-gpt-frontier",
        architecture: "decoder-only-moe-gqa-rope",
        total_params_billion: 1000,
        active_params_billion: 100,
        layers: 96,
        hidden_dim: 12288,
        attention_heads: 96,
        kv_heads: 16,
        context_len: 131072,
        vocab_size: 200000,
        moe_experts: 256,
        moe_top_k: 2,
        multimodal: true,
    }
}

func default_frontier_data_plan() frontier_data_plan {
    frontier_data_plan {
        target_tokens_billion: 20000,
        high_quality_tokens_billion: 12000,
        code_tokens_billion: 3000,
        math_tokens_billion: 1000,
        multilingual_tokens_billion: 3000,
        exact_dedup: true,
        near_dedup: true,
        pii_filter: true,
        toxicity_filter: true,
        eval_contamination_filter: true,
    }
}

func default_frontier_cluster_plan() frontier_cluster_plan {
    frontier_cluster_plan {
        gpu_count: 8192,
        gpu_memory_gb: 80,
        accelerator: "h100-or-better",
        interconnect: "nvlink-infiniband",
        tensor_parallel: 8,
        pipeline_parallel: 16,
        data_parallel: 64,
        expert_parallel: 16,
        zero_stage: 3,
        elastic_recovery: true,
    }
}

func default_frontier_train_recipe() frontier_train_recipe {
    frontier_train_recipe {
        global_batch_tokens: 4194304,
        sequence_length: 131072,
        warmup_steps: 2000,
        max_steps: 5000000,
        peak_lr: 0.00012,
        min_lr: 0.000012,
        optimizer: "distributed-adamw",
        scheduler: "warmup-cosine",
        bf16: true,
        fp8: true,
        gradient_checkpointing: true,
        flash_attention: true,
        fused_optimizer: true,
    }
}

func make_capability(
    string key,
    string area,
    string status,
    string priority,
    bool blocker,
    string path,
    string work
) frontier_capability {
    frontier_capability {
        key: key,
        area: area,
        status: status,
        priority: priority,
        launch_blocker: blocker,
        implementation_path: path,
        required_work: work,
    }
}

func current_neurx_frontier_capabilities() []frontier_capability {
    []frontier_capability caps = []frontier_capability{cap: 16}

    caps[0] = make_capability(
        "real_corpus_pipeline",
        "data",
        "partial",
        "p0",
        true,
        "data/corpus_loader.s",
        "wire corpus_loader into pretrain loop and remove synthetic fallback"
    )
    caps[1] = make_capability(
        "frontier_tokenizer",
        "data",
        "partial",
        "p0",
        true,
        "data/tokenizer_pipeline.s",
        "replace placeholder whitespace paths with production BPE/SentencePiece flow"
    )
    caps[2] = make_capability(
        "eval_contamination_filter",
        "data",
        "missing",
        "p0",
        true,
        "data/quality_filter.s",
        "add benchmark contamination detection before pretraining shard emission"
    )
    caps[3] = make_capability(
        "moe_transformer",
        "model",
        "partial",
        "p0",
        true,
        "model/llm/gpt_moe_1t.s",
        "finish top-k routing, expert capacity handling, and load-balance loss"
    )
    caps[4] = make_capability(
        "long_context_attention",
        "model",
        "partial",
        "p0",
        true,
        "model/transformer/rope_scaling.s",
        "validate 128k context with RoPE scaling, KV cache layout, and evals"
    )
    caps[5] = make_capability(
        "mixed_precision_stack",
        "runtime",
        "partial",
        "p0",
        true,
        "distributed/mixed_precision/mixed_precision.s",
        "add FP8 amax history, loss scaling policy, and numerics monitors"
    )
    caps[6] = make_capability(
        "hybrid_parallel_runtime",
        "distributed",
        "partial",
        "p0",
        true,
        "distributed/training_coordinator.s",
        "connect DP+TP+PP+EP+ZeRO process groups into one launch plan"
    )
    caps[7] = make_capability(
        "elastic_fault_recovery",
        "distributed",
        "partial",
        "p0",
        true,
        "distributed/fault_recovery.s",
        "resume failed ranks from sharded checkpoints without restarting run"
    )
    caps[8] = make_capability(
        "sharded_checkpoint_format",
        "checkpoint",
        "partial",
        "p0",
        true,
        "pretrain/checkpoint/pretrain_checkpoint.s",
        "store model, optimizer, RNG, dataloader cursor, and topology metadata"
    )
    caps[9] = make_capability(
        "distributed_optimizer",
        "optimizer",
        "partial",
        "p0",
        true,
        "pretrain/optimizer/pretrain_adamw.s",
        "support ZeRO/FSDP partitioned AdamW with overflow and grad clipping"
    )
    caps[10] = make_capability(
        "frontier_eval_harness",
        "eval",
        "partial",
        "p1",
        false,
        "eval/benchmark_eval.s",
        "add benchmark loaders, held-out perplexity, coding, math, safety, and long-context suites"
    )
    caps[11] = make_capability(
        "alignment_pipeline",
        "alignment",
        "partial",
        "p1",
        false,
        "alignment/rlhf_complete.s",
        "connect SFT, reward modeling, preference optimization, red-team data, and refusal evals"
    )
    caps[12] = make_capability(
        "multimodal_pretraining",
        "model",
        "missing",
        "p1",
        false,
        "model/multimodal/minimal_fusion.s",
        "replace minimal fusion with image/audio/video encoders and interleaved data"
    )
    caps[13] = make_capability(
        "observability",
        "ops",
        "partial",
        "p1",
        false,
        "distributed/performance_monitor.s",
        "track tokens/sec, loss spikes, grad norms, amax, communication stalls, and data quality"
    )
    caps[14] = make_capability(
        "safety_governance",
        "safety",
        "partial",
        "p1",
        false,
        "safety/safety.s",
        "add policy datasets, automated jailbreak evals, and deployment gates"
    )
    caps[15] = make_capability(
        "reproducible_launch_manifest",
        "ops",
        "missing",
        "p0",
        true,
        "pretrain/config/frontier_training_plan.s",
        "emit immutable run manifest with git SHA, data hashes, topology, and hyperparameters"
    )

    caps
}

func frontier_status_score(string status) int {
    if status == "ready" {
        return 2
    }
    if status == "partial" {
        return 1
    }
    0
}

func audit_frontier_readiness([]frontier_capability caps) frontier_audit {
    int total = len(caps)
    int ready = 0
    int partial = 0
    int missing = 0
    int blockers = 0
    int score = 0

    int i = 0
    while i < total {
        score = score + frontier_status_score(caps[i].status)
        if caps[i].status == "ready" {
            ready = ready + 1
        } else if caps[i].status == "partial" {
            partial = partial + 1
        } else {
            missing = missing + 1
        }
        if caps[i].launch_blocker && caps[i].status != "ready" {
            blockers = blockers + 1
        }
        i = i + 1
    }

    float readiness = 0.0
    if total > 0 {
        readiness = (score * 100.0) / (total * 2.0)
    }

    frontier_audit {
        capabilities: caps,
        total: total,
        ready: ready,
        partial: partial,
        missing: missing,
        blockers: blockers,
        readiness_score: readiness,
        can_launch_frontier_run: blockers == 0,
    }
}

func default_frontier_audit() frontier_audit {
    audit_frontier_readiness(current_neurx_frontier_capabilities())
}

func frontier_launch_decision(frontier_audit audit) string {
    if audit.can_launch_frontier_run {
        return "launch_allowed"
    }
    if audit.readiness_score >= 70.0 {
        return "launch_blocked_complete_p0_items"
    }
    "launch_blocked_foundation_incomplete"
}

func next_frontier_p0_work(frontier_audit audit) []frontier_capability {
    []frontier_capability work = []frontier_capability{cap: audit.total}
    int out = 0
    int i = 0
    while i < audit.total {
        frontier_capability cap = audit.capabilities[i]
        if cap.priority == "p0" && cap.status != "ready" {
            work[out] = cap
            out = out + 1
        }
        i = i + 1
    }
    work
}

