


























package neurx.complete_system

import neurx.model.llm.neurx.*
import neurx.tokenizer.neurx.*
import neurx.pretrain.pipeline.*
import neurx.attention.*
import neurx.posttrain.alignment.*
import neurx.inference.engine.*





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

    []string warnings
    []string errors
}

func check_system_status() {

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


    print("[2/6] Checking NEURX tokenizer...")
    try:
        tokenizer_state tok = create_tokenizer("vocab/neurx.model")
        status.modules.tokenizer_loaded = true
        status.tokenizer_ready = true
        print(f"   ✅ NEURX tokenizer loaded (vocab size: {tok.vocab_size})")
    except Exception as e:
        append(status.warnings, "tokenizer using mock vocabulary (for testing)")
        status.modules.tokenizer_loaded = true
        print("   ⚠️ Using mock tokenizer (testing mode)")


    print("[3/6] Checking Pretraining Framework...")
    try:
        pretrain_config pt_cfg = create_neurx_200b_pretrain_config()
        assert(pt_cfg.clm_ratio + pt_cfg.mlm_ratio + pt_cfg.prefix_lm_ratio == 1.0)
        status.modules.pretraining_framework = true
        print("   ✅ Pretraining framework ready")
        print(f"      task distribution: CLM={pt_cfg.clm_ratio:.0%} MLM={pt_cfg.mlm_ratio:.0%} PrefixLM={pt_cfg.prefix_lm_ratio:.0%}")
    except Exception as e:
        append(status.errors, f"Pretraining error: {e}")
        print(f"   ❌ {e}")


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





func start_neurx_training(
    string mode = "full",
    string config_path = "",
    option<string> resume_from = none
):
    """
    English textstart NEURX-5.2 trainingpipeline

    Modes:
    - "pretrain": English texttraining (RequiredEnglish textdata)
    - "sft": English text (English textdataEnglish text fine-tune)
    - "align": alignmenttraining (DPO/GRPO/PPO)
    - "full": completepipeline (English texttraining → SFT → alignment)
    """

    print("\n" + "🚀"*35)
    print("Starting NEURX-5.2 Training Pipeline")
    print("🚀"*35 + "\n")


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
    """startEnglish texttraining"""
    print("\n" + "="*60)
    print("📖 PHASE 1: PRETRAINING")
    print("="*60)


    pretrain_config cfg
    if config_path != "":
        cfg = load_config(config_path)
    else:
        cfg = create_neurx_200b_pretrain_config()


    run_pretraining(
        model_config_path=config_path if config_path != "" else none,
        resume_from_checkpoint=resume_from
    )

func _start_sft(string config_path, option<string> resume_from):
    """startEnglish text"""
    print("\n" + "="*60)
    print("📚 PHASE 2: SUPERVISED FINE-TUNING (SFT)")
    print("="*60)

    alignment_config sft_cfg = create_sft_config()

    if config_path != "":
        sft_cfg = load_alignment_config(config_path)


    neurx_model model = load_neurx_model(sft_cfg.base_model_path)
    tokenizer_state tokenizer = create_tokenizer(sft_cfg.tokenizer_path)


    sft_trainer trainer = init_sft_trainer(model, tokenizer, sft_cfg)


    for epoch in range(sft_cfg.num_train_epochs):
        print(f"\nEpoch {epoch+1}/{sft_cfg.num_train_epochs}")
        float epoch_loss = train_sft_epoch(trainer, dataloaders["train"])
        print(f"   Epoch Loss: {epoch_loss:.4f}")


        if (epoch+1) % eval_interval == 0:
            evaluate_sft(trainer, dataloaders["eval"])


        save_checkpoint(model, f"{sft_cfg.output_dir}/epoch_{epoch+1}/")

func _start_alignment(string config_path, option<string> resume_from):
    """startalignmenttraining"""
    print("\n" + "="*60)
    print("🎯 PHASE 3: ALIGNMENT TRAINING")
    print("="*60)


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


    run_alignment_training(align_cfg)

func start_neurx_inference_server(int port = 8080, string model_path = "./checkpoints/neurx_final/"):
    """
    start NEURX-5.2 inferenceEnglish text

    Features:
    - REST API endpoint
    - Continuous batching
    - KV Cache management
    - PagedAttention (optional)
    """

    print("\n" + "="*60)
    print("🌐 Starting NEURX-5.2 Inference Server")
    print("="*60 + "\n")


    neurx_model model = load_neurx_model(model_path)
    tokenizer_state tokenizer = create_tokenizer("./vocab/neurx.model")


    inference_engine engine = init_engine(
        model=model,
        tokenizer=tokenizer,
        max_batch_size=32,
        enable_paged_attention=True,
        gpu_memory_mb=get_gpu_memory_mb()
    )


    print(f"🚀 Server starting on port {port}...")
    print(f"\nEndpoints:")
    print(f"   POST /generate     - Single generation")
    print(f"   POST /batch_generate - Batch generation")
    print(f"   GET  /status       - Server status")
    print(f"   GET  /health       - Health check\n")









func run_all_tests():
    """runEnglish texttest"""

    print("\n" + "#"*70)
    print("#  Running Complete NEURX-5.2 Test Suite")
    print("#"*70)

    bool all_passed = true


    try:
        test_neurx_architecture()
        print("✅ Architecture Tests PASSED\n")
    except:
        print("❌ Architecture Tests FAILED\n")
        all_passed = False


    try:
        test_tokenizer()
        print("✅ tokenizer Tests PASSED\n")
    except:
        print("❌ tokenizer Tests FAILED\n")
        all_passed = False


    try:
        test_pretrain_framework()
        print("✅ Pretraining Tests PASSED\n")
    except:
        print("❌ Pretraining Tests FAILED\n")
        all_passed = False


    try:
        test_attention()
        print("✅ Attention Tests PASSED\n")
    except:
        print("❌ Attention Tests FAILED\n")
        all_passed = False


    try:
        test_alignment_systems()
        print("✅ Alignment Tests PASSED\n")
    except:
        print("❌ Alignment Tests FAILED\n")
        all_passed = False


    try:
        test_inference_system()
        print("✅ Inference Tests PASSED\n")
    except:
        print("❌ Inference Tests FAILED\n")
        all_passed = False


    print("#"*70)
    if all_passed:
        print("#  🎉 ALL TESTS PASSED! System is fully functional!  ")
    else:
        print("#  ⚠️  SOME TESTS FAILED - Please check logs above  ")
    print("#"*70 + "\n")





func show_usage_examples():
    """
    English textuseexample
    """

    examples = """

╔══════════════════════════════════════════════════════════════╗
║          NEURX-5.2 Complete Training System - Quick Start          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📘 PRETRAINING (English texttraining)                                     ║
║                                                              ║
║  // English text                                                 ║
║  start_neurx_training(mode="pretrain")                        ║
║                                                              ║
║  // English textconfiguration                                                 ║
║  start_neurx_training(                                        ║
║      mode="pretrain",                                         ║
║      config_path="./configs/my_neurx_config.json",                ║
║      resume_from="./checkpoints/step_10000/"                   ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  📚 SUPERVISED FINE-TUNING (English text)                         ║
║                                                              ║
║  // English textdataEnglish text                                           ║
║  start_neurx_training(mode="sft",                             ║
║      config_path="./configs/sft_config.json"                    ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🎯 ALIGNMENT TRAINING (alignmenttraining)                              ║
║                                                              ║
║  // DPO (recommended, English text Reward Model)                               ║
║  start_neurx_training(mode="align",                            ║
║      config_path="./configs/dpo_config.json"                    ║
║  )                                                           ║
║                                                              ║
║  // GRPO (NeurX-R1 English text, English textoptimize)                           ║
║  // English text config English text method="grpo"                             ║
║                                                              ║
║  // PPO (English text RLHF, Required Reward Model)                          ║
║  // English text config English text method="ppo"                              ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🌐 INFERENCE SERVER (inferenceEnglish text)                                 ║
║                                                              ║
║  // startinferenceEnglish text                                               ║
║  start_neurx_inference_server(                                 ║
║      port=8080,                                              ║
║      model_path="./checkpoints/neurx_final/"                    ║
║  )                                                           ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🧪 TESTING (testEnglish text)                                          ║
║                                                              ║
║  // runcompletetestEnglish text                                            ║
║  run_all_tests()                                              ║
║                                                              ║
║  // English textsystemstate                                               ║
║  check_system_status()                                         ║
║                                                              ║
║  ══════════════════════════════════════════════════════════  ║
║  🔧 ADVANCED USAGE (advancedEnglish text)                                    ║
║                                                              ║
║  // English textmodelconfiguration                                               ║
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
║  // English text                                               ║
║  neurx_config vision_cfg = create_vision_9b_config()              ║
║                                                              ║
║  // English text MoE English text                                               ║
║  neurx_config moe_cfg = create_moe_200b_config_200b()             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""
    print(examples)





func main():
    """mainEnglish text"""

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


    show_usage_examples()


    print("\n🔍 Running initial system check...\n")
    check_system_status()

if __name__ == "__main__":
    main()
