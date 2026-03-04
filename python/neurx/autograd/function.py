class Function:
    @staticmethod
    def forward(*args, **kwargs):
        raise NotImplementedError("Function.forward is not implemented")

    @staticmethod
    def backward(*args, **kwargs):
        raise NotImplementedError("Function.backward is not implemented")

    @classmethod
    def apply(cls, *args, **kwargs):
        return cls.forward(*args, **kwargs)
