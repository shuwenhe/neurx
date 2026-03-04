class Optimizer:
    def __init__(self, params, defaults=None):
        self.defaults = dict(defaults or {})
        self.param_groups = []
        self.params = []
        self._param_index = {}

        param_groups = list(params)
        if len(param_groups) == 0:
            raise ValueError("optimizer got an empty parameter list")

        if isinstance(param_groups[0], dict):
            for group in param_groups:
                self.add_param_group(group)
        else:
            self.add_param_group({"params": param_groups})

    def add_param_group(self, param_group):
        if not isinstance(param_group, dict):
            raise TypeError("param_group must be a dict")
        if "params" not in param_group:
            raise ValueError("param_group must contain key 'params'")

        group_params = list(param_group["params"])
        if len(group_params) == 0:
            raise ValueError("optimizer param group has no parameters")

        group = dict(self.defaults)
        for key, value in param_group.items():
            if key != "params":
                group[key] = value
        group["params"] = group_params

        self.param_groups.append(group)
        for p in group_params:
            pid = id(p)
            if pid not in self._param_index:
                self._param_index[pid] = len(self.params)
                self.params.append(p)

    def _serialize_param_groups(self):
        serialized = []
        for group in self.param_groups:
            item = {k: v for k, v in group.items() if k != "params"}
            item["params"] = [self._param_index[id(p)] for p in group["params"]]
            serialized.append(item)
        return serialized

    def _load_param_groups(self, param_groups_state):
        if not isinstance(param_groups_state, list):
            return
        if len(param_groups_state) != len(self.param_groups):
            raise ValueError(
                f"loaded state has {len(param_groups_state)} param_groups, expected {len(self.param_groups)}"
            )

        for dst, src in zip(self.param_groups, param_groups_state):
            for key, value in src.items():
                if key == "params":
                    continue
                dst[key] = value

        if self.param_groups and "lr" in self.param_groups[0]:
            self.lr = self.param_groups[0]["lr"]

    def zero_grad(self):
        for p in self.params:
            p.zero_grad()

    def step(self):
        raise NotImplementedError("Optimizer.step is not implemented")

    def state_dict(self):
        return {
            "param_groups": self._serialize_param_groups(),
        }

    def load_state_dict(self, state):
        if not isinstance(state, dict):
            raise TypeError("optimizer state must be a dict")
        self._load_param_groups(state.get("param_groups", []))
        return None
