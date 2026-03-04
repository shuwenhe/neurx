class TensorError(Exception):
    """Base exception for neurx platform errors."""


class ConfigurationError(TensorError):
    """Raised when runtime configuration is invalid."""


class BackendNotAvailableError(TensorError):
    """Raised when a required backend (e.g. CUDA) is unavailable."""


class RuntimeValidationError(TensorError):
    """Raised when runtime health checks fail."""

