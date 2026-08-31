package neurx.posttrain.rlhf.value_model_examples
use neurx.posttrain.rlhf.value_model_trainer.*
func create_value_config() value_config {
    value_config {
        seq_len: 128,
        hidden_size: 256,
        num_layers: 1,
        learning_rate: 5e-4,
        gamma: 0.99,
        gae_lambda: 0.95,
        batch_size: 32,
        num_epochs: 3,
        weight_decay: 0.0,
        value_loss_coef: 0.5,
        max_grad_norm: 0.5,
        global_rank: 0,
        world_size: 1,
        dp_degree: 1,
        use_mixed_precision: false,
        checkpoint_dir: "./checkpoints",
        checkpoint_interval: 10,
    }
}

func example_basic_value_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 1: Basic Value model Training                    ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    value_config cfg = create_value_config()
    value_state state = new_value_state(cfg)
    print("[Configuration]")
    print("  Hidden size: " + int_to_string_ex(cfg.hidden_size))
    print("  Sequence length: " + int_to_string_ex(cfg.seq_len))
    print("  Learning rate: " + float_to_string_ex(cfg.learning_rate))
    print("  Gamma (discount): " + float_to_string_ex(cfg.gamma))
    print("  Lambda (GAE): " + float_to_string_ex(cfg.gae_lambda))
    print("")
    int num_trajectories = 5
    int steps_per_trajectory = 32
    print("[sample Trajectories]")
    print("  Number of trajectories: " + int_to_string_ex(num_trajectories))
    print("  Steps per trajectory: " + int_to_string_ex(steps_per_trajectory))
    print("")
    []value_trajectory trajectories = make([]value_trajectory, num_trajectories)
    int t = 0
    for t < num_trajectories {
        value_trajectory traj = value_trajectory {
            trajectory_id: t,
            steps: make([]value_trajectory_step, steps_per_trajectory),
            length: steps_per_trajectory,
            total_reward: 0.0,
            mean_value: 0.0,
            max_advantage: 0.0,
            min_advantage: 0.0,
        }
        int s = 0
        for s < steps_per_trajectory {
            value_trajectory_step step = value_trajectory_step {
                observation: make([]float, cfg.seq_len),
                reward: 0.5 + (s as float) / (steps_per_trajectory as float) * 0.5,
                value_estimate: 0.4,
                next_value_estimate: 0.45,
                advantage: 0.0,
                return_value: 0.0,
                is_terminal: (s == steps_per_trajectory - 1),
            }
            int i = 0
            for i < cfg.seq_len {
                step.observation = append_float_ex(step.observation, 0.1)
                i = i + 1
            }
            traj.total_reward = traj.total_reward + step.reward
            traj.steps = append_step_ex(traj.steps, step)
            s = s + 1
        }
        trajectories = append_trajectory_ex(trajectories, traj)
        t = t + 1
    }
    print("[Starting Training]")
    print("  Epochs: " + int_to_string_ex(cfg.num_epochs))
    print("")
    state = start_value_training(cfg, trajectories)
    print("")
}

func example_gae_advantage_estimation() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 2: GAE Advantage Estimation                      ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[GAE Algorithm]")
    print("Step 1: Compute TD Residuals")
    print("  δ_t = r_t + γV(s_{t+1}) - V(s_t)")
    print("")
    print("Step 2: Compute GAE")
    print("  A_t = δ_t + (γλ)δ_{t+1} + (γλ)²δ_{t+2} + ...")
    print("")
    print("Step 3: Compute Returns")
    print("  G_t = A_t + V(s_t)")
    print("")
    print("[Example trajectory]")
    print("  Step | Reward | V(s)  | V(s+1) | δ     | A(GAE) | G(return)")
    print("  ──── ┼─────── ┼─────── ┼─────── ┼─────── ┼──────── ┼─────────")
    float[] rewards = make([]float, 5)
    rewards = append_float_ex(rewards, 0.5)
    rewards = append_float_ex(rewards, 0.6)
    rewards = append_float_ex(rewards, 0.7)
    rewards = append_float_ex(rewards, 0.8)
    rewards = append_float_ex(rewards, 0.9)
    float[] values = make([]float, 5)
    values = append_float_ex(values, 0.3)
    values = append_float_ex(values, 0.4)
    values = append_float_ex(values, 0.5)
    values = append_float_ex(values, 0.6)
    values = append_float_ex(values, 0.7)
    float gamma = 0.99
    float lambda = 0.95
    int i = 0
    for i < 5 {
        float r = rewards[i]
        float v = values[i]
        float v_next = if i < 4 { values[i + 1] } else { 0.0 }
        float delta = r + gamma * v_next - v
        float advantage = delta
        float return_val = advantage + v
        string step_str = int_to_string_ex(i + 1)
        string r_str = float_to_string_ex(r)
        string v_str = float_to_string_ex(v)
        string vn_str = float_to_string_ex(v_next)
        string d_str = float_to_string_ex(delta)
        string a_str = float_to_string_ex(advantage)
        string g_str = float_to_string_ex(return_val)
        print("   " + step_str + "  |  " + r_str + "  |  " + v_str + "  |  " + vn_str + "  |  " + d_str + "  |  " + a_str + "   |  " + g_str)
        i = i + 1
    }
    print("")
    print("[Key Insights]")
    print("  • TD residual δ captures immediate difference")
    print("  • λ controls bootstrapping (0=one-step, 1=full return)")
    print("  • GAE reduces variance while maintaining bias")
    print("")
}

func example_distributed_value_training() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 3: Distributed Multi-GPU Value Training          ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    int num_gpus = 8
    int global_batch_size = 256
    int batch_per_gpu = global_batch_size / num_gpus
    print("[Distributed Setup]")
    print("  Total GPUs: " + int_to_string_ex(num_gpus))
    print("  Global batch size: " + int_to_string_ex(global_batch_size))
    print("  batch_2 per GPU: " + int_to_string_ex(batch_per_gpu))
    print("")
    print("[Gradient Synchronization]")
    print("  Each GPU computes gradients on its batch")
    print("  AllReduce averages gradients across GPUs")
    print("  All GPUs perform identical parameter updates")
    print("")
    print("[GPU Progress]")
    int gpu = 0
    for gpu < num_gpus {
        print("  GPU " + int_to_string_ex(gpu) + ": Processing batch " + int_to_string_ex(gpu * batch_per_gpu))
        gpu = gpu + 1
    }
    print("")
    print("[Speedup Analysis]")
    print("  Single GPU: 1.0x")
    print("  2 GPUs:     1.95x (98% efficiency)")
    print("  4 GPUs:     3.88x (97% efficiency)")
    print("  8 GPUs:     7.75x (97% efficiency)")
    print("")
}

func example_value_ppo_integration() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 4: Value model Integration with PPO              ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[PPO Training Pipeline]")
    print("")
    print("1️⃣  Rollout Collection")
    print("   - Policy generates trajectories")
    print("   - Store (state, action, reward, log_prob)")
    print("")
    print("2️⃣  Value Estimation")
    print("   - Value network predicts V(s)")
    print("   - Compute TD residuals: δ_t = r_t + γV(s_{t+1}) - V(s_t)")
    print("")
    print("3️⃣  Advantage Computation")
    print("   - GAE: A_t = δ_t + (γλ)δ_{t+1} + ...")
    print("   - Returns: G_t = A_t + V(s_t)")
    print("")
    print("4️⃣  Policy Update")
    print("   - Compute PPO loss with advantages")
    print("   - Update policy network")
    print("")
    print("5️⃣  Value Update")
    print("   - Compute value loss: (V(s) - G_t)²")
    print("   - Update value network with MSE loss")
    print("")
    print("6️⃣  Monitor KL Divergence")
    print("   - If KL too high: early stopping")
    print("   - Continue to next iteration")
    print("")
}

func example_value_performance_monitoring() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 5: Value model Performance Monitoring            ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Key Metrics]")
    print("")
    print("1. MSE Loss (Mean Squared Error)")
    print("   L = (1/N) Σ(V(s) - G_t)²")
    print("   Target: <0.01 after convergence")
    print("")
    print("2. MAE (Mean Absolute Error)")
    print("   L = (1/N) Σ|V(s) - G_t|")
    print("   Interpretation: avg prediction error in value units")
    print("")
    print("3. R² (Explained Variance)")
    print("   R² = 1 - SS_res / SS_tot")
    print("   Range: 0-1, higher is better")
    print("   Target: >0.95")
    print("")
    print("4. Max Absolute Error")
    print("   Catches outliers in value predictions")
    print("   Target: <0.5 (varies by reward scale)")
    print("")
    print("[Typical Training Curve]")
    print("  Epoch  | Loss    | MAE    | R²")
    print("  ────── ┼────────── ┼──────── ┼─────")
    print("  1      | 0.4532  | 0.521  | 0.52")
    print("  2      | 0.2847  | 0.384  | 0.71")
    print("  3      | 0.1921  | 0.298  | 0.83")
    print("  4      | 0.1205  | 0.219  | 0.90")
    print("  5      | 0.0847  | 0.163  | 0.95")
    print("")
    print("[Troubleshooting]")
    print("  • High loss: Increase learning rate or hidden size")
    print("  • Unstable: Use gradient clipping (max_grad_norm)")
    print("  • Slow convergence: Reduce weight decay")
    print("")
}

func example_full_alignment_pipeline() {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║  Example 6: Full Alignment Pipeline                       ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("[Stage 1: Supervised Fine-Tuning (SFT)]")
    print("  Input: Base model + instruction pairs")
    print("  Output: SFT checkpoint")
    print("  Duration: 1 week on 64 A100s")
    print("")
    print("[Stage 2: Reward model Training]")
    print("  Input: SFT model + human preferences")
    print("  Output: Learned reward function")
    print("  Duration: 3-5 days on 8 A100s")
    print("")
    print("[Stage 3: Value model Training]")
    print("  Input: SFT model + trajectory data")
    print("  Output: Value estimates V(s)")
    print("  Duration: 1-2 days on 8 A100s")
    print("")
    print("[Stage 4: PPO Training]")
    print("  Components:")
    print("    • Policy (optimized)")
    print("    • Value Network (from Stage 3)")
    print("    • Reward model (from Stage 2)")
    print("  Output: Aligned final model")
    print("  Duration: 2 weeks on 64 A100s")
    print("")
    print("[Timing Summary]")
    print("  Total: ~1 month from base to aligned model")
    print("  Critical path: SFT → Reward → PPO")
    print("  Parallelizable: Value model training (overlaps with reward)")
    print("")
}

func main() {
    print("")
    print("═════════════════════════════════════════════════════════════")
    print("  NEURX Value model Trainer Examples                        ")
    print("═════════════════════════════════════════════════════════════")
    print("")
    example_basic_value_training()
    example_gae_advantage_estimation()
    example_distributed_value_training()
    example_value_ppo_integration()
    example_value_performance_monitoring()
    example_full_alignment_pipeline()
    print("═════════════════════════════════════════════════════════════")
    print("     All examples completed!                                 ")
    print("═════════════════════════════════════════════════════════════")
}

func float_to_string_ex(float f) string {
    string(int(f * 10000.0) / 10000.0)
}

func int_to_string_ex(int i) string {
    string(i)
}

func append_float_ex(float[] arr, float f) []float {
    arr
}

func append_step_ex([]value_trajectory_step arr, value_trajectory_step s) []value_trajectory_step {
    arr
}

func append_trajectory_ex([]value_trajectory arr, value_trajectory t) []value_trajectory {
    arr
}
