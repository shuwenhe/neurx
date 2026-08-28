package neurx.diffusion.model
use neurx.ops
struct denoiser_state {
    string name
    int channels
    int hidden_dim
    bool conditioned
}
func new_denoiser_state(string name, int channels, int hidden_dim, bool conditioned) denoiser_state {
    denoiser_state {
        name: name,
        channels: channels,
        hidden_dim: hidden_dim,
        conditioned: conditioned,
    }
}
func denoiser_forward_stub(denoiser_state model, float[] noisy_sample, int t) float[] {
    float scale = 1.0
    if model.conditioned {
        scale = 0.95
    }
    neurx.ops.diffusion_denoise_stub(noisy_sample, t, scale)
}
func denoiser_state_dict(denoiser_state state) denoiser_state {
    state
}
func denoiser_load_state_dict(denoiser_state state, denoiser_state other) denoiser_state {
    other
}
