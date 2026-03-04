"""
本阶段测试：Module.to(non_blocking/copy)参数兼容 + checkpoint shape/dtype mismatch报告
"""

import pytest
import numpy as np
import tempfile
import os
from neurx.nn.modules import Module, Linear, Parameter
from neurx.neurx import Tensor
from neurx.serialization.checkpoint import save_checkpoint, load_checkpoint


class SimpleModel(Module):
    """简单测试模型"""
    def __init__(self, in_features=10, out_features=5):
        super().__init__()
        self.linear = Linear(in_features, out_features)
        self.register_buffer("running_mean", np.zeros(out_features))

    def forward(self, x):
        return self.linear(x)


def test_module_to_with_non_blocking_parameter():
    """验证Module.to()接受non_blocking参数（兼容PyTorch）"""
    model = SimpleModel()
    
    # non_blocking 参数应该被接受但在NumPy中无效
    result = model.to(device='cpu', non_blocking=True)
    assert result is model  # 应该返回自身
    
    result = model.to(device='cpu', non_blocking=False)
    assert result is model
    
    # 通过non_blocking=True过的模型应该正常工作
    x = Tensor(np.random.randn(2, 10))
    output = model(x)
    assert output.shape == (2, 5)


def test_module_to_with_copy_parameter():
    """验证Module.to()接受copy参数（兼容PyTorch）"""
    model = SimpleModel()
    
    # copy 参数应该被接受
    result = model.to(device='cpu', copy=True)
    assert result is model
    
    result = model.to(device='cpu', copy=False)
    assert result is model
    
    # 验证模型仍然可用
    x = Tensor(np.random.randn(2, 10))
    output = model(x)
    assert output.shape == (2, 5)


def test_module_load_state_dict_shape_mismatch_detection():
    """验证load_state_dict()检测shape不匹配"""
    model = SimpleModel(in_features=10, out_features=5)
    
    # 获取正常的state_dict
    state = model.state_dict()
    
    # 修改state中的某个参数shape
    original_weight = state['linear.weight']
    state['linear.weight'] = np.random.randn(10, 3)  # 改为(10,3)，应该是(10,5)
    
    # 以非strict模式加载，应该返回shape_mismatch信息
    incompatible = model.load_state_dict(state, strict=False)
    
    assert hasattr(incompatible, 'shape_mismatch')
    assert len(incompatible.shape_mismatch) > 0
    
    # 查找weight参数的mismatch记录
    weight_mismatch = [m for m in incompatible.shape_mismatch if m['name'] == 'linear.weight']
    assert len(weight_mismatch) == 1
    assert weight_mismatch[0]['expected'] == (10, 5)
    assert weight_mismatch[0]['got'] == (10, 3)


def test_module_load_state_dict_dtype_mismatch_detection():
    """验证load_state_dict()检测dtype不匹配"""
    model = SimpleModel()
    state = model.state_dict()
    
    # 修改state中参数的dtype
    state['linear.weight'] = state['linear.weight'].astype(np.float16)
    
    # 非strict模式加载
    incompatible = model.load_state_dict(state, strict=False)
    
    assert hasattr(incompatible, 'dtype_mismatch')
    assert len(incompatible.dtype_mismatch) > 0
    
    # 查找weight参数的dtype mismatch
    weight_dtype = [m for m in incompatible.dtype_mismatch if m['name'] == 'linear.weight']
    assert len(weight_dtype) == 1
    # 当前模型应该是float64，加载的是float16
    assert 'float16' in weight_dtype[0]['got']


def test_module_load_state_dict_strict_with_shape_mismatch_raises():
    """验证strict=True模式下shape mismatch会raise RuntimeError"""
    model = SimpleModel(in_features=10, out_features=5)
    state = model.state_dict()
    
    # 修改shape
    state['linear.weight'] = np.random.randn(10, 3)
    
    # strict=True应该raise
    with pytest.raises(RuntimeError) as exc_info:
        model.load_state_dict(state, strict=True)
    
    error_msg = str(exc_info.value)
    assert 'shape_mismatch' in error_msg
    assert 'SimpleModel' in error_msg


def test_checkpoint_load_report_with_shape_dtype_mismatch():
    """验证checkpoint加载报告包含shape/dtype mismatch信息"""
    model = SimpleModel(in_features=10, out_features=5)
    
    with tempfile.TemporaryDirectory() as tmpdir:
        ckpt_path = os.path.join(tmpdir, 'test.ckpt')
        
        # 保存checkpoint
        save_checkpoint(ckpt_path, model=model)
        
        # 创建新的模型并修改其结构（改为不同的input size）
        model2 = SimpleModel(in_features=15, out_features=5)  # 不同输入维度
        
        # 加载checkpoint，应该检测到shape mismatch
        ckpt = load_checkpoint(ckpt_path, model=model2, strict=False)
        
        # 检查load_report结构
        assert 'load_report' in ckpt
        report = ckpt['load_report']
        
        assert 'model' in report
        model_report = report['model']
        
        # 应该包含shape_mismatch字段
        assert 'shape_mismatch' in model_report
        assert len(model_report['shape_mismatch']) > 0
        
        # 应该显示哪个参数shape不匹配
        shape_mismatch = model_report['shape_mismatch']
        weight_mismatch = [m for m in shape_mismatch if 'weight' in m['name']]
        assert len(weight_mismatch) > 0
        print(f"Shape mismatch detected: {weight_mismatch}")


def test_checkpoint_load_report_loaded_flag():
    """验证checkpoint report中的loaded标志"""
    model = SimpleModel()
    
    with tempfile.TemporaryDirectory() as tmpdir:
        ckpt_path = os.path.join(tmpdir, 'test.ckpt')
        
        # 保存checkpoint
        save_checkpoint(ckpt_path, model=model)
        
        # 加载checkpoint
        ckpt = load_checkpoint(ckpt_path, model=model, strict=False)
        
        # 检查load_report中的loaded标志
        assert 'load_report' in ckpt
        assert ckpt['load_report']['model']['loaded'] is True
        
        # no shape/dtype mismatch时这些列表应该为空
        assert len(ckpt['load_report']['model']['shape_mismatch']) == 0
        assert len(ckpt['load_report']['model']['dtype_mismatch']) == 0


def test_checkpoint_incompatible_keys_structure():
    """验证返回的IncompatibleKeys包含所有4个字段"""
    model = SimpleModel()
    state = {'extra_key': np.array([1, 2, 3])}  # 意外的key
    
    incompatible = model.load_state_dict(state, strict=False)
    
    # 应该有所有4个字段
    assert hasattr(incompatible, 'missing_keys')
    assert hasattr(incompatible, 'unexpected_keys')
    assert hasattr(incompatible, 'shape_mismatch')
    assert hasattr(incompatible, 'dtype_mismatch')
    
    # unexpected_keys应该被捕获
    assert len(incompatible.unexpected_keys) > 0
    assert 'extra_key' in incompatible.unexpected_keys


def test_module_to_combined_device_and_dtype_with_kwargs():
    """验证Module.to()支持device和dtype同时转换，并接受额外的兼容参数"""
    model = SimpleModel()
    
    # 同时指定device和dtype，加上兼容参数
    result = model.to(device='cpu', dtype=np.float32, non_blocking=False, copy=True)
    
    # 验证参数被转换
    for param in model.parameters():
        assert param.dtype == np.float32
    
    # 验证buffer也被转换
    assert model.linear.weight.dtype == np.float32


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
