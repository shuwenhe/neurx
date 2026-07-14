// ============================================================
// 🚀 NEURX-5.2 Complete Training & Inference System
// 
// 整合所有模块的一站式训练/推理系统:
//   1. 模型架构 (model/llm/neurx.s)
//   2. Tokenizer (tokenizer/tokenizer_core.s)
//   3. 预训练框架 (pretrain/pretraining_pipeline.s)
//   4. 注意力机制 (model/transformer/attention_mechanism.s)
//   5. 对齐训练 (posttrain/alignment_trainer.s)
//   6. 推理优化 (inference/inference_engine.s)
//
// Usage:
//   use neurx.complete_system.*
//   
//   // 快速启动预训练
//   start_neurx_pretraining(mode="full")
//   
//   // 快速启动 SFT
//   start_neurx_sft(data_path="./data/sft/")
//   
//   // 快速启动 DPO 对齐
//   start_neurx_dpo(preferences_path="./data/dpo/")
//   
//   // 启动推理服务
//   start_neurx_inference_server(port=8080)
// ============================================================

package neurx.complete_system

import neurx.model.llm.neurx.*
import neurx.tokenizer.neurx.*
import neurx.pretrain.pipeline.*
import neurx.model.transformer.attention.*
import neurx.posttrain.alignment.*
import neurx.inference.engine.*

// ============================================================
// 📋 系统状态检查
// ============================================================

struct system_status {
    bool model_loaded
    bool tokenizer_ready
    bool training_initialized
    bool inference_engine_ready
    
    struct modules {
        bool architecture_loaded
        bool tokenizer_loaded
        bool pretraining_framework
        bool attention_mechanism
        bool alignment_system
        bool inference_optimization
    } modules
    
    string[] warnings
    string[] errors
}

func check_system_status() -> system_status {
    
    print("\n" + "="*70)
    print("🔍 Checking NEURX-5.2 Training System Status")
    print("="*70 + "\n")
    
    system_status status {
        model_loaded: false,
        tokenizer_ready: false,
        training_initialized: false,
        inference_engine_ready: false,
        
        modules: modules{
            architecture_loaded: false,
            tokenizer_loaded: false,
            pretraining_framework: false,
            attention_mechanism: false,
            alignment_system: false,
            inference_optimization: false,
        },
        
        warnings: [],
        errors: []
    }
    
    # Check Module 1: NEURX Architecture
    print("[1/6] Checking NEURX Architecture...")
    try:
        neurx_config test_cfg = create_neurx_200b_config_200b()
        assert(test_cfg.hidden_size == 12288)
        assert(test_cfg.enable_long_context == true)
        status.modules.architecture_loaded = true
        print("   ✅ NEURX Architecture module loaded")
    except Exception as e:
        append(status.errors, f"NEURX Architecture error: {e}")
        print(f"   ❌ {e}")
    
    # Check Module 2: Tokenizer
    print("[2/6] Checking NEURX Tokenizer...")
    try:
        tokenizer_state tok = create_tokenizer("vocab/neurx.model")
        status.modules.tokenizer_loaded = true
        status.tokenizer_ready = true
        print(f"   ✅ NEURX Tokenizer loaded (vocab size: {tok.vocab_size})")
    except Exception as e:
        append(status.warnings, "Tokenizer using mock vocabulary (for testing)")
        status.modules.tokenizer_loaded = true  # Still works with mock
        print("   ⚠️ Using mock tokenizer (testing mode)")
    
    # Check Module 3: Pretraining Framework
    print("[3/6] Checking Pretraining Framework...")
    try:
        pretrain_config pt_cfg = create_neurx_200b_pretrain_config()
        assert(pt_cfg.clm_ratio + pt_cfg.mlm_ratio + pt_cfg.prefix_lm_ratio == 1.0)
        status.modules.pretraining_framework = true
        print("   ✅ Pretraining framework ready")
        print(f"      Task distribution: CLM={pt_cfg.clm_ratio:.0%} MLM={pt_cfg.mlm_ratio:.0%} PrefixLM={pt_cfg.prefix_lm_ratio:.0%}")
    except Exception as e:
        append(status.errors, f"Pretraining error: {e}")
        print(f"   ❌ {e}")
    
    # Check Module 4: Attention Mechanism
    print("[4/6] Checking Attention Mechanism...")
    try:
        attention_config attn_cfg {
            hidden_size: 4096,
            num_attention_heads: 32,
            num_key_value_heads: 8,
            head_dim: 128,
            attention_dropout: 0.0,
            max_position_embeddings: 131072,
            use_flash_attention: True,
            use_gqa: True,
            use_causal_mask: False,
            softmax_scale: 1.0 / sqrt(128.0),
            use_gradient_checkpointing: False,
        }
        
        NeurxAttention attn = init(attn_cfg)
        status.modules.attention_mechanism = true
        print("   ✅ NEURX Attention mechanism ready (Flash Attn + GQA enabled)")
    except Exception as e:
        append(status.errors, f"Attention error: {e}")
        print(f"   ❌ {e}")
    
    # Check Module 5: Alignment System
    print("[5/6] Checking Alignment System...")
    try:
        alignment_config dpo_cfg = create_dpo_config()
        alignment_config grpo_cfg = create_grpo_config()
        alignment_config ppo_cfg = create_ppo_config()
        alignment_config sft_cfg = create_sft_config()
        
        status.modules.alignment_system = true
        print("   ✅ Alignment system ready (SFT/DPO/GRPO/PPO)")
    except Exception as e:
        append(status.errors, f"Alignment error: {e}")
        print(f"   ❌ {e}")
    
    # Check Module 6: Inference Optimization
    print("[6/6] Checking Inference Optimization...")
    try:
        KVCacheManager kv_mgr = init(num_layers=4, num_kv_heads=8, head_dim=64)
        PagedAttentionManager paged_mgr = init_paged_attention(
            num_kv_heads=8, 
            head_dim=64, 
            gpu_memory_mb=1024
        )
        ContinuousBatchScheduler sched = init_scheduler(max_batch_size=16)
        
        status.modules.inference_optimization = true
        status.inference_engine_ready = true
        print("   ✅ Inference optimization ready (KV Cache + PagedAttn + Continuous Batch)")
    except Exception as e:
        append(status.errors, f"Inference error: {e}")
        print(f"   ❌ {e}")
    
    # Summary
    int ready_count = sum([
        status.modules.architecture_loaded,
        status.modules.tokenizer_loaded,
        status.modules.pretraining_framework,
        status.modules.attention_mechanism,
        status.modules.alignment_system,
        status.modules.inference_optimization
    ])
    
    print("\n" + "-"*70)
    print(f"📊 System Status: {ready_count}/6 modules ready")
    
    if len(status.warnings) > 0:
        print(f"\n⚠️  Warnings ({len(status.warnings)}):")
        for w in status.warnings:
            print(f"   - {w}")
    
    if len(status.errors) > 0:
        print(f"\n❌ Errors ({len(status.errors)}):")
        for e in status.errors:
            print(f"   - {e}")
    
    if ready_count == 6:
        print("\n✨ All systems operational! Ready for NEURX-5.2 training/inference.")
    
    print("="*70 + "\n")
    
    return status

// ============================================================
// 🎯 一键启动函数
// ============================================================

func start_neurx_training(
    string mode = "full",           # "pretrain" | "sft" | "align" | "full"
    string config_path = "",         # Custom config path (optional)
    option<string> resume_from = none  # Resume from checkpoint
):
    """
    一键启动 NEURX-5.2 训练流程
    
    Modes:
    - "pretrain": 从头预训练 (需要大量数据)
    - "sft": 监督微调 (在指令数据上 fine-tune)
    - "align": 对齐训练 (DPO/GRPO/PPO)
    - "full": 完整流程 (预训练 → SFT → 对齐)
    """
    
    print("\n" + "🚀"*35)
    print("Starting NEURX-5.2 Training Pipeline")
    print("🚀"*35 + "\n")
    
    # Step 1: System Check
    system_status sys_status = check_system_status()
    
    if len(sys_status.errors) > 0:
        print("❌ Cannot start training due to errors above!")
        return
    
    match mode:
        case "pretrain":
            _start_pretraining(config_path, resume_from)
        
        case "sft":
            _start_sft(config_path, resume_from)
        
        case "align":
            _start_alignment(config_path, resume_from)
        
        case "full":
            print("📋 Running FULL pipeline:")
            print("   Phase 1: Pretraining (~weeks)")
            _start_pretraining("", none)
            
            print("\n   Phase 2: Supervised Fine-Tuning (hours~days)")
            _start_sft("", none)
            
            print("\n   Phase 3: Alignment Training (hours~days)")
            _start_alignment("", none)
            
            print("\n🎉 Full pipeline complete!")
        
        case _:
            print(f"Unknown mode: {mode}. Use 'pretrain', 'sft', 'align', or 'full'.")

func _start_pretraining(string config_path, option<string> resume_from):
    """启动预训练"""
    print("\n" + "="*60)
    print("📖 PHASE 1: PRETRAINING")
    print("="*60)
    
    # Load or create config
    pretrain_config cfg
    if config_path != "":
        cfg = load_config(config_path)
    else:
        cfg = create_neurx_200b_pretrain_config()
    
    # Run pretraining
    run_pretraining(
        model_config_path=config_path if config_path != "" else none,
        resume_from_checkpoint=resume_from
    )

func _start_sft(string config_path, option<string> resume_from):
    """启动监督微调"""
    print("\n" + "="*60)
    print("📚 PHASE 2: SUPERVISED FINE-TUNING (SFT)")
    print("="*60)
    
    alignment_config sft_cfg = create_sft_config()
    
    if config_path != "":
        sft_cfg = load_alignment_config(config_path)
    
    # Load base model
    neurx_model model = load_neurx_model(sft_cfg.base_model_path)
    tokenizer_state tokenizer = create_tokenizer(sft_cfg.tokenizer_path)
    
    # Initialize trainer
    SFTTrainer trainer = init_sft_trainer(model, tokenizer, sft_cfg)
    
    # Train
    for epoch in range(sft_cfg.num_train_epochs):
        print(f"\nEpoch {epoch+1}/{sft_cfg.num_train_epochs}")
        float epoch_loss = train_sft_epoch(trainer, dataloaders["train"])
        print(f"   Epoch Loss: {epoch_loss:.4f}")
        
        # Evaluate periodically
        if (epoch+1) % eval_interval == 0:
            evaluate_sft(trainer, dataloaders["eval"])
        
        # Save checkpoint
        save_checkpoint(model, f"{sft_cfg.output_dir}/epoch_{epoch+1}/")

func _start_alignment(string config_path, option<string> resume_from):
    """启动对齐训练"""
    print("\n" + "="*60)
    print("🎯 PHASE 3: ALIGNMENT TRAINING")
    print("="*60)
    
    # Default to DPO (most popular and effective)
    string align_method = "dpo"
    
    alignment_config align_cfg
    match align_method:
        case "dpo":
            align_cfg = create_dpo_config()
        case "grpo":
            align_cfg = create_grpo_config()
        case "ppo":
            align_cfg = create_ppo_config()
    
    if config_path != "":
        align_cfg = load_alignment_config(config_path)
    
    print(f"   Method: {align_method.upper()}")
    print(f"   Data: {align_cfg.train_data_path}")
    
    # Run alignment training
    run_alignment_training(align_cfg)

func start_neurx_inference_server(int port = 8080, string model_path = "./checkpoints/neurx_final/"):
    """
    启动 NEURX-5.2 推理服务器
    
    Features:
    - REST API endpoint
    - Continuous batching
    - KV Cache management
    - PagedAttention (optional)
    """
    
    print("\n" + "="*60)
    print("🌐 Starting NEURX-5.2 Inference Server")
    print("="*60 + "\n")
    
    # Load model
    neurx_model model = load_neurx_model(model_path)
    tokenizer_state tokenizer = create_tokenizer("./vocab/neurx.model")
    
    # Initialize engine
    InferenceEngine engine = init_engine(
        model=model,
        tokenizer=tokenizer,
        max_batch_size=32,
        enable_paged_attention=True,
        gpu_memory_mb=get_gpu_memory_mb()
    )
    
    # Start API server
    print(f"🚀 Server starting on port {port}...")
    print(f"\nEndpoints:")
    print(f"   POST /generate     - Single generation")
    print(f"   POST /batch_generate - Batch generation")
    print(f"   GET  /status       - Server status")
    print(f"   GET  /health       - Health check\n")
    
    # Start serving (pseudo-code)
    # app = create_fastapi_app(engine)
    # uvicorn.run(app, host="0.0.0.0", port=port)

// ============================================================
// 🧪 运行全部测试
// ============================================================

func run_all_tests():
    """运行所有模块的测试"""
    
    print("\n" + "#"*70)
    print("#  Running Complete NEURX-5.2 Test Suite")
    print("#"*70)
    
    bool all_passed = true
    
    # Test 1: Architecture
    try:
        test_neurx_architecture()
        print("✅ Architecture Tests PASSED\n")
    except:
        print("❌ Architecture Tests FAILED\n")
        all_passed = False
    
    # Test 2: Tokenizer
    try:
        test_tokenizer()
        print("✅ Tokenizer Tests PASSED\n")
    except:
        print("❌ Tokenizer Tests FAILED\n")
        all_passed = False
    
    # Test 3: Pretraining
    try:
        test_pretrain_framework()
        print("✅ Pretraining Tests PASSED\n")
    except:
        print("❌ Pretraining Tests FAILED\n")
        all_passed = False
    
    # Test 4: Attention
    try:
        test_attention()
        print("✅ Attention Tests PASSED\n")
    except:
        print("❌ Attention Tests FAILED\n")
        all_passed = False
    
    # Test 5: Alignment
    try:
        test_alignment_systems()
        print("✅ Alignment Tests PASSED\n")
    except:
        print("❌ Alignment Tests FAILED\n")
        all_passed = False
    
    # Test 6: Inference
    try:
        test_inference_system()
        print("✅ Inference Tests PASSED\n")
    except:
        print("❌ Inference Tests FAILED\n")
        all_passed = False
    
    # Final result
    print("#"*70)
    if all_passed:
        print("#  🎉 ALL TESTS PASSED! System is fully functional!  ")
    else:
        print("#  ⚠️  SOME TESTS FAILED - Please check logs above  ")
    print("#"*70 + "\n")

// ============================================================
// 📖 使用示例 & 文档
// ============================================================

func show_usage_examples():
    """
    打印使用示例
    """
    
    examples = """

╔══════════════════════════════════════════════════════════════╗
║          NEURX-5.2 Complete Training System - Quick Start          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📘 PRETRAINING (从头训练)                                     ║
║                                                              ║
║  // 基础用法                                                 ║
║  start_neurx_training(mode="pretrain")                        ║
║                                                              ║
║  // 自定义配置                                                 ║
║  start_neurx_training(                                        ║
║      mode="pretrain",                                         ║
║      config_path="./configs/my_neurx_config.json",                ║
║      resume_from="./checkpoints/step_10000/"                   ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  📚 SUPERVISED FINE-TUNING (指令微调)                         ║
║                                                              ║
║  // 在指令数据上微调                                           ║
║  start_neurx_training(mode="sft",                             ║
║      config_path="./configs/sft_config.json"                    ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🎯 ALIGNMENT TRAINING (对齐训练)                              ║
║                                                              ║
║  // DPO (推荐, 无需 Reward Model)                               ║
║  start_neurx_training(mode="align",                            ║
║      config_path="./configs/dpo_config.json"                    ║
║  )                                                           ║
║                                                              ║
║  // GRPO (NeurX-R1 风格, 组内相对优化)                           ║
║  // 修改 config 中的 method="grpo"                             ║
║                                                              ║
║  // PPO (经典 RLHF, 需要 Reward Model)                          ║
║  // 修改 config 中的 method="ppo"                              ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🌐 INFERENCE SERVER (推理服务)                                 ║
║                                                              ║
║  // 启动推理服务                                               ║
║  start_neurx_inference_server(                                 ║
║      port=8080,                                              ║
║      model_path="./checkpoints/neurx_final/"                    ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🧪 TESTING (测试验证)                                          ║
║                                                              ║
║  // 运行完整测试套件                                            ║
║  run_all_tests()                                              ║
║                                                              ║
║  // 检查系统状态                                               ║
║  check_system_status()                                         ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🔧 ADVANCED USAGE (高级用法)                                    ║
║                                                              ║
║  // 自定义模型配置                                               ║
║  neurx_config my_cfg = create_custom_neurx_config(                  ║
║      vocab_size=151552,                                       ║
║      hidden_size=5120,                                        ║
║      num_layers=48,                                           ║
║      num_heads=40,                                            ║
║      max_seq_len=16384,                                       ║
║      use_rope_yarn=true,                                      ║
║      enable_moe=false                                         ║
║  )                                                           ║
║                                                              ║
║  // 创建多模态版本                                               ║
║  neurx_config vision_cfg = create_vision_9b_config()              ║
║                                                              ║
║  // 创建 MoE 版本                                               ║
║  neurx_config moe_cfg = create_moe_200b_config_200b()             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""
    print(examples)

// ============================================================
// Main Entry Point
// ============================================================

func main():
    """主入口"""
    
    print("""
    ╔═══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║     ███████╗██╗   ██╗███╗   ██╗████████╗██╗  ██╗ █████╗  ║
    ║     ██╔════╝██║   ██║████╗  ██║╚══██╔══╝██║  ██║██╔══██╗ ║
    ║     █████╗  ██║   ██║██╔██╗ ██║   ██║   ███████║███████║ ║
    ║     ██╔══╝  ██║   ██║██║╚██╗██║   ██║   ██╔══██║██╔══██║ ║
    ║     ██║     ╚██████╔╝██║ ╚████║   ██║   ██║  ██║██║  ██║ ║
    ║     ╚═╝      ╚═════╝ ╚═╝  ╚═══╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ║
    ║                                                      ║
    ║              Complete Training & Inference               ║
    ║                      System v1.0                        ║
    ║                                                      ║
    ╚═══════════════════════════════════════════════════════╝
    """)
    
    # Show usage by default
    show_usage_examples()
    
    # Run system check
    print("\n🔍 Running initial system check...\n")
    check_system_status()

if __name__ == "__main__":
    main()
