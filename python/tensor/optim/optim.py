import numpy as np

from tensor.optim.optimizer import Optimizer


class AdamW(Optimizer):
    def __init__(self, params, lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=0.01):
        super().__init__(params)
        self.lr = lr
        self.beta1, self.beta2 = betas
        self.eps = eps
        self.weight_decay = weight_decay
        self.step_count = 0
        self.m = {id(p): np.zeros_like(p.data) for p in self.params}
        self.v = {id(p): np.zeros_like(p.data) for p in self.params}

    def step(self):
        self.step_count += 1
        for p in self.params:
            if p.grad is None:
                continue
            g = p.grad
            if self.weight_decay != 0:
                g = g + self.weight_decay * p.data

            pid = id(p)
            self.m[pid] = self.beta1 * self.m[pid] + (1 - self.beta1) * g
            self.v[pid] = self.beta2 * self.v[pid] + (1 - self.beta2) * (g * g)

            m_hat = self.m[pid] / (1 - self.beta1 ** self.step_count)
            v_hat = self.v[pid] / (1 - self.beta2 ** self.step_count)

            p.data -= self.lr * m_hat / (np.sqrt(v_hat) + self.eps)

    def state_dict(self):
        return {
            "lr": self.lr,
            "betas": (self.beta1, self.beta2),
            "eps": self.eps,
            "weight_decay": self.weight_decay,
            "step_count": self.step_count,
            "m": [self.m[id(p)].copy() for p in self.params],
            "v": [self.v[id(p)].copy() for p in self.params],
        }

    def load_state_dict(self, state):
        self.lr = state.get("lr", self.lr)
        betas = state.get("betas", (self.beta1, self.beta2))
        self.beta1, self.beta2 = betas
        self.eps = state.get("eps", self.eps)
        self.weight_decay = state.get("weight_decay", self.weight_decay)
        self.step_count = state.get("step_count", self.step_count)
        m_list = state.get("m", [])
        v_list = state.get("v", [])
        if m_list and len(m_list) == len(self.params):
            self.m = {id(p): m_list[i].copy() for i, p in enumerate(self.params)}
        if v_list and len(v_list) == len(self.params):
            self.v = {id(p): v_list[i].copy() for i, p in enumerate(self.params)}


def clip_grad_norm(params, max_norm, eps=1e-6):
    if max_norm is None or max_norm <= 0:
        return 0.0
    total_norm_sq = 0.0
    for p in params:
        if p.grad is None:
            continue
        total_norm_sq += float((p.grad ** 2).sum())
    total_norm = total_norm_sq ** 0.5
    clip_coef = max_norm / (total_norm + eps)
    if clip_coef < 1.0:
        for p in params:
            if p.grad is not None:
                p.grad *= clip_coef
    return total_norm
