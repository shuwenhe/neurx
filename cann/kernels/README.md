# Ascend AI Core kernels

The initial 310P path uses supported ATB operations from
`operators/atb_310p_plugin.cpp`. Add Ascend C/TBE kernels here only for an
operation that ATB cannot provide or after profiling proves a fusion is needed.
Likely candidates are fused RMSNorm-QKV-RoPE and device-side logits sampling.
