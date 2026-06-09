#!/usr/bin/env python3
"""
claude-code Mermaid Flowchart to Image Converter
使用多个 API 源和本地工具的转换器
"""

import subprocess
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
MMD_FILE = SCRIPT_DIR / "claude-code-architecture.mmd"

def convert_with_curl(mmd_file: Path):
    """使用 curl 和 kroki.io 转换"""
    print("🔄 使用 curl + kroki.io API...")
    
    if not mmd_file.exists():
        print(f"❌ 错误: {mmd_file} 不存在")
        return False
    
    try:
        # 读取 Mermaid 文件
        diagram_content = mmd_file.read_text()
        
        # 使用 jq 编码 JSON
        result = subprocess.run(
            ['jq', '-Rs', '.'],
            input=diagram_content,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            print(f"⚠️ jq 编码失败: {result.stderr}")
            # 尝试使用 Python 进行 JSON 编码
            import json as jsonlib
            encoded = jsonlib.dumps(diagram_content)
        else:
            encoded = result.stdout.strip()
        
        # 构造 JSON 负载
        payload = f'{{"diagram_source":{encoded}}}'
        
        # 生成 PNG
        print("  🎨 生成 PNG...")
        png_result = subprocess.run(
            [
                'curl', '-s', '-X', 'POST',
                '-H', 'Content-Type: application/json',
                '-d', payload,
                'https://kroki.io/mermaid/png',
                '-o', str(SCRIPT_DIR / 'claude-code-architecture.png'),
                '-w', '%{http_code}'
            ],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        http_code = png_result.stdout.strip()[-3:]
        png_size = (SCRIPT_DIR / 'claude-code-architecture.png').stat().st_size if (SCRIPT_DIR / 'claude-code-architecture.png').exists() else 0
        
        if http_code == '200' and png_size > 1000:
            print(f"  ✅ PNG 创建成功 ({png_size // 1024} KB)")
            return True
        else:
            print(f"  ❌ PNG 生成失败 (HTTP {http_code}, 大小: {png_size} 字节)")
            return False
            
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

def convert_with_mermaid_cli(mmd_file: Path):
    """使用本地 mermaid-cli 转换"""
    print("🔄 尝试使用本地 mermaid-cli...")
    
    try:
        result = subprocess.run(
            [
                'mmdc',
                '-i', str(mmd_file),
                '-o', str(SCRIPT_DIR / 'claude-code-architecture.png')
            ],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print("✅ PNG 创建成功")
            return True
        else:
            print(f"❌ mermaid-cli 失败: {result.stderr}")
            return False
    except FileNotFoundError:
        print("❌ mermaid-cli 未找到")
        return False
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

def main():
    print("=" * 60)
    print("🎨 claude-code Flowchart Converter")
    print("=" * 60)
    print()
    
    if not MMD_FILE.exists():
        print(f"❌ 错误: {MMD_FILE} 不存在")
        return False
    
    print(f"📄 输入: {MMD_FILE}")
    print(f"📁 输出: {SCRIPT_DIR}")
    print()
    
    # 方法 1: curl + kroki.io
    if convert_with_curl(MMD_FILE):
        print()
        print("✨ 转换完成！")
        png_file = SCRIPT_DIR / 'claude-code-architecture.png'
        if png_file.exists():
            size = png_file.stat().st_size
            print(f"📁 PNG 文件: {png_file} ({size // 1024} KB)")
        return True
    
    # 方法 2: mermaid-cli
    print()
    if convert_with_mermaid_cli(MMD_FILE):
        print()
        print("✨ 转换完成！")
        png_file = SCRIPT_DIR / 'claude-code-architecture.png'
        if png_file.exists():
            size = png_file.stat().st_size
            print(f"📁 PNG 文件: {png_file} ({size // 1024} KB)")
        return True
    
    # 失败
    print()
    print("❌ 所有转换方法都失败了")
    print()
    print("💡 替代方案:")
    print("  1. 访问 https://mermaid.live")
    print("  2. 复制 claude-code-architecture.mmd 内容")
    print("  3. 粘贴到编辑器并下载")
    
    return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
