from __future__ import annotations


class Function:
    """Minimal autograd Function placeholder."""

    @staticmethod
    def forward(*args, **kwargs):
        del args, kwargs

    @staticmethod
    def backward(*args, **kwargs):
        del args, kwargs

    @staticmethod
    def apply(*args, **kwargs):
        del args, kwargs


__all__ = ["Function"]
