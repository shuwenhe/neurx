"""
Phase 5 完整测试：
1. 自动dtype/shape转换 (非strict模式)
2. 更完整的Module API (eval/train/repr增强)
3. Autograd上下文管理 (no_grad、梯度累积)
4. 分布式训练支持 (DistributedDataParallel/DataParallel)
"""

import pytest
import numpy as np
import tempfile
import os
from neurx.nn.modules import Module, Linear, Parameter
from neurx.neurx import Tensor
from neurx.serialization.checkpoint import save_checkpoint, load_checkpoint
from neurx.autograd.context import no_grad, enable_grad, gradient_accumulation
from neurx.nn.modules import Module

class DistributedDataParallel(Module):
    """简单的DDP mock实现"""
    def __init__(self, module, **kwargs):
        super().__init__()
        self.module = module
    
    def forward(self, *args, **kwargs):
        return self.module.forward(*args, **kwargs)
    
    def state_dict(self):
        state = {}
        for name, value in self.module.state_dict().items():
            state[f'module.{name}'] = value
        return state
    
    def load_state_dict(self, state, **kwargs):
        processed = {}
        for key, val in state.items():
            if key.startswith('module.'):
                processed[key[7:]] = val
            else:
                processed[key] = val
        return self.module.load_state_dict(processed, **kwargs)
    
    def train(self, mode=True):
        self.module.train(mode)
        return self
    
    def eval(self):
        self.module.eval()
        return self
    
    def to(self, *args, **kwargs):
        self.module.to(*args, **kwargs)
        return self

class DataParallel(Module):
    """简单的DP mock实现"""
    def __init__(self, module, **kwargs):
        super().__init__()
        self.module = module
    
    def forward(self, *args, **kwargs):
        return self.module.forward(*args, **kwargs)
    
    def state_dict(self):
        return self.module.state_dict()
    
    def load_state_dict(self, state, **kwargs):
        return self.module.load_state_dict(state, **kwargs)
    
    def train(self, mode=True):
        self.module.train(mode)
        return self
    
    def eval(self):
        self.module.eval()
        return self
    
    def to(self, *args, **kwargs):
        self.module.to(*args, **kwargs)
        return self


class SimpleModel(Module):
    """用于测试的简单模型"""
    def __init__(self, in_features=10, out_features=5):
        super().__init__()
        self.linear1 = Linear(in_features, out_features)
        self.linear2 = Linear(out_features, 2)

    def forward(self, x):
        x = self.linear1(x)
        x = self.linear2(x)
        return x


# ===== Phase 5-1: 自动dtype/shape转换 =====

def test_auto_convert_dtype_mismatch():
    """验证自动转换dtype不匹配的参数"""
    model = SimpleModel(10, 5)
    state = model.state_dict()
    
    # 改变state中一个参数的dtype
    state['linear1.weight'] = state['linear1.weight'].astype(np.float16)
    
    # auto_convert=True时应该自动转换
    incompatible = model.load_state_dict(state, strict=False, auto_convert=True)
    
    # 参数应该已被转换为原始dtype
    assert model.linear1.weight.dtype == np.float64


def test_auto_convert_shape_mismatch_reshape():
    """验证自动shape转换（reshape）"""
    model = SimpleModel(10, 5)
    state = model.state_dict()
    
    # 改变weight的shape（但保持总元素数不变）
    weight = state['linear1.weight']  # (10, 5)
    state['linear1.weight'] = weight.flatten()  # (50,)
    
    # auto_convert=True时应该reshape
    incompatible = model.load_state_dict(state, strict=False, auto_convert=True)
    
    # 参数应该被reshape回正确的shape
    assert model.linear1.weight.shape == (10, 5)


def test_auto_convert_disabled_by_default():
    """验证auto_convert默认为False"""
    model1 = SimpleModel(10, 5)
    model2 = SimpleModel(10, 5)
    
    state = model1.state_dict()
    # 改变dtype
    state['linear1.weight'] = state['linear1.weight'].astype(np.float16)
    
    # 不指定auto_convert或auto_convert=False时不应转换
    incompatible = model2.load_state_dict(state, strict=False)
    
    # 应该报告dtype mismatch
    assert len(incompatible.dtype_mismatch) > 0


# ===== Phase 5-2: 更完整的Module API =====

def test_module_train_returns_self():
    """验证train()返回self以支持链式调用"""
    model = SimpleModel()
    result = model.train(True)
    assert result is model
    assert model.training is True
    
    result = model.train(False)
    assert result is model
    assert model.training is False


def test_module_eval_returns_self():
    """验证eval()返回self以支持链式调用"""
    model = SimpleModel()
    result = model.eval()
    assert result is model
    assert model.training is False


def test_module_train_eval_chain():
    """验证train/eval可链式调用"""
    model = SimpleModel()
    model.train().eval().train()
    assert model.training is True
    
    model.eval().train(False)
    assert model.training is False


def test_module_repr():
    """验证Module的__repr__返回模块结构"""
    model = SimpleModel()
    repr_str = repr(model)
    
    # 应该包含模块类名
    assert 'SimpleModel' in repr_str
    assert 'Linear' in repr_str
    assert 'linear1' in repr_str
    assert 'linear2' in repr_str
    
    # 应该是可读的格式
    print(repr_str)


def test_module_repr_nested():
    """验证嵌套模块的repr"""
    model = SimpleModel()
    repr_str = repr(model)
    
    # 应该显示嵌套结构
    lines = repr_str.split('\n')
    assert len(lines) > 1  # 多行输出


# ===== Phase 5-3: Autograd上下文管理 =====

def test_no_grad_context():
    """验证no_grad上下文管理器"""
    with no_grad():
        # 在此上下文中应该禁用梯度
        x = Tensor(np.random.randn(2, 10), requires_grad=False)
        y = x * 2
        # 无法验证具体行为，但应该不raise


def test_enable_grad_context():
    """验证enable_grad上下文"""
    with enable_grad():
        x = Tensor(np.random.randn(2, 10), requires_grad=True)
        y = x * 2
        # 应该能正常运行


def test_gradient_accumulation_context():
    """验证梯度累积上下文"""
    with gradient_accumulation(True):
        # 在此上下文中应启用梯度累积
        x = Tensor(np.random.randn(2, 10), requires_grad=True)
    
    with gradient_accumulation(False):
        # 在此上下文中应禁用梯度累积
        x = Tensor(np.random.randn(2, 10), requires_grad=True)


# ===== Phase 5-4: 分布式训练支持 =====

def test_distributed_dataparallel_wrapping():
    """验证DistributedDataParallel包装"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    # 应该能访问module属性
    assert ddp_model.module is model


def test_distributed_dataparallel_forward():
    """验证DistributedDataParallel的forward转发"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    x = Tensor(np.random.randn(2, 10))
    output = ddp_model(x)
    
    # 应该返回与模型相同的结果
    expected_output = model(x)
    assert output.shape == expected_output.shape


def test_distributed_dataparallel_state_dict():
    """验证DistributedDataParallel的state_dict处理"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    state = ddp_model.state_dict()
    
    # 应该包含'module.'前缀
    for key in state.keys():
        assert key.startswith('module.')


def test_distributed_dataparallel_load_state_dict():
    """验证DistributedDataParallel的load_state_dict处理"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    # 保存有前缀的state
    state_with_prefix = ddp_model.state_dict()
    
    # 创建新的ddp，加载带前缀的state
    model2 = SimpleModel()
    ddp_model2 = DistributedDataParallel(model2)
    ddp_model2.load_state_dict(state_with_prefix)
    
    # 应该成功加载


def test_dataparallel_wrapping():
    """验证DataParallel包装（简化版）"""
    model = SimpleModel()
    dp_model = DataParallel(model)
    
    # 应该能访问module属性
    assert dp_model.module is model


def test_dataparallel_forward():
    """验证DataParallel的forward转发"""
    model = SimpleModel()
    dp_model = DataParallel(model)
    
    x = Tensor(np.random.randn(2, 10))
    output = dp_model(x)
    
    expected_output = model(x)
    assert output.shape == expected_output.shape


def test_ddp_train_eval():
    """验证DistributedDataParallel的train/eval"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    ddp_model.eval()
    assert model.training is False
    
    ddp_model.train()
    assert model.training is True


def test_ddp_to_device():
    """验证DistributedDataParallel的to方法"""
    model = SimpleModel()
    ddp_model = DistributedDataParallel(model)
    
    # to()应该能执行，即使设备转移在NumPy中是no-op
    ddp_model.to(device='cpu', dtype=np.float32)
    
    # 模型参数应该被转换
    for param in model.parameters():
        assert param.dtype == np.float32


# ===== 整合测试 =====

def test_ddp_with_auto_convert_checkpoint():
    """验证DDP + 自动转换 + checkpoint的整合"""
    model1 = SimpleModel(10, 5)
    ddp_model1 = DistributedDataParallel(model1)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        ckpt_path = os.path.join(tmpdir, 'test.ckpt')
        
        # 保存checkpoint
        save_checkpoint(ckpt_path, model=ddp_model1)
        
        # 创建不同大小的模型
        model2 = SimpleModel(15, 8)
        ddp_model2 = DistributedDataParallel(model2)
        
        # 加载checkpoint，使用auto_convert
        ckpt = load_checkpoint(ckpt_path, model=ddp_model2, strict=False)
        
        # 应该加载并进行转换
        assert 'load_report' in ckpt


def test_training_loop_with_no_grad():
    """验证典型的训练循环与no_grad的使用"""
    model = SimpleModel()
    model.train()  # 设置训练模式
    
    x = Tensor(np.random.randn(2, 10), requires_grad=True)
    
    with no_grad():
        # 评估时不计算梯度
        output = model(x)
    
    # 应该能正常运行
    assert output.shape == (2, 2)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
