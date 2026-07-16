# Ascend AI Core kernels

Place CANN Ascend C/TBE implementations here. Required inference kernels are paged attention, fused RMSNorm-QKV-RoPE, SwiGLU, KV-cache scatter/gather and fused logits sampling. Kernel sources must be compiled with the matching CANN toolkit and exported through launchers compatible with `DeviceBatch`.
