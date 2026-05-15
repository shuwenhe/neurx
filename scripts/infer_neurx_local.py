#!/usr/bin/env python3
"""
示例：使用 NeurX 本地推理引擎加载本地模型检查点并执行一次前向推理

用法示例：
  python scripts/infer_neurx_local.py \
    --checkpoint /path/to/checkpoint.pt \
    --model example.mnist_classifier:ClassificationModel \
    --input-shape 784 --batch-size 4

如果模型定义在单个文件中（未安装为包），使用 --model-file 指定路径：
  python scripts/infer_neurx_local.py --checkpoint ./model.pt --model-file /path/to/model.py --model-class ClassificationModel
"""

import argparse
import importlib
import importlib.util
import sys
from pathlib import Path

def load_model_from_module(spec: str):
    """Load model class from a module string 'module.sub:ClassName'"""
    if ':' not in spec:
        raise ValueError("--model must be in format module.path:ClassName")
    module_path, cls_name = spec.split(':', 1)
    mod = importlib.import_module(module_path)
    cls = getattr(mod, cls_name)
    return cls

def load_model_from_file(path: str, class_name: str):
    """Dynamically import a python file and return the class by name."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Model file not found: {path}")
    spec = importlib.util.spec_from_file_location(p.stem, str(p))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[p.stem] = mod
    spec.loader.exec_module(mod)
    cls = getattr(mod, class_name)
    return cls


def main():
    parser = argparse.ArgumentParser(description="Infer with local NeurX checkpoint")
    parser.add_argument('--checkpoint', required=True, help='Path to checkpoint file')
    parser.add_argument('--model', help='Model spec in module:Class format (e.g. example.mnist_classifier:ClassificationModel)')
    parser.add_argument('--model-file', help='Path to a python file containing the model class')
    parser.add_argument('--model-class', help='Class name when using --model-file')
    parser.add_argument('--device', default='cpu', choices=['cpu','cuda'], help='Device to run on')
    parser.add_argument('--input-shape', required=True, help='Input shape (for single sample) as comma-separated dims or single int for flattened vector')
    parser.add_argument('--batch-size', type=int, default=1)
    args = parser.parse_args()

    import neurx
    from neurx import Tensor
    from neurx.serialization import load_checkpoint

    # Resolve model class
    if args.model:
        ModelClass = load_model_from_module(args.model)
    elif args.model_file and args.model_class:
        ModelClass = load_model_from_file(args.model_file, args.model_class)
    else:
        raise ValueError('Provide either --model or both --model-file and --model-class')

    print(f"Instantiating model {ModelClass.__name__}()")
    model = ModelClass()

    # Load checkpoint
    ckpt_path = Path(args.checkpoint)
    if not ckpt_path.exists():
        raise FileNotFoundError(f"Checkpoint not found: {ckpt_path}")

    print(f"Loading checkpoint from {ckpt_path}")
    loaded = load_checkpoint(str(ckpt_path), model=model)
    print("Checkpoint loaded. Training metadata:", loaded.get('training') if isinstance(loaded, dict) else None)

    # Prepare input
    # Support single int (flattened) or comma-separated dims
    shape_str = args.input_shape
    if ',' in shape_str:
        dims = [int(x) for x in shape_str.split(',')]
    else:
        dims = [int(shape_str)]

    batch = args.batch_size
    input_shape = [batch] + dims
    x = neurx.randn(*input_shape)

    model.eval()
    with neurx.no_grad():
        out = model(x)

    try:
        # Print basic info
        print(f"Input shape: {x.shape}, Output shape: {out.shape}")
        print("Output sample:", out.data.flatten()[:8])
    except Exception:
        print("Inference completed.")


if __name__ == '__main__':
    main()
