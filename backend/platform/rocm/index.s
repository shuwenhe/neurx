package neurx.platform.rocm.index

struct rocm_module_info {
    string module_name
    string description
    []string exports
    string status
}

func get_rocm_modules_info() []rocm_module_info {
    [
        rocm_module_info {
            module_name: "device_manager_rocm",
            description: "ROCm 设备管理与初始化，支持多设备、GCN 架构识别",
            exports: ["rocm_device_count", "rocm_get_device", "rocm_set_device", "rocm_initialize_context"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "rocm_runtime",
            description: "ROCm 运行时绑定，包含内存管理、rocBLAS、MIOpen、流管理",
            exports: ["rocm_malloc", "rocm_free", "rocm_memcpy_h2d", "hipblas_sgemm", "rocm_stream_create"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "attention_rocm",
            description: "注意力机制实现，包含 Flash Attention v2、分页注意力、MQA/GQA、RoPE/ALiBi",
            exports: ["rocm_attention_forward", "rocm_flash_attention_v2", "rocm_paged_attention_forward", "rocm_gqa_attention_forward"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "rocm_kernels",
            description: "基础计算核，包含激活函数、规范化、采样、嵌入等",
            exports: ["rocm_gelu_forward", "rocm_layer_norm_forward", "rocm_top_k_sampling", "rocm_embedding_forward"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "moe_kernels_rdna",
            description: "混合专家实现，RDNA 架构优化，支持量化 MoE",
            exports: ["rocm_moe_forward", "rocm_expert_choice_moe", "rocm_sparse_moe_gemm_rdna3", "rocm_moe_auxiliary_loss"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "inference_server_rocm",
            description: "推理引擎，集成预填充、解码、Batch 推理、KV 缓存管理",
            exports: ["create_rocm_engine", "rocm_prefill_forward", "rocm_decode_forward", "rocm_batch_prefill"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "memory_manager_rocm",
            description: "内存管理，包含设备内存分配、KV 缓存、固定内存",
            exports: ["create_memory_allocator", "allocate_device_memory", "create_kv_cache", "allocate_pinned_memory"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "rccl_integration",
            description: "RCCL 分布式通信集成，支持 AllReduce、AllGather、点对点",
            exports: ["rocm_create_rccl_comm", "rocm_rccl_all_reduce", "rocm_rccl_all_gather", "rocm_rccl_broadcast"],
            status: "stable"
        },
        rocm_module_info {
            module_name: "quick_start",
            description: "快速开始示例和测试函数",
            exports: ["rocm_hello_world", "create_test_model", "run_inference_example", "benchmark_rocm_kernels"],
            status: "example"
        }
    ]
}

func get_rocm_architecture_support() []string {
    [
        "CDNA: MI250, MI250X, MI300, MI300X, MI325X",
        "RDNA 3: RX 7900 XTX, RX 9070 XT (early)",
        "RDNA 3.5: Strix Point, Strix Halo",
        "RDNA 4: RX 9070, RX 9080 (future)"
    ]
}

func get_rocm_feature_matrix() []string {
    [
        "✓ Multi-device support",
        "✓ HIP Memory Management",
        "✓ rocBLAS Integration (GEMM)",
        "✓ MIOpen Support",
        "✓ Flash Attention v2",
        "✓ Paged Attention",
        "✓ Multi-Query Attention (MQA)",
        "✓ Grouped-Query Attention (GQA)",
        "✓ RoPE/ALiBi Position Encoding",
        "✓ Mixed-Precision Training",
        "✓ Expert Choice MoE",
        "✓ Quantized MoE",
        "✓ Load Balancing Loss",
        "✓ Layer Normalization",
        "✓ RMS Normalization",
        "✓ Activation Functions (GELU, ReLU, SiLU)",
        "✓ Top-k/Top-p Sampling",
        "✓ RCCL Distributed Backend",
        "✓ KV Cache Management",
        "✓ Pinned Memory Support"
    ]
}

func get_comparison_with_vllm_sglang() []string {
    [
        "NeurX ROCm vs vLLM:",
        "  - NeurX: Compile-time optimization, S language, direct hardware access",
        "  - vLLM: Python + CUDA, runtime flexibility",
        "",
        "NeurX ROCm vs SGLang:",
        "  - NeurX: Pure S implementation, specialized for inference performance",
        "  - SGLang: Python framework, broader feature set",
        "",
        "Comparison Table:",
        "Feature          | NeurX  | vLLM   | SGLang",
        "Flash Attention  | ✓      | ✓      | ✓",
        "MoE Support      | ✓      | ✓      | ✓",
        "Distributed      | RCCL   | RCCL   | RCCL",
        "RDNA Optim       | ✓✓     | ✓      | ✓",
        "Compile Optim    | ✓✓     | ⚠      | ⚠",
        "Quantization     | ✓      | ✓      | ✓"
    ]
}

func print_rocm_setup_guide() string {
    guide = "ROCm Setup Guide for NeurX\n"
    guide + "1. Install ROCm: https:
    guide + "2. Install Dependencies: rocBLAS, MIOpen, RCCL\n"
    guide + "3. Export ROCm path: export ROCM_HOME=/opt/rocm\n"
    guide + "4. Build: make -f Makefile.rocm all\n"
    guide + "5. Test: make -f Makefile.rocm test\n"
    guide + "6. Install: make -f Makefile.rocm install"
}

func rocm_deployment_checklist() []string {
    [
        "Pre-deployment:",
        "  [ ] ROCm 5.7+ installed",
        "  [ ] rocBLAS available",
        "  [ ] MIOpen installed",
        "  [ ] RCCL built (if distributed)",
        "  [ ] S compiler available",
        "",
        "Build & Test:",
        "  [ ] Run 'make check-rocm' to verify setup",
        "  [ ] Build with 'make -f Makefile.rocm all'",
        "  [ ] Run unit tests",
        "  [ ] Run integration tests",
        "",
        "Deployment:",
        "  [ ] Install libraries to system",
        "  [ ] Set LD_LIBRARY_PATH",
        "  [ ] Set ROCM_HOME",
        "  [ ] Verify device visibility with 'rocm-smi'",
        "  [ ] Test with benchmark suite",
        "",
        "Production:",
        "  [ ] Enable monitoring/logging",
        "  [ ] Configure memory pooling",
        "  [ ] Set up distributed backend",
        "  [ ] Performance profiling",
        "  [ ] Load testing"
    ]
}
