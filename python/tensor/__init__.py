from tensor.tensor import Tensor
from tensor.version import __version__
from tensor import compile, data, distributed, nn, optim
from tensor.losses import cross_entropy, cross_entropy_loss
from tensor.platform import doctor, format_doctor_report, get_runtime_config, runtime_info

__all__ = [
    "__version__",
    "Tensor",
    "data",
    "distributed",
    "compile",
    "nn",
    "optim",
    "cross_entropy",
    "cross_entropy_loss",
    "get_runtime_config",
    "runtime_info",
    "doctor",
    "format_doctor_report",
]
