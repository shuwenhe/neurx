#!/usr/bin/env python3
import subprocess
import sys

if len(sys.argv) < 2:
    print("Usage: python3 run_ir.py <ir_file>")
    sys.exit(1)

ir_file = sys.argv[1]
binary_file = ir_file.replace('.ir', '.bin')

# 编译为二进制
print(f"📦 编译 {ir_file} 为二进制...")
result = subprocess.run(['/Users/feifei/train/s/bin/s', '--emit-bin', ir_file, binary_file], 
                       capture_output=True, text=True)
if result.returncode != 0:
    print(f"❌ 编译失败:\n{result.stderr}")
    sys.exit(1)

print(f"✅ 二进制生成: {binary_file}")

# 执行二进制
print(f"▶️  执行 {binary_file}...\n")
result = subprocess.run([binary_file], capture_output=True, text=True)
print(result.stdout)
if result.stderr:
    print(f"错误: {result.stderr}")
if result.returncode != 0:
    sys.exit(result.returncode)
