class Optimizer:
    def __init__(self, params):
        self.params = list(params)

    def zero_grad(self):
        for p in self.params:
            p.zero_grad()

    def step(self):
        raise NotImplementedError("Optimizer.step is not implemented")

    def state_dict(self):
        return {}

    def load_state_dict(self, state):
        return None
