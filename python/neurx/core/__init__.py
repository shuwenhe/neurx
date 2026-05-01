from neurx.core.neurx import (
    Tensor,
    bmm,
    cat,
    chunk,
    eig,
    meshgrid,
    inverse,
    matmul,
    mm,
    split,
    stack,
    svd,
    no_grad,
    enable_grad,
    set_grad_enabled,
    is_grad_enabled,
    where,
    clamp,
    clip,
    sign,
    flip,
    roll,
    tile,
    diag,
    softmax,
    log_softmax,
    take_along_dim,
)

# Lazy import tensor creation functions to avoid circular imports
def __getattr__(name):
    """Lazy loading of tensor creation/manipulation functions"""
    if name in ('zeros', 'ones', 'full', 'zeros_like', 'ones_like', 'full_like',
                'eye', 'arange', 'linspace', 'logspace', 'rand', 'randn',
                'randint', 'randperm', 'normal', 'uniform', 'empty', 'empty_like',
                'rand_like', 'randn_like'):
        from neurx.core.tensor_creation import (
            zeros, ones, full, zeros_like, ones_like, full_like, eye, arange,
            linspace, logspace, rand, randn, randint, randperm, normal, uniform,
            empty, empty_like, rand_like, randn_like
        )
        return locals()[name]
    
    elif name in ('index_select', 'masked_select', 'masked_fill', 'masked_scatter',
                  'nonzero', 'repeat_interleave'):
        from neurx.core.tensor_indexing import (
            index_select, masked_select, masked_fill, masked_scatter,
            nonzero, repeat_interleave
        )
        return locals()[name]
    
    elif name in ('sort', 'argsort', 'topk', 'unique', 'median', 'mode',
                  'quantile', 'cumsum', 'cumprod', 'prod'):
        from neurx.core.tensor_stats import (
            sort, argsort, topk, unique, median, mode, quantile,
            cumsum, cumprod, prod
        )
        return locals()[name]
    
    elif name in ('matrix_rank', 'inv', 'det', 'eig', 'eigh', 'svd', 'qr',
                  'cholesky', 'solve', 'lstsq', 'cross', 'outer', 'inner',
                  'matrix_power'):
        from neurx.core.linalg import (
            matrix_rank, inv, det, eig, eigh, svd, qr, cholesky, solve,
            lstsq, cross, outer, inner, matrix_power
        )
        return locals()[name]
    
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")

# For backward compatibility, also try to import at module level
# but wrapped in try-except to handle circular imports
try:
    from neurx.core.tensor_creation import (
        zeros,
        ones,
        full,
        zeros_like,
        ones_like,
        full_like,
        eye,
        arange,
        linspace,
        logspace,
        rand,
        randn,
        randint,
        randperm,
        normal,
        uniform,
        empty,
        empty_like,
        rand_like,
        randn_like,
    )
except (ImportError, NameError):
    pass

# Import tensor indexing functions
try:
    from neurx.core.tensor_indexing import (
        index_select,
        masked_select,
        masked_fill,
        masked_scatter,
        nonzero,
        repeat_interleave,
    )
except (ImportError, NameError):
    pass

# Import statistical functions
try:
    from neurx.core.tensor_stats import (
        sort,
        argsort,
        topk,
        unique,
        median,
        mode,
        quantile,
        cumsum,
        cumprod,
        prod,
    )
except (ImportError, NameError):
    pass

__all__ = [
    # Core tensor
    "Tensor",
    
    # Gradient control
    "no_grad",
    "enable_grad",
    "set_grad_enabled",
    "is_grad_enabled",
    
    # Tensor creation
    "zeros",
    "ones",
    "full",
    "zeros_like",
    "ones_like",
    "full_like",
    "eye",
    "arange",
    "linspace",
    "logspace",
    "rand",
    "randn",
    "randint",
    "randperm",
    "normal",
    "uniform",
    "empty",
    "empty_like",
    "rand_like",
    "randn_like",
    
    # Tensor operations
    "where",
    "clamp",
    "clip",
    "sign",
    "flip",
    "roll",
    "tile",
    "diag",
    "softmax",
    "log_softmax",
    "take_along_dim",
    "meshgrid",
    "cat",
    "stack",
    "split",
    "chunk",
    "index_select",
    "masked_select",
    "masked_fill",
    "masked_scatter",
    "nonzero",
    "repeat_interleave",
    
    # Linear algebra
    "matmul",
    "mm",
    "bmm",
    "inverse",
    "svd",
    "eig",
    
    # Statistics
    "sort",
    "argsort",
    "topk",
    "unique",
    "median",
    "mode",
    "quantile",
    "cumsum",
    "cumprod",
    "prod",
]
