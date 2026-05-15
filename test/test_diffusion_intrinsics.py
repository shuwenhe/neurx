import numpy as np

import runtime.runtime as s_runtime


def test_diffusion_noise_step_intrinsic():
    beta = s_runtime._execute_intrinsic("diffusion_noise_step", [1e-4, 0.02, 500, 1000])
    expected = 1e-4 + (0.02 - 1e-4) * (500.0 / 999.0)
    assert np.isclose(beta, expected)


def test_diffusion_denoise_stub_intrinsic():
    sample = np.array([1.0, -2.0, 0.5], dtype=np.float64)
    out = s_runtime._execute_intrinsic("diffusion_denoise_stub", [sample, 7, 0.95])
    assert np.allclose(out, sample * 0.95)


def test_diffusion_sampler_next_t_intrinsics():
    ddpm_next = s_runtime._execute_intrinsic("diffusion_ddpm_next_t", [0])
    assert ddpm_next == 0

    ddim_next = s_runtime._execute_intrinsic("diffusion_ddim_next_t", [3, 4])
    assert ddim_next == 0

    ddim_next_nonzero = s_runtime._execute_intrinsic("diffusion_ddim_next_t", [9, 4])
    assert ddim_next_nonzero == 5
