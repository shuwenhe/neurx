import numpy as np

from tensor.optim.optimizer import Optimizer


class SGD(Optimizer):
    """Stochastic Gradient Descent optimizer.
    
    Args:
        params: Iterable of parameters to optimize
        lr: Learning rate (default: 1e-3)
        momentum: Momentum factor (default: 0)
        weight_decay: Weight decay (L2 penalty) (default: 0)
        dampening: Dampening for momentum (default: 0)
        nesterov: Enable Nesterov momentum (default: False)
    
    Example:
        >>> optimizer = SGD(model.parameters(), lr=0.01, momentum=0.9)
        >>> optimizer.zero_grad()
        >>> loss.backward()
        >>> optimizer.step()
    """
    
    def __init__(self, params, lr=1e-3, momentum=0, weight_decay=0, dampening=0, nesterov=False):
        super().__init__(params)
        self.lr = lr
        self.momentum = momentum
        self.weight_decay = weight_decay
        self.dampening = dampening
        self.nesterov = nesterov
        
        if nesterov and (momentum <= 0 or dampening != 0):
            raise ValueError("Nesterov momentum requires a momentum and zero dampening")
        
        # Initialize momentum buffers
        self.velocity = {id(p): np.zeros_like(p.data) for p in self.params} if momentum != 0 else {}
    
    def step(self):
        """Perform a single optimization step."""
        for p in self.params:
            if p.grad is None:
                continue
            
            grad = p.grad
            
            # Apply weight decay
            if self.weight_decay != 0:
                grad = grad + self.weight_decay * p.data
            
            # Apply momentum
            if self.momentum != 0:
                pid = id(p)
                if pid not in self.velocity:
                    self.velocity[pid] = np.zeros_like(p.data)
                
                v = self.velocity[pid]
                v = self.momentum * v + (1 - self.dampening) * grad
                self.velocity[pid] = v
                
                if self.nesterov:
                    grad = grad + self.momentum * v
                else:
                    grad = v
            
            # Update parameters
            p.data -= self.lr * grad
    
    def state_dict(self):
        """Return the state of the optimizer as a dict."""
        return {
            "lr": self.lr,
            "momentum": self.momentum,
            "weight_decay": self.weight_decay,
            "dampening": self.dampening,
            "nesterov": self.nesterov,
            "velocity": {i: self.velocity[id(p)].copy() for i, p in enumerate(self.params) if id(p) in self.velocity},
        }
    
    def load_state_dict(self, state):
        """Load the optimizer state."""
        self.lr = state.get("lr", self.lr)
        self.momentum = state.get("momentum", self.momentum)
        self.weight_decay = state.get("weight_decay", self.weight_decay)
        self.dampening = state.get("dampening", self.dampening)
        self.nesterov = state.get("nesterov", self.nesterov)
        
        velocity_dict = state.get("velocity", {})
        for i, p in enumerate(self.params):
            if i in velocity_dict:
                self.velocity[id(p)] = velocity_dict[i].copy()


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
