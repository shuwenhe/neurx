package neurx.test.test_all_new_modules

import "neurx.model.transformer.trae_moe"
import "neurx.training.rl_training"
import "neurx.model.multimodal.vision_encoder"
import "neurx.model.transformer.long_context"
import "neurx.inference.speculative_decoding"
import "neurx.distributed.veomni.veomni"
import "neurx.model.reasoning.chain_of_thought"
import "neurx.util.math"

func test_trae_moe() bool {
    trae_moe_config config = trae_moe.new_trae_moe_config()
    config.num_experts = 4
    config.top_k = 2
    config.hidden_dim = 64
    config.expert_dim = 32
    
    trae_moe_layer layer = trae_moe.new_trae_moe_layer(config)
    
    int batch_size = 2
    int seq_len = 4
    int total_tokens = batch_size * seq_len
    int hidden_dim = config.hidden_dim
    
    []float hidden_states = math.allocate_float(total_tokens * hidden_dim, 0.1)
    
    trae_forward_result result = trae_moe.trae_moe_forward(layer, hidden_states, batch_size, seq_len)
    
    bool success = len(result.output) == total_tokens * hidden_dim && result.aux_loss >= 0.0
    
    if success {
        print("TRAE-MoE test passed")
    } else {
        print("TRAE-MoE test failed")
    }
    
    success
}

func test_rl_training() bool {
    rl_config config = rl_training.new_rl_config()
    config.rollout_length = 10
    config.hidden_dim = 64
    
    rl_state state = rl_training.new_rl_state(config)
    
    []float obs = math.allocate_float(config.hidden_dim, 0.5)
    
    state = rl_training.collect_rollout_step(state, obs)
    
    bool success = state.current_rollout.length > 0 && state.step_count >= 1
    
    if success {
        print("RL Training test passed")
    } else {
        print("RL Training test failed")
    }
    
    success
}

func test_vision_encoder() bool {
    vision_encoder_config config = vision_encoder.new_vision_encoder_config()
    config.hidden_dim = 64
    config.num_layers = 2
    config.num_heads = 4
    config.patch_size = 4
    
    vision_encoder encoder = vision_encoder.new_vision_encoder(config)
    
    int width = 32
    int height = 32
    int num_channels = 3
    
    []float image = math.allocate_float(width * height * num_channels, 0.5)
    
    image_feature feature = vision_encoder.encode_image(encoder, image, width, height)
    
    int expected_patches = (width / config.patch_size) * (height / config.patch_size) + 1
    
    bool success = feature.num_tokens == expected_patches && len(feature.tokens) == expected_patches * config.hidden_dim
    
    if success {
        print("Vision Encoder test passed")
    } else {
        print("Vision Encoder test failed")
    }
    
    success
}

func test_long_context() bool {
    long_context_config config = long_context.new_long_context_config()
    config.max_context_length = 8192
    config.sliding_window_size = 1024
    config.hidden_dim = 64
    config.num_heads = 4
    
    long_context_state state = long_context.new_long_context_state(config)
    
    int seq_len = 100
    int hidden_dim = config.hidden_dim
    
    []float hidden_states = math.allocate_float(seq_len * hidden_dim, 0.1)
    
    ([]float output, long_context_state new_state) = long_context.long_context_forward(state, hidden_states, seq_len)
    
    bool success = len(output) == seq_len * hidden_dim && new_state.sw_state.current_position == seq_len
    
    if success {
        print("Long Context test passed")
    } else {
        print("Long Context test failed")
    }
    
    success
}

func test_speculative_decoding() bool {
    speculative_config config = speculative_decoding.new_speculative_config()
    config.max_speculation_steps = 3
    config.beam_width = 2
    
    speculative_state state = speculative_decoding.new_speculative_state(config)
    
    []int context = []int{1, 2, 3, 4, 5}
    
    ([]int tokens, speculative_state new_state) = speculative_decoding.speculative_decode_step(state, context)
    
    bool success = len(tokens) > 0 && new_state.speedup_factor >= 1.0
    
    if success {
        print("Speculative Decoding test passed")
    } else {
        print("Speculative Decoding test failed")
    }
    
    success
}

func test_veomni() bool {
    veomni_config config = veomni.new_veomni_config()
    config.world_size = 8
    config.data_parallel_size = 2
    config.model_parallel_size = 2
    config.expert_parallel_size = 2
    config.pipeline_parallel_size = 1
    
    veomni_state state = veomni.new_veomni_state(config)
    state = veomni.configure_hybrid_parallelism(state, 0)
    
    int test_size = 16
    []float test_data = math.allocate_float(test_size, 0.5)
    
    []float reduced = veomni.allreduce(state.dp_group, test_data)
    
    bool success = len(reduced) == test_size
    
    if success {
        print("VeOmni test passed")
    } else {
        print("VeOmni test failed")
    }
    
    success
}

func test_chain_of_thought() bool {
    cot_config config = chain_of_thought.new_cot_config()
    config.max_steps = 5
    config.num_samples = 2
    config.strategy = chain_of_thought.STEP_BY_STEP
    
    cot_state state = chain_of_thought.new_cot_state(config)
    
    []int input_tokens = math.allocate_int(10, 1)
    
    reasoning_result result = chain_of_thought.cot_reason(state, input_tokens, 10)
    
    bool success = len(result.final_tokens) > 0 && result.num_steps > 0
    
    if success {
        print("Chain of Thought test passed")
    } else {
        print("Chain of Thought test failed")
    }
    
    success
}

func run_all_tests() int {
    int passed = 0
    int total = 7
    
    print("Running all new module tests...\n")
    
    if test_trae_moe() { passed = passed + 1 }
    if test_rl_training() { passed = passed + 1 }
    if test_vision_encoder() { passed = passed + 1 }
    if test_long_context() { passed = passed + 1 }
    if test_speculative_decoding() { passed = passed + 1 }
    if test_veomni() { passed = passed + 1 }
    if test_chain_of_thought() { passed = passed + 1 }
    
    print("\nTest Results: " + string(passed) + "/" + string(total) + " passed")
    
    if passed == total {
        print("All tests passed!")
        return 0
    } else {
        print("Some tests failed")
        return 1
    }
}

func print(string msg) {
}