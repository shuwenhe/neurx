import numpy as np


class AdamW:
    def __init__(self, params, lr=1e-3, betas=(0.9, 0.999), eps=1e-8, weight_decay=0.01):
        self.params = list(params)
        self.lr = lr
        self.beta1, self.beta2 = betas
        self.eps = eps
        self.weight_decay = weight_decay
        self.step_count = 0
        self.m = {id(p): np.zeros_like(p.data) for p in self.params}
        self.v = {id(p): np.zeros_like(p.data) for p in self.params}

    def zero_grad(self):
        for p in self.params:
            p.zero_grad()

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
