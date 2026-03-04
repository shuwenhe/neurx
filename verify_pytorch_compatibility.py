#!/usr/bin/env python3
"""
NeurX PyTorch 兼容性 - 快速验证脚本

用法:
    python verify_pytorch_compatibility.py
    python verify_pytorch_compatibility.py --phase 5
    python verify_pytorch_compatibility.py --all
"""

import subprocess
import sys
from pathlib import Path

def run_command(cmd, description):
    """运行命令并报告结果"""
    print(f"\n{'='*60}")
    print(f"🧪 {description}")
    print(f"{'='*60}")
    print(f"$ {cmd}")
    print()
    
    result = subprocess.run(cmd, shell=True)
    return result.returncode == 0

def main():
    project_root = Path(__file__).parent
    test_dir = project_root / "tests"
    
    # 获取命令行参数
    phase = None
    if len(sys.argv) > 1:
        if sys.argv[1] == "--all":
            phase = "all"
        elif sys.argv[1] == "--phase" and len(sys.argv) > 2:
            phase = sys.argv[2]
    
    print("\n" + "="*60)
    print("🚀 NeurX PyTorch 兼容性验证")
    print("="*60)
    
    results = {}
    
    if phase is None:
        # 默认运行所有 Phase
        phases = ["1", "2", "3", "4", "5"]
    elif phase == "all":
        phases = ["1", "2", "3", "4", "5", "all"]
    else:
        phases = [phase]
    
    for p in phases:
        if p == "all":
            description = "运行所有 Phase (1-5) 的测试"
            cmd = f"cd {project_root} && python -m pytest tests/test_pytorch_parity_phase[1-5].py -v --tb=short"
        else:
            description = f"运行 Phase {p} 的测试"
            cmd = f"cd {project_root} && python -m pytest tests/test_pytorch_parity_phase{p}.py -v --tb=short"
        
        success = run_command(cmd, description)
        results[f"Phase {p}"] = "✅ PASS" if success else "❌ FAIL"
    
    # 运行回归测试
    if phase is None or phase == "all":
        description = "运行回归测试 (Module & Checkpointing)"
        cmd = f"cd {project_root} && python -m pytest tests/test_module*.py tests/test_checkpointing.py -v --tb=short"
        success = run_command(cmd, description)
        results["Regression Tests"] = "✅ PASS" if success else "❌ FAIL"
    
    # 生成总结
    print("\n" + "="*60)
    print("📊 验证结果汇总")
    print("="*60)
    print()
    
    all_passed = True
    for test_name, result in results.items():
        print(f"  {test_name:.<40} {result}")
        if "FAIL" in result:
            all_passed = False
    
    print()
    print("="*60)
    if all_passed:
        print("✅ 所有测试通过！系统已 PRODUCTION READY")
        print("="*60)
        return 0
    else:
        print("❌ 部分测试失败，请查看详细输出")
        print("="*60)
        return 1

if __name__ == "__main__":
    sys.exit(main())
