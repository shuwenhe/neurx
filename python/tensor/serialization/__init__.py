import pickle

from tensor.serialization.checkpoint import load_checkpoint, save_checkpoint
from tensor.serialization.enhanced import (
    ModelCheckpoint,
    save_tensor_dict,
    load_tensor_dict,
    merge_state_dicts,
    extract_state_dict_subset,
)


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
    "ModelCheckpoint",
    "save_tensor_dict",
    "load_tensor_dict",
    "merge_state_dicts",
    "extract_state_dict_subset",
]
