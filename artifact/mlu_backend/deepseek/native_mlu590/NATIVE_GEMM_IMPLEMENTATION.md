# Native GEMM implementation

**BLOCKED before implementation.** The target is a real MLU590-M9 path through Device ABI v1 with S owning dispatch and resource lifecycle and typed native code owning vendor pointers and calls. Neither a compatible SDK nor usable devices were available. No vendor symbol was added by guesswork, and this turn made no runtime source changes.

The requested first mode is stored BF16 inputs, FP32 accumulation and FP32 output. The second mode substitutes FP16 inputs. Each mode needs real MLU execution for the five square sizes, rectangular matrices and padded leading dimensions. Padded strides require explicit support in the verified vendor descriptor and v1 operation contract. Current preparation describes packed layouts only. GEMM acceptance requires launch, synchronization and real output transfer. DeepSeek operators remain gated on that acceptance.
