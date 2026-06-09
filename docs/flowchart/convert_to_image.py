#!/usr/bin/env python3
"""
neurx-code Mermaid Flowchart to Image Converter
Convert Mermaid flowchart to PNG/SVG/PDF formats

Methods:
1. Online Mermaid API (无需安装依赖)
2. Local mermaid-cli (需要 npm 安装)
3. Playwright + Mermaid Live Editor (需要 pip)
"""

import os
import sys
import json
import requests
import urllib.parse
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).parent
MMD_FILE = SCRIPT_DIR / "neurx-code-architecture.mmd"

# Mermaid 在线渲染 API
MERMAID_RENDER_API = "https://mermaid.ink/img"

def method1_online_api(mmd_file: Path, output_format: str = "png"):
    """
    Method 1: 使用 Mermaid.ink 在线 API (推荐，无需依赖)
    """
    print(f"📡 Using Mermaid Online API (mermaid.ink)...")
    
    if not mmd_file.exists():
        print(f"❌ Error: {mmd_file} not found")
        return False
    
    # 读取 Mermaid 文件
    mermaid_content = mmd_file.read_text()
    
    # 将内容编码为 base64 (Mermaid.ink 的标准方式)
    import base64
    encoded = base64.b64encode(mermaid_content.encode('utf-8')).decode('utf-8')
    
    # 构造 URL
    # 对于 mermaid.ink，需要使用特殊格式
    # 首先尝试使用 kroki (支持 Mermaid)
    try:
        # 使用 kroki.io (免费 API)
        print("📡 Trying kroki.io API...")
        kroki_api = f"https://kroki.io/mermaid/png"
        
        headers = {'Content-Type': 'application/json'}
        data = {"diagram_source": mermaid_content}
        
        response = requests.post(kroki_api, json=data, headers=headers, timeout=10)
        
        if response.status_code == 200:
            output_file = SCRIPT_DIR / f"neurx-code-architecture.{output_format}"
            output_file.write_bytes(response.content)
            print(f"✅ Successfully created: {output_file}")
            return True
        else:
            print(f"⚠️  kroki.io returned status {response.status_code}")
    except Exception as e:
        print(f"⚠️  kroki.io API failed: {e}")
    
    # 备选方案：使用 mermaid.ink
    try:
        print("📡 Trying mermaid.ink API...")
        # mermaid.ink 使用这种格式: /img/base64_encoded_diagram
        
        # 首先尝试直接发送
        mermaid_api = "https://mermaid.ink/svg"
        
        response = requests.post(
            mermaid_api,
            data=mermaid_content,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        if response.status_code == 200:
            output_file = SCRIPT_DIR / f"neurx-code-architecture.svg"
            output_file.write_bytes(response.content)
            print(f"✅ Successfully created SVG: {output_file}")
            return True
    except Exception as e:
        print(f"⚠️  mermaid.ink API failed: {e}")
    
    return False

def method2_mermaid_cli(mmd_file: Path):
    """
    Method 2: 使用本地 mermaid-cli (需要先安装)
    """
    print("📦 Using local mermaid-cli...")
    import subprocess
    
    try:
        cmd = [
            "mmdc",
            "-i", str(mmd_file),
            "-o", str(SCRIPT_DIR / "neurx-code-architecture.svg")
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print("✅ Successfully created: neurx-code-architecture.svg")
            # 也生成 PNG
            cmd_png = [
                "mmdc",
                "-i", str(mmd_file),
                "-o", str(SCRIPT_DIR / "neurx-code-architecture.png"),
                "-t", "default"
            ]
            result_png = subprocess.run(cmd_png, capture_output=True, text=True, timeout=30)
            if result_png.returncode == 0:
                print("✅ Successfully created: neurx-code-architecture.png")
            return True
        else:
            print(f"❌ Error: {result.stderr}")
            return False
    except FileNotFoundError:
        print("❌ mermaid-cli not found. Install with: npm install -g @mermaid-js/mermaid-cli")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def method3_graphviz_fallback(mmd_file: Path):
    """
    Method 3: 使用 Graphviz 作为后备方案
    """
    print("📊 Using Graphviz (fallback)...")
    import subprocess
    
    try:
        # 检查是否安装了 dot 命令
        result = subprocess.run(["which", "dot"], capture_output=True)
        if result.returncode != 0:
            print("⚠️  Graphviz not installed. Install with: brew install graphviz")
            return False
        
        # 这需要转换 Mermaid 到 DOT 格式，比较复杂
        print("ℹ️  Graphviz method requires manual Mermaid to DOT conversion")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def convert_mermaid_to_image():
    """
    主转换函数 - 尝试所有可用方法
    """
    print("=" * 60)
    print("🎨 neurx-code Flowchart Converter")
    print("=" * 60)
    print()
    
    if not MMD_FILE.exists():
        print(f"❌ Error: Mermaid file not found at {MMD_FILE}")
        return False
    
    print(f"📄 Input file: {MMD_FILE}")
    print(f"📁 Output directory: {SCRIPT_DIR}")
    print()
    
    # 尝试方法 1: 在线 API (推荐，最可靠)
    print("🔄 Attempt 1: Online API (kroki.io + mermaid.ink)")
    print("-" * 60)
    if method1_online_api(MMD_FILE, "png"):
        print()
        print("✨ Conversion completed successfully!")
        return True
    
    print()
    print("🔄 Attempt 2: Local mermaid-cli")
    print("-" * 60)
    if method2_mermaid_cli(MMD_FILE):
        print()
        print("✨ Conversion completed successfully!")
        return True
    
    print()
    print("⚠️  All automatic methods failed.")
    print()
    print("📋 Alternative options:")
    print("=" * 60)
    print()
    print("Option 1: Install mermaid-cli")
    print("  npm install -g @mermaid-js/mermaid-cli")
    print("  mmdc -i neurx-code-architecture.mmd -o neurx-code-architecture.png")
    print()
    print("Option 2: Online Mermaid Editor")
    print("  1. Copy contents of: neurx-code-architecture.mmd")
    print("  2. Visit: https://mermaid.live")
    print("  3. Paste diagram code")
    print("  4. Click 'Download' and save as PNG/SVG/PDF")
    print()
    print("Option 3: VS Code Extension")
    print("  1. Install: 'Mermaid Markdown Syntax Highlighting' extension")
    print("  2. Install: 'Markdown Preview Mermaid Support' extension")
    print("  3. Open .md file and preview")
    print()
    
    return False

def install_mermaid_cli():
    """
    帮助用户安装 mermaid-cli
    """
    import subprocess
    
    print("📦 Installing mermaid-cli...")
    try:
        subprocess.run(
            ["npm", "install", "-g", "@mermaid-js/mermaid-cli"],
            check=True,
            timeout=300  # 5 分钟超时
        )
        print("✅ mermaid-cli installed successfully!")
        return True
    except Exception as e:
        print(f"❌ Installation failed: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "install":
            install_mermaid_cli()
        elif sys.argv[1] == "convert":
            convert_mermaid_to_image()
    else:
        # 默认执行转换
        success = convert_mermaid_to_image()
        sys.exit(0 if success else 1)
