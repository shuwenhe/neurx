from neurx.cuda.ops import add, mul, available


def is_available() -> bool:
	"""PyTorch-compatible alias for CUDA availability check."""
	return available()


__all__ = ["add", "mul", "available", "is_available"]
