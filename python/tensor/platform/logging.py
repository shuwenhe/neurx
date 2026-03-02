from __future__ import annotations

import logging
import threading

from tensor.platform.config import get_runtime_config

_LOCK = threading.Lock()
_CONFIGURED = False


def configure_logging(level: str | None = None) -> logging.Logger:
    global _CONFIGURED
    with _LOCK:
        logger = logging.getLogger("tensor")
        if not _CONFIGURED:
            handler = logging.StreamHandler()
            handler.setFormatter(
                logging.Formatter(
                    fmt="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
                    datefmt="%Y-%m-%d %H:%M:%S",
                )
            )
            logger.addHandler(handler)
            logger.propagate = False
            _CONFIGURED = True

        cfg = get_runtime_config()
        logger.setLevel(level or cfg.log_level)
        return logger


def get_logger(name: str | None = None) -> logging.Logger:
    base = configure_logging()
    if not name:
        return base
    return base.getChild(name)

