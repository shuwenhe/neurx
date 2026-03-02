from __future__ import annotations


class Dataset:
    def __len__(self) -> int:
        raise NotImplementedError("Dataset.__len__ is not implemented")

    def __getitem__(self, index):
        raise NotImplementedError("Dataset.__getitem__ is not implemented")


class TensorDataset(Dataset):
    def __init__(self, *tensors):
        if not tensors:
            raise ValueError("TensorDataset requires at least one tensor")
        first_len = len(tensors[0])
        for t in tensors[1:]:
            if len(t) != first_len:
                raise ValueError("all tensors must share the same first dimension")
        self.tensors = tensors

    def __len__(self) -> int:
        return len(self.tensors[0])

    def __getitem__(self, index):
        if len(self.tensors) == 1:
            return self.tensors[0][index]
        return tuple(t[index] for t in self.tensors)

