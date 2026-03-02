import pickle

from tensor.serialization.checkpoint import load_checkpoint, save_checkpoint


def save(obj, path):
    with open(path, "wb") as f:
        pickle.dump(obj, f)


def load(path):
    with open(path, "rb") as f:
        return pickle.load(f)


__all__ = [
    "save",
    "load",
    "save_checkpoint",
    "load_checkpoint",
]
